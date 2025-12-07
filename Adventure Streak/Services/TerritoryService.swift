import Foundation
import CoreLocation

@MainActor
class TerritoryService {
    private let territoryStore: TerritoryStore
    
    init(territoryStore: TerritoryStore) {
        self.territoryStore = territoryStore
    }
    
    func processActivity(_ activity: ActivitySession, ownerUserId: String? = nil, ownerDisplayName: String? = nil) -> (cells: [TerritoryCell], stats: TerritoryStats) {
        // Reuse the static helper logic
        let existingCells = territoryStore.conqueredCells
        let (newCells, stats) = TerritoryService.calculateTerritories(activities: [activity], existingCells: existingCells, ownerUserId: ownerUserId, ownerDisplayName: ownerDisplayName)
        
        if !newCells.isEmpty {
            territoryStore.upsertCells(newCells)

            // Multiplayer Sync - only if we have a valid user
            if let userId = AuthenticationService.shared.userId, !userId.isEmpty {
                TerritoryRepository.shared.saveCells(newCells, userId: userId)
            } else {
                print("[Territories] Skipping cloud save because userId is missing")
            }
        }
        
        return (newCells, stats)
    }
    

    
    func recalculateExpiredCells() {
        territoryStore.removeExpiredCells(now: Date())
    }
    
    // NEW: Batch processing to prevent update storms
    // NEW: Batch processing to prevent update storms
    // Now async to allow offloading to background thread
    func processActivities(_ activities: [ActivitySession], ownerUserId: String? = nil, ownerDisplayName: String? = nil) async -> TerritoryStats {
        // 1. Capture existing cells (Main Actor access)
        let existingCells = territoryStore.conqueredCells
        
        // 2. Perform heavy calculation on background thread
        let result = await Task.detached(priority: .userInitiated) {
            return TerritoryService.calculateTerritories(activities: activities, existingCells: existingCells, ownerUserId: ownerUserId, ownerDisplayName: ownerDisplayName)
        }.value
        
        // 3. Update store ONCE (Main Actor access)
        if !result.newCells.isEmpty {
            territoryStore.upsertCells(result.newCells)

            // Multiplayer Sync - only if we have a valid user
            if let userId = AuthenticationService.shared.userId, !userId.isEmpty {
                TerritoryRepository.shared.saveCells(result.newCells, userId: userId)
            } else {
                print("[Territories] Skipping cloud save because userId is missing")
            }
        }
        
        return result.stats
    }
    
    // Pure logic helper - Non-isolated to run on background thread
    nonisolated private static func calculateTerritories(activities: [ActivitySession], existingCells: [String: TerritoryCell], ownerUserId: String?, ownerDisplayName: String?) -> (newCells: [TerritoryCell], stats: TerritoryStats) {
        var newConqueredCount = 0
        var defendedCount = 0
        var recapturedCount = 0
        
        // Temporary local cache of new cells to avoid duplicates within the batch
        var batchNewCells: [TerritoryCell] = []
        
        for activity in activities {
            guard !activity.route.isEmpty else { continue }
            
            // Add start point cell
            if let first = activity.route.first {
                let cell = existingCells[TerritoryGrid.cellId(x: TerritoryGrid.cellIndex(for: first.coordinate).x, y: TerritoryGrid.cellIndex(for: first.coordinate).y)] ?? TerritoryGrid.getCell(for: first.coordinate, ownerUserId: ownerUserId, ownerDisplayName: ownerDisplayName)
                processCell(cell, existingCells: existingCells, newCells: &batchNewCells, newConqueredCount: &newConqueredCount, defendedCount: &defendedCount, recapturedCount: &recapturedCount, activity: activity, currentUserId: ownerUserId, currentUserName: ownerDisplayName)
            }
            
            // Process segments
            for i in 0..<activity.route.count - 1 {
                let start = activity.route[i].coordinate
                let end = activity.route[i+1].coordinate
                
                let interpolatedCells = TerritoryGrid.cellsBetween(start: start, end: end)
                
                for cellTemplate in interpolatedCells {
                    // Check if already processed in this batch
                    if batchNewCells.contains(where: { $0.id == cellTemplate.id }) {
                        continue
                    }
                    
                    let cell = existingCells[cellTemplate.id] ?? cellTemplate
                    processCell(cell, existingCells: existingCells, newCells: &batchNewCells, newConqueredCount: &newConqueredCount, defendedCount: &defendedCount, recapturedCount: &recapturedCount, activity: activity, currentUserId: ownerUserId, currentUserName: ownerDisplayName)
                }
            }
        }
        
        let stats = TerritoryStats(
            newCellsCount: newConqueredCount,
            defendedCellsCount: defendedCount,
            recapturedCellsCount: recapturedCount
        )
        
        return (batchNewCells, stats)
    }
    
    // Helper must be static or non-isolated to be called from detached task without capturing self
    nonisolated private static func processCell(_ cell: TerritoryCell, existingCells: [String: TerritoryCell], newCells: inout [TerritoryCell], newConqueredCount: inout Int, defendedCount: inout Int, recapturedCount: inout Int, activity: ActivitySession, currentUserId: String?, currentUserName: String?) {
        var mutableCell = cell
        let existing = existingCells[mutableCell.id]
        let wasExpiredOrNew = mutableCell.isExpired || existing == nil
        let wasPreviouslyOwned = existing != nil
        let ownedByCurrent = mutableCell.ownerUserId == currentUserId
        let ownedByOther = (mutableCell.ownerUserId != nil) && (mutableCell.ownerUserId != currentUserId)
        
        if wasExpiredOrNew {
            if wasPreviouslyOwned && ownedByCurrent {
                recapturedCount += 1
            } else {
                newConqueredCount += 1
            }
        } else if ownedByOther {
            // Stealing from another active owner
            recapturedCount += 1
        } else {
            defendedCount += 1
        }
        
        mutableCell.lastConqueredAt = activity.endDate
        mutableCell.expiresAt = Calendar.current.date(byAdding: .day, value: TerritoryGrid.daysToExpire, to: activity.endDate)!
        mutableCell.ownerUserId = currentUserId
        mutableCell.ownerDisplayName = currentUserName
        mutableCell.ownerUploadedAt = activity.endDate
        
        newCells.append(mutableCell)
    }
}

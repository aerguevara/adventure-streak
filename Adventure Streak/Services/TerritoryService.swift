import Foundation
import CoreLocation

@MainActor
class TerritoryService {
    private let territoryStore: TerritoryStore
    
    init(territoryStore: TerritoryStore) {
        self.territoryStore = territoryStore
    }
    
    func processActivity(_ activity: ActivitySession) -> TerritoryStats {
        // Reuse the static helper logic
        let existingCells = territoryStore.conqueredCells
        let (newCells, stats) = TerritoryService.calculateTerritories(activities: [activity], existingCells: existingCells)
        
        if !newCells.isEmpty {
            territoryStore.upsertCells(newCells)
            
            // Multiplayer Sync
            let userId = AuthenticationService.shared.userId ?? "unknown_user"
            TerritoryRepository.shared.saveCells(newCells, userId: userId)
        }
        
        return stats
    }
    

    
    func recalculateExpiredCells() {
        territoryStore.removeExpiredCells(now: Date())
    }
    
    // NEW: Batch processing to prevent update storms
    // NEW: Batch processing to prevent update storms
    // Now async to allow offloading to background thread
    func processActivities(_ activities: [ActivitySession]) async -> TerritoryStats {
        // 1. Capture existing cells (Main Actor access)
        let existingCells = territoryStore.conqueredCells
        
        // 2. Perform heavy calculation on background thread
        let result = await Task.detached(priority: .userInitiated) {
            return TerritoryService.calculateTerritories(activities: activities, existingCells: existingCells)
        }.value
        
        // 3. Update store ONCE (Main Actor access)
        if !result.newCells.isEmpty {
            territoryStore.upsertCells(result.newCells)
            
            // Multiplayer Sync
            let userId = AuthenticationService.shared.userId ?? "unknown_user"
            TerritoryRepository.shared.saveCells(result.newCells, userId: userId)
        }
        
        return result.stats
    }
    
    // Pure logic helper - Non-isolated to run on background thread
    nonisolated private static func calculateTerritories(activities: [ActivitySession], existingCells: [String: TerritoryCell]) -> (newCells: [TerritoryCell], stats: TerritoryStats) {
        var newConqueredCount = 0
        var defendedCount = 0
        let recapturedCount = 0
        
        // Temporary local cache of new cells to avoid duplicates within the batch
        var batchNewCells: [TerritoryCell] = []
        
        for activity in activities {
            guard !activity.route.isEmpty else { continue }
            
            // Add start point cell
            if let first = activity.route.first {
                let cell = existingCells[TerritoryGrid.cellId(x: TerritoryGrid.cellIndex(for: first.coordinate).x, y: TerritoryGrid.cellIndex(for: first.coordinate).y)] ?? TerritoryGrid.getCell(for: first.coordinate)
                processCell(cell, existingCells: existingCells, newCells: &batchNewCells, newConqueredCount: &newConqueredCount, defendedCount: &defendedCount, activity: activity)
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
                    processCell(cell, existingCells: existingCells, newCells: &batchNewCells, newConqueredCount: &newConqueredCount, defendedCount: &defendedCount, activity: activity)
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
    nonisolated private static func processCell(_ cell: TerritoryCell, existingCells: [String: TerritoryCell], newCells: inout [TerritoryCell], newConqueredCount: inout Int, defendedCount: inout Int, activity: ActivitySession) {
        var mutableCell = cell
        let wasExpiredOrNew = mutableCell.isExpired || existingCells[mutableCell.id] == nil
        
        if wasExpiredOrNew {
            newConqueredCount += 1
        } else {
            defendedCount += 1
        }
        
        mutableCell.lastConqueredAt = activity.endDate
        mutableCell.expiresAt = Calendar.current.date(byAdding: .day, value: TerritoryGrid.daysToExpire, to: activity.endDate)!
        
        newCells.append(mutableCell)
    }
}

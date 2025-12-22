import Foundation
import CoreLocation

enum TerritoryInteraction: String {
    case conquest
    case defense
    case steal
    case recapture
}

struct TerritoryEvent {
    let interaction: TerritoryInteraction
    let cellId: String
    let previousOwnerId: String?
}

@MainActor
class TerritoryService {
    private let territoryStore: TerritoryStore
    
    init(territoryStore: TerritoryStore) {
        self.territoryStore = territoryStore
    }
    
    // Prefetch remote owners for cells involved to avoid misclassification (robo vs nuevo)
    private func mergeWithRemoteOwners(for activities: [ActivitySession], existing: [String: TerritoryCell]) async -> [String: TerritoryCell] {
        var merged = existing
        let cellIds = collectCellIds(for: activities)
        
        // Usar snapshot ya observado para no depender solo de 'in' queries
        let repo = TerritoryRepository.shared
        await repo.waitForInitialSync()
        let cachedRemotes = repo.otherTerritories.filter { cellIds.contains($0.id ?? "") }
        
        // Fallback: traer por ids en caso de no estar en cache
        let fetchedRemotes = await repo.fetchTerritories(ids: Array(cellIds))
        
        for remote in (cachedRemotes + fetchedRemotes) {
            guard let id = remote.id else { continue }
            merged[id] = TerritoryCell(
                id: id,
                centerLatitude: remote.centerLatitude,
                centerLongitude: remote.centerLongitude,
                boundary: remote.boundary,
                lastConqueredAt: remote.activityEndAt,
                expiresAt: remote.expiresAt,
                ownerUserId: remote.userId,
                ownerDisplayName: nil,
                ownerUploadedAt: remote.uploadedAt?.dateValue()
            )
        }
        return merged
    }
    
    // Build the set of cell IDs the activities traverse
    nonisolated private func collectCellIds(for activities: [ActivitySession]) -> Set<String> {
        var ids = Set<String>()
        for activity in activities {
            guard !activity.route.isEmpty else { continue }
            if let first = activity.route.first {
                let cell = TerritoryGrid.getCell(for: first.coordinate)
                ids.insert(cell.id)
            }
            for i in 0..<max(0, activity.route.count - 1) {
                let start = activity.route[i].coordinate
                let end = activity.route[i+1].coordinate
                let interpolatedCells = TerritoryGrid.cellsBetween(start: start, end: end)
                for cell in interpolatedCells {
                    ids.insert(cell.id)
                }
            }
        }
        return ids
    }
    
    func processActivity(_ activity: ActivitySession, ownerUserId: String? = nil, ownerDisplayName: String? = nil) async -> (cells: [TerritoryCell], stats: TerritoryStats, events: [TerritoryEvent]) {
        // [SERVER MIGRATION]
        // Local calculation disabled to prevent cache conflicts.
        // The Cloud Function 'processActivityTerritories' is now the single source of truth.
        print("ℹ️ TerritoryService: Skipping local calculation. Delegating to Server.")
        
        let emptyStats = TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0)
        return ([], emptyStats, [])
    }
    
    // Remote notifications moved to Cloud Function
    /*
    private func handleNotifications(for events: [TerritoryEvent], activityId: String) {
        // ... (Logic moved to backend)
    }
    */    
    func recalculateExpiredCells() {
        territoryStore.removeExpiredCells(now: Date())
    }
    
    // NEW: Batch processing to prevent update storms
    // Now async to allow offloading to background thread
    func processActivities(_ activities: [ActivitySession], ownerUserId: String? = nil, ownerDisplayName: String? = nil) async -> TerritoryStats {
        // 1. Capture existing cells (Main Actor access)
        let existingCells = territoryStore.conqueredCells
        let mergedCells = await mergeWithRemoteOwners(for: activities, existing: existingCells)
        let expirationDays = GameConfigService.shared.config.territoryExpirationDays
        
        // 2. Perform heavy calculation on background thread
        let result = await Task.detached(priority: .userInitiated) {
            return TerritoryService.calculateTerritories(
                activities: activities,
                existingCells: mergedCells,
                ownerUserId: ownerUserId,
                ownerDisplayName: ownerDisplayName,
                expirationDays: expirationDays
            )
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
        
        // Note: For batch processing, we might want to consolidate notifications 
        // but for now let's focus on single activity processing (Sync/Import)
        
        return result.stats
    }
    
    // ... (rest of the file)
    
    // Pure logic helper - Non-isolated to run on background thread
    nonisolated private static func calculateTerritories(activities: [ActivitySession], existingCells: [String: TerritoryCell], ownerUserId: String?, ownerDisplayName: String?, expirationDays: Int) -> (newCells: [TerritoryCell], stats: TerritoryStats, events: [TerritoryEvent]) {
        var newConqueredCount = 0
        var defendedCount = 0
        var recapturedCount = 0
        var events: [TerritoryEvent] = []
        
        // Temporary local cache of new cells to avoid duplicates within the batch
        var batchNewCells: [TerritoryCell] = []
        
        for activity in activities {
            guard !activity.route.isEmpty else { continue }
            
            // Add start point cell
            if let first = activity.route.first {
                let cell = existingCells[TerritoryGrid.cellId(x: TerritoryGrid.cellIndex(for: first.coordinate).x, y: TerritoryGrid.cellIndex(for: first.coordinate).y)] ?? TerritoryGrid.getCell(for: first.coordinate, ownerUserId: ownerUserId, ownerDisplayName: ownerDisplayName, expirationDays: expirationDays, activityId: activity.id)
                processCell(cell, existingCells: existingCells, newCells: &batchNewCells, newConqueredCount: &newConqueredCount, defendedCount: &defendedCount, recapturedCount: &recapturedCount, events: &events, activity: activity, currentUserId: ownerUserId, currentUserName: ownerDisplayName, expirationDays: expirationDays)
            }
            
            // Process segments
            for i in 0..<activity.route.count - 1 {
                let start = activity.route[i].coordinate
                let end = activity.route[i+1].coordinate
                
                let interpolatedCells = TerritoryGrid.cellsBetween(start: start, end: end, expirationDays: expirationDays, activityId: activity.id)
                
                for cellTemplate in interpolatedCells {
                    // Check if already processed in this batch
                    if batchNewCells.contains(where: { $0.id == cellTemplate.id }) {
                        continue
                    }
                    
                    let cell = existingCells[cellTemplate.id] ?? cellTemplate
                    processCell(cell, existingCells: existingCells, newCells: &batchNewCells, newConqueredCount: &newConqueredCount, defendedCount: &defendedCount, recapturedCount: &recapturedCount, events: &events, activity: activity, currentUserId: ownerUserId, currentUserName: ownerDisplayName, expirationDays: expirationDays)
                }
            }
        }
        
        let stats = TerritoryStats(
            newCellsCount: newConqueredCount,
            defendedCellsCount: defendedCount,
            recapturedCellsCount: recapturedCount
        )
        
        return (batchNewCells, stats, events)
    }
    
    // Helper must be static or non-isolated to be called from detached task without capturing self
    nonisolated private static func processCell(_ cell: TerritoryCell, existingCells: [String: TerritoryCell], newCells: inout [TerritoryCell], newConqueredCount: inout Int, defendedCount: inout Int, recapturedCount: inout Int, events: inout [TerritoryEvent], activity: ActivitySession, currentUserId: String?, currentUserName: String?, expirationDays: Int) {
        var mutableCell = cell
        let existing = existingCells[mutableCell.id]
        
        // Si ya existe un dueño distinto con fecha más reciente o igual, no lo podemos reclamar
        if let existing,
           let currentUserId,
           existing.ownerUserId != nil,
           existing.ownerUserId != currentUserId,
           existing.lastConqueredAt >= activity.endDate,
           existing.expiresAt > Date() {
            return
        }
        
        let wasExpiredOrNew = mutableCell.isExpired || existing == nil
        let wasPreviouslyOwned = existing != nil
        let ownedByCurrent = mutableCell.ownerUserId == currentUserId
        let ownedByOther = (mutableCell.ownerUserId != nil) && (mutableCell.ownerUserId != currentUserId)
        
        var interaction: TerritoryInteraction = .conquest
        var prevOwner: String? = nil
        
        if wasExpiredOrNew {
            if wasPreviouslyOwned && ownedByCurrent {
                recapturedCount += 1
                interaction = .recapture
            } else {
                newConqueredCount += 1
                interaction = .conquest
            }
        } else if ownedByOther {
            // Stealing from another active owner
            recapturedCount += 1
            interaction = .steal
            prevOwner = mutableCell.ownerUserId
        } else if ownedByCurrent {
            // Explicitly verify current user ownership (prevents nil owner -> defense bug)
            defendedCount += 1
            interaction = .defense
        } else {
            // Existing but owner is nil (Unknown/Legacy) -> Treat as Conquest
            newConqueredCount += 1
            interaction = .conquest
        }
        
        events.append(TerritoryEvent(interaction: interaction, cellId: mutableCell.id, previousOwnerId: prevOwner))
        
        mutableCell.lastConqueredAt = activity.endDate
        mutableCell.expiresAt = Calendar.current.date(byAdding: .day, value: expirationDays, to: activity.endDate)!
        mutableCell.ownerUserId = currentUserId
        mutableCell.ownerDisplayName = currentUserName
        mutableCell.ownerUploadedAt = activity.endDate
        mutableCell.activityId = activity.id
        
        newCells.append(mutableCell)
    }
}

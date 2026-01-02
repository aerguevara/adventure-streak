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
    
    func processActivity(_ activity: ActivitySession, ownerUserId: String? = nil, ownerDisplayName: String? = nil) async -> (cells: [TerritoryCell], stats: TerritoryStats, events: [TerritoryEvent]) {
        // [SERVER MIGRATION]
        // Local calculation disabled to prevent cache conflicts.
        // The Cloud Function 'processActivityTerritories' is now the single source of truth.
        print("ℹ️ TerritoryService: Skipping local calculation. Delegating to Server.")
        
        let emptyStats = TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0, stolenCellsCount: 0)
        return ([], emptyStats, [])
    }
    
    func processActivities(_ activities: [ActivitySession], ownerUserId: String? = nil, ownerDisplayName: String? = nil) async -> TerritoryStats {
        // [SERVER MIGRATION]
        // Local calculation disabled to prevent cache conflicts and ensure consistency.
        // Cloud Functions are now responsible for territorial updates and XP.
        print("ℹ️ TerritoryService: Skipping local batch process. Delegating to Server.")
        
        return TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0, stolenCellsCount: 0)
    }
    

}

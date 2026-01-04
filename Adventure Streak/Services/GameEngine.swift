// IMPLEMENTATION: ADVENTURE STREAK GAME SYSTEM
import Foundation

@MainActor
class GameEngine {
    static let shared = GameEngine()
    
    private let activityStore = ActivityStore.shared
    private let territoryService: TerritoryService
    private let gamificationService = GamificationService.shared
    private let feedRepository = FeedRepository.shared
    private let activityRepository = ActivityRepository.shared
    
    private init() {
        self.territoryService = TerritoryService(territoryStore: TerritoryStore.shared)
    }
    
    enum ProcessingResult {
        case processed(TerritoryStats)
        case skipped
    }
    
    /// Main orchestrator: processes a completed activity through the entire game system
    /// Returns the processing result to distinguish new imports from restored ones
    @discardableResult
    func completeActivity(_ activity: ActivitySession, for userId: String, userName: String? = nil) async throws -> ProcessingResult {
        // GUARD: Never process activity for "unknown_user"
        guard userId != "unknown_user" && !userId.isEmpty else {
            print("⚠️ [GameEngine] Aborting completeActivity: Invalid userId '\(userId)'")
            return .skipped
        }
        
        print("🎮 GameEngine: Processing activity \(activity.id)")
        
        // Asegurar que ya tenemos foto de territorios remotos antes de calcular conquistas
        let territoryRepo = TerritoryRepository.shared
        territoryRepo.observeTerritories()
        await territoryRepo.waitForInitialSync()
        
        // 1. Save activity to store
        activityStore.saveActivity(activity)
        print("✅ Activity saved")
        
        // 1b. Check remote to avoid double-processing (XP/feed/territories) if already processed
        let alreadyProcessed = await activityRepository.activityExists(activityId: activity.id, userId: userId)
        if alreadyProcessed {
            print("⚠️ Activity \(activity.id) already exists in Firestore. Skipping XP and feed application. Refreshing local copy from remote.")
            if let remoteActivity = await activityRepository.fetchActivity(activityId: activity.id, userId: userId) {
                activityStore.updateActivity(remoteActivity)
            }
            return .skipped
        }
        
        // 2. Classify missions (Disabled - Moved to Cloud Function)
        
        // 3. Calculate territorial delta
        let territoryResult: (cells: [TerritoryCell], stats: TerritoryStats, events: [TerritoryEvent])
        if activity.activityType.isOutdoor {
            // Use the passed userId and userName for territory processing
            territoryResult = await territoryService.processActivity(activity, ownerUserId: userId, ownerDisplayName: userName)
            print("ℹ️ Territory calculation delegated to Server (Local result empty)")
        } else {
            territoryResult = ([], TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0, stolenCellsCount: 0, totalLootXP: 0, totalConsolidationXP: 0, totalStreakInterruptionXP: 0), [])
            print("ℹ️ Actividad indoor: se omite conquista de territorios")
        }
        
        // 3b. Smart Place Naming (Hybrid Approach)
        // Calculate the place name locally (free) and attach it to the activity
        // This avoids expensive Google Maps API calls on the server
        let smartLocation = await SmartPlaceNameService.shared.generateSmartTitle(for: activity.route)
        if let locationName = smartLocation {
            print("📍 Smart Location Detected: \(locationName)")
        }
        let territoryStats = territoryResult.stats
        
        // 4. Missions and XP logic are now handled server-side via Cloud Functions
        print("ℹ️ XP and Missions calculation delegated to Server")
        
        // Just update territory stats for local consistency if needed
        var updatedActivity = activity
        updatedActivity.territoryStats = territoryStats
        updatedActivity.locationLabel = smartLocation
        activityStore.updateActivity(updatedActivity)
        
        // 7b. Persist remotely in dedicated collection (Blocking) - Triggers Cloud Function
        do {
            try await self.activityRepository.saveActivity(updatedActivity, territories: territoryResult.cells, userId: userId)
        } catch {
            print("❌ [GameEngine] Failed to save activity remotely: \(error)")
            // Update local status to error so the UI can proceed/show error
            var errorActivity = updatedActivity
            errorActivity.processingStatus = .error
            activityStore.updateActivity(errorActivity)
            throw error // Rethrow to inform VM
        }
        
        // 9. Workout import notification is now handled server-side
        
        print("🎉 GameEngine: Activity processing complete!")
        
        return .processed(territoryStats)
    }
    

    
}

// IMPLEMENTATION: ADVENTURE STREAK GAME SYSTEM
import Foundation

@MainActor
class GameEngine {
    static let shared = GameEngine()
    
    private let activityStore = ActivityStore.shared
    private let territoryService: TerritoryService
    private let missionEngine = MissionEngine.shared
    private let gamificationService = GamificationService.shared
    private let feedRepository = FeedRepository.shared
    private let activityRepository = ActivityRepository.shared
    
    private init() {
        self.territoryService = TerritoryService(territoryStore: TerritoryStore.shared)
    }
    
    /// Main orchestrator: processes a completed activity through the entire game system
    /// Returns the territory stats for tracking purposes
    @discardableResult
    func completeActivity(_ activity: ActivitySession, for userId: String, userName: String? = nil) async throws -> TerritoryStats {
        // GUARD: Never process activity for "unknown_user"
        guard userId != "unknown_user" && !userId.isEmpty else {
            print("⚠️ [GameEngine] Aborting completeActivity: Invalid userId '\(userId)'")
            return TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0)
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
            return TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0)
        }
        
        // 2. Classify missions (Disabled - Moved to Cloud Function)
        
        // 3. Calculate territorial delta
        let territoryResult: (cells: [TerritoryCell], stats: TerritoryStats, events: [TerritoryEvent])
        if activity.activityType.isOutdoor {
            // Use the passed userId and userName for territory processing
            territoryResult = await territoryService.processActivity(activity, ownerUserId: userId, ownerDisplayName: userName)
            print("ℹ️ Territory calculation delegated to Server (Local result empty)")
        } else {
            territoryResult = ([], TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0), [])
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
        
        // 4. Classify missions (Disabled - Moved to Cloud Function)
        // let missions = try await missionEngine.classifyMissions(...)
        print("ℹ️ Missions calculation delegated to Server")
        
        // 5. Calculate XP for the activity (Disabled - Moved to Cloud Function)
        // let xpBreakdown = try await gamificationService.computeXP(...)
        print("ℹ️ XP calculation delegated to Server")
        
        // 6. Update activity with results
        // var updatedActivity = activity
        // updatedActivity.xpBreakdown = xpBreakdown
        // updatedActivity.territoryStats = territoryStats
        // updatedActivity.missions = missions
        
        // Just update territory stats for local consistency if needed
        var updatedActivity = activity
        updatedActivity.territoryStats = territoryStats
        updatedActivity.locationLabel = smartLocation
        activityStore.updateActivity(updatedActivity)
        
        // 7b. Persist remotely in dedicated collection (non-blocking) - Triggers Cloud Function
        Task {
            await self.activityRepository.saveActivity(updatedActivity, territories: territoryResult.cells, userId: userId)
        }
        
        // 7. Apply XP to user (Disabled - Server authoritative)
        // try await gamificationService.applyXP(xpBreakdown, to: userId, at: activity.endDate)
        

        
        // 9. Send workout_import notification
        // Moved to Cloud Function 'processActivityTerritories'
        /*
        NotificationService.shared.createFirestoreNotification(
            recipientId: userId,
            type: .workout_import,
            activityId: activity.id.uuidString
        )
        */
        
        print("🎉 GameEngine: Activity processing complete!")
        
        return territoryStats
    }
    

    
}

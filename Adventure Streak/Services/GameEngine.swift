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
    
    private init() {
        self.territoryService = TerritoryService(territoryStore: TerritoryStore.shared)
    }
    
    /// Main orchestrator: processes a completed activity through the entire game system
    /// Returns the territory stats for tracking purposes
    @discardableResult
    func completeActivity(_ activity: ActivitySession, for userId: String) async throws -> TerritoryStats {
        print("🎮 GameEngine: Processing activity \(activity.id)")
        
        // 1. Save activity to store
        activityStore.saveActivity(activity)
        print("✅ Activity saved")
        
        // 2. Get XP context
        let context = try await GamificationRepository.shared.buildXPContext(for: userId)
        print("✅ XP Context loaded")
        
        // 3. Calculate territorial delta
        let territoryStats = territoryService.processActivity(activity)
        print("✅ Territory processed: \(territoryStats.newCellsCount) new, \(territoryStats.defendedCellsCount) defended")
        
        // 4. Classify missions
        let missions = try await missionEngine.classifyMissions(
            for: activity,
            territoryStats: territoryStats,
            context: context
        )
        print("✅ \(missions.count) missions classified")
        for mission in missions {
            print("   📋 Mission: \(mission.name) (\(mission.rarity))")
        }
        
        // 5. Calculate XP for the activity
        let xpBreakdown = try await gamificationService.computeXP(
            for: activity,
            territoryStats: territoryStats,
            context: context
        )
        print("✅ XP calculated: \(xpBreakdown.total) total")
        
        // 6. Update activity with results
        var updatedActivity = activity
        updatedActivity.xpBreakdown = xpBreakdown
        updatedActivity.territoryStats = territoryStats
        updatedActivity.missions = missions
        print("💾 Saving activity with \(missions.count) missions")
        if let firstMission = missions.first {
            print("   First mission: \(firstMission.name)")
        }
        activityStore.updateActivity(updatedActivity)
        
        // 7. Apply XP to user
        try await gamificationService.applyXP(xpBreakdown, to: userId, at: activity.endDate)
        print("✅ XP applied to user")
        
        // 8. Create feed events
        try await createFeedEvents(
            missions: missions,
            activity: updatedActivity,
            territoryStats: territoryStats,
            xpBreakdown: xpBreakdown,
            userId: userId
        )
        print("✅ Feed events created")
        
        print("🎉 GameEngine: Activity processing complete!")
        
        return territoryStats
    }
    
    // MARK: - Feed Event Creation
    
    private func createFeedEvents(
        missions: [Mission],
        activity: ActivitySession,
        territoryStats: TerritorialDelta,
        xpBreakdown: XPBreakdown,
        userId: String
    ) async throws {
        let userName = AuthenticationService.shared.userName ?? "Aventurero"
        
        // Create event for each mission
        for mission in missions {
            let event = FeedEvent(
                id: nil,
                type: .territoryConquered, // Map mission category to event type
                date: activity.endDate,
                title: mission.name,
                subtitle: mission.description,
                xpEarned: xpBreakdown.total,
                userId: userId,
                relatedUserName: userName,
                miniMapRegion: nil,
                badgeName: nil,
                badgeRarity: nil,
                rarity: mission.rarity,
                isPersonal: true
            )
            
            feedRepository.postEvent(event)
        }
        
        // Create summary event if significant territory gain
        if territoryStats.newCellsCount >= 5 {
            let event = FeedEvent(
                id: nil,
                type: .territoryConquered,
                date: activity.endDate,
                title: "Expansión Territorial",
                subtitle: "\(territoryStats.newCellsCount) nuevos territorios conquistados",
                xpEarned: xpBreakdown.xpTerritory,
                userId: userId,
                relatedUserName: userName,
                miniMapRegion: nil,
                badgeName: nil,
                badgeRarity: nil,
                rarity: nil,
                isPersonal: true
            )
            
            feedRepository.postEvent(event)
        }
    }
}

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
        let userName = AuthenticationService.shared.resolvedUserName()
        let userLevel = GamificationService.shared.currentLevel
        
        // Create activity data for the feed
        let activityData = SocialActivityData(
            activityType: activity.activityType,
            distanceMeters: activity.distanceMeters,
            durationSeconds: activity.durationSeconds,
            xpEarned: xpBreakdown.total,
            newZonesCount: territoryStats.newCellsCount
        )
        
        // Single event per activity
        let primaryMission: Mission? = missions.first
        let missionNames: String = {
            let names = missions.map { $0.name }
            return names.isEmpty ? "" : names.joined(separator: " · ")
        }()
        
        let title: String = primaryMission?.name ?? "Actividad completada"
        let subtitle: String? = {
            if !missionNames.isEmpty {
                return "Misiones: \(missionNames)"
            }
            if territoryStats.newCellsCount > 0 {
                return "\(territoryStats.newCellsCount) nuevos territorios conquistados"
            }
            return nil
        }()
        
        let eventType: FeedEventType
        if territoryStats.newCellsCount > 0 {
            eventType = .territoryConquered
        } else {
            eventType = .distanceRecord
        }
        
        let event: FeedEvent = FeedEvent(
            id: "activity-\(activity.id.uuidString)-summary",
            type: eventType,
            date: activity.endDate,
            activityId: activity.id,
            title: title,
            subtitle: subtitle,
            xpEarned: xpBreakdown.total,
            userId: userId,
            relatedUserName: userName,
            userLevel: userLevel,
            userAvatarURL: nil, // TODO: Fetch from profile if needed
            miniMapRegion: nil,
            badgeName: nil,
            badgeRarity: nil,
            activityData: activityData,
            rarity: primaryMission?.rarity,
            isPersonal: true
        )
        
        feedRepository.postEvent(event)
    }
}

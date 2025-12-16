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
    func completeActivity(_ activity: ActivitySession, for userId: String) async throws -> TerritoryStats {
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
            if let remoteActivity = await activityRepository.fetchActivity(activityId: activity.id, userId: userId) {
                if let existingXP = remoteActivity.xpBreakdown {
                    print("⚠️ Activity \(activity.id) already exists with XP (\(existingXP.total)). Skipping reapply. Refreshing local copy.")
                    activityStore.updateActivity(remoteActivity)
                    return remoteActivity.territoryStats ?? TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0)
                } else {
                    print("⚠️ Activity \(activity.id) exists remotely but without XP. Recomputing XP to avoid zero rewards.")
                    // Recompute XP (territory stats may be missing; default to zero)
                    let context = try await GamificationRepository.shared.buildXPContext(for: userId)
                    let territoryStats = remoteActivity.territoryStats ?? TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0)
                    let xpBreakdown = try await gamificationService.computeXP(
                        for: remoteActivity,
                        territoryStats: territoryStats,
                        context: context
                    )
                    
                    var updated = remoteActivity
                    updated.xpBreakdown = xpBreakdown
                    activityStore.updateActivity(updated)
                    
                    // Persist updated activity and apply XP once (safe because previous XP was nil)
                    Task {
                        await self.activityRepository.saveActivity(updated, territories: [], userId: userId)
                    }
                    try await gamificationService.applyXP(xpBreakdown, to: userId, at: updated.endDate)
                    print("✅ XP recomputed and applied for pre-existing activity \(activity.id)")
                    return territoryStats
                }
            }
            return TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0)
        }
        
        // 2. Get XP context
        let context: XPContext
        do {
            context = try await GamificationRepository.shared.buildXPContext(for: userId)
            print("✅ XP Context loaded")
        } catch {
            print("⚠️ XP Context error (\(error)). Using default context.")
            context = defaultXPContext(for: userId)
        }
        
        // 3. Calculate territorial delta
        let territoryResult: (cells: [TerritoryCell], stats: TerritoryStats)
        if activity.activityType.isOutdoor {
            territoryResult = await territoryService.processActivity(activity, ownerUserId: AuthenticationService.shared.userId, ownerDisplayName: AuthenticationService.shared.userName)
            print("✅ Territory processed: \(territoryResult.stats.newCellsCount) new, \(territoryResult.stats.defendedCellsCount) defended")
        } else {
            territoryResult = ([], TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0))
            print("ℹ️ Actividad indoor: se omite conquista de territorios")
        }
        let territoryStats = territoryResult.stats
        
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
        let xpBreakdown: XPBreakdown
        do {
            xpBreakdown = try await gamificationService.computeXP(
                for: activity,
                territoryStats: territoryStats,
                context: context
            )
            print("✅ XP calculated: \(xpBreakdown.total) total")
        } catch {
            print("❌ XP calculation failed: \(error). Skipping XP for this activity.")
            return territoryStats
        }
        
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
        
        // 7b. Persist remotely in dedicated collection (non-blocking)
        Task {
            await self.activityRepository.saveActivity(updatedActivity, territories: territoryResult.cells, userId: userId)
        }
        
        // 7. Apply XP to user
        do {
            try await gamificationService.applyXP(xpBreakdown, to: userId, at: activity.endDate)
            print("✅ XP applied to user")
        } catch {
            print("❌ Failed to apply XP: \(error)")
        }
        
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
            newZonesCount: territoryStats.newCellsCount,
            defendedZonesCount: territoryStats.defendedCellsCount,
            recapturedZonesCount: territoryStats.recapturedCellsCount
        )
        
        // Single event per activity
        let primaryMission: Mission? = missions.first
        let missionNames: String = {
            let names = missions.map { $0.name }
            return names.isEmpty ? "" : names.joined(separator: " · ")
        }()
        
        let title: String = primaryMission?.name ?? "Actividad completada"
        let territoryHighlights: [String] = [
            territoryStats.newCellsCount > 0 ? "\(territoryStats.newCellsCount) territorios conquistados" : nil,
            territoryStats.defendedCellsCount > 0 ? "\(territoryStats.defendedCellsCount) territorios defendidos" : nil,
            territoryStats.recapturedCellsCount > 0 ? "\(territoryStats.recapturedCellsCount) territorios robados" : nil
        ].compactMap { $0 }

        let subtitle: String? = {
            var components: [String] = []
            if !missionNames.isEmpty {
                components.append("Misiones: \(missionNames)")
            }
            if !territoryHighlights.isEmpty {
                components.append(territoryHighlights.joined(separator: " · "))
            }
            return components.isEmpty ? nil : components.joined(separator: " · ")
        }()

        let eventType: FeedEventType
        if territoryStats.recapturedCellsCount > 0 {
            eventType = .territoryRecaptured
        } else if territoryStats.newCellsCount > 0 {
            eventType = .territoryConquered
        } else if territoryStats.defendedCellsCount > 0 {
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
    
    private func defaultXPContext(for userId: String) -> XPContext {
        XPContext(
            userId: userId,
            currentWeekDistanceKm: 0,
            bestWeeklyDistanceKm: nil,
            currentStreakWeeks: 0,
            todayBaseXPEarned: 0,
            gamificationState: GamificationState(totalXP: 0, level: 1, currentStreakWeeks: 0)
        )
    }
}

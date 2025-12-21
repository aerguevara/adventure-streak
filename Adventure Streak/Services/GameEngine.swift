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
        activityStore.updateActivity(updatedActivity)
        
        // 7b. Persist remotely in dedicated collection (non-blocking) - Triggers Cloud Function
        Task {
            await self.activityRepository.saveActivity(updatedActivity, territories: territoryResult.cells, userId: userId)
        }
        
        // 7. Apply XP to user (Disabled - Server authoritative)
        // try await gamificationService.applyXP(xpBreakdown, to: userId, at: activity.endDate)
        
        // 8. Create feed events (Disabled - Server authoritative)
        // try await createFeedEvents(...)
        print("✅ Activity processing handed off to Server")
        
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
    
    // MARK: - Feed Event Creation
    
    private func createFeedEvents(
        missions: [Mission],
        activity: ActivitySession,
        territoryStats: TerritorialDelta,
        xpBreakdown: XPBreakdown,
        userId: String,
        providedUserName: String? = nil
    ) async throws {
        var userName = providedUserName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? AuthenticationService.shared.resolvedUserName()
        
        // Saneamiento adicional: si el nombre es genérico o vacío, intentar descarga directa de Firestore
        if userName.isEmpty || userName == "Aventurero" || userName == "Guest Adventurer" {
            let userDoc = await withCheckedContinuation { continuation in
                UserRepository.shared.fetchUser(userId: userId) { user in
                    continuation.resume(returning: user)
                }
            }
            if let remoteName = userDoc?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !remoteName.isEmpty {
                userName = remoteName
                print("🔄 [GameEngine] Nome recuperado de Firestore para el feed: \(userName)")
            }
        }

        let userLevel = GamificationService.shared.currentLevel
        
        // Create activity data for the feed
        let activityData = SocialActivityData(
            activityType: activity.activityType,
            distanceMeters: activity.distanceMeters,
            durationSeconds: activity.durationSeconds,
            xpEarned: xpBreakdown.total,
            newZonesCount: territoryStats.newCellsCount,
            defendedZonesCount: territoryStats.defendedCellsCount,
            recapturedZonesCount: territoryStats.recapturedCellsCount,
            calories: activity.calories,
            averageHeartRate: activity.averageHeartRate
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
            activityId: activity.id.uuidString,
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

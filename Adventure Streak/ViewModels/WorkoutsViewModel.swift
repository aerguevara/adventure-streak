import Foundation
import Combine

struct WorkoutItemViewData: Identifiable {
    let id: UUID
    let type: ActivityType
    let title: String
    let dateString: String
    let duration: String
    let pace: String?
    let xp: Int?
    let territoryXP: Int?
    let territoryCount: Int?
    // NEW: Detailed stats
    let newTerritories: Int?
    let defendedTerritories: Int?
    let recapturedTerritories: Int?
    
    let isStreak: Bool
    let isRecord: Bool
    let hasBadge: Bool
}

@MainActor
class WorkoutsViewModel: ObservableObject {
    @Published var workouts: [WorkoutItemViewData] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let activityStore: ActivityStore
    private let territoryService: TerritoryService
    
    @Published var isImporting = false
    
    init(activityStore: ActivityStore? = nil, territoryService: TerritoryService? = nil) {
        self.activityStore = activityStore ?? ActivityStore()
        self.territoryService = territoryService ?? TerritoryService(territoryStore: TerritoryStore())
        
        loadWorkouts()
        
        // Fix missing XP for previously imported activities
        Task {
            await fixMissingXP()
        }
    }
    
    func loadWorkouts() {
        let activities = activityStore.fetchAllActivities()
        // Filter for last 7 days
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        self.workouts = activities
            .filter { $0.startDate >= sevenDaysAgo }
            .sorted(by: { $0.startDate > $1.startDate })
            .map { activity in
            WorkoutItemViewData(
                id: activity.id,
                type: activity.activityType,
                title: "\(activity.activityType.displayName) · \(formatDistance(activity.distanceMeters))",
                dateString: formatDate(activity.startDate),
                duration: formatDuration(activity.durationSeconds),
                pace: calculatePace(distance: activity.distanceMeters, duration: activity.durationSeconds, type: activity.activityType),
                xp: activity.xpBreakdown?.total,
                territoryXP: activity.xpBreakdown?.xpTerritory,
                territoryCount: activity.territoryStats?.newCellsCount,
                newTerritories: activity.territoryStats?.newCellsCount,
                defendedTerritories: activity.territoryStats?.defendedCellsCount,
                recapturedTerritories: activity.territoryStats?.recapturedCellsCount,
                isStreak: (activity.xpBreakdown?.xpStreak ?? 0) > 0,
                isRecord: (activity.xpBreakdown?.xpWeeklyRecord ?? 0) > 0,
                hasBadge: (activity.xpBreakdown?.xpBadges ?? 0) > 0
            )
        }
    }
    
    func refresh() async {
        importFromHealthKit()
    }
    
    func importFromHealthKit() {
        guard !isImporting else { return }
        isImporting = true
        isLoading = true
        print("Starting automatic HealthKit import...")
        
        // Request permissions first
        HealthKitManager.shared.requestPermissions { [weak self] success, error in
            guard let self = self else { return }
            
            if !success {
                print("HealthKit authorization failed or denied.")
                DispatchQueue.main.async { 
                    self.isImporting = false 
                    self.isLoading = false
                }
                return
            }
            
            HealthKitManager.shared.fetchOutdoorWorkouts { [weak self] workouts, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching workouts: \(error.localizedDescription)")
                    DispatchQueue.main.async { 
                        self.isImporting = false
                        self.isLoading = false
                    }
                    return
                }
                
                guard let workouts = workouts, !workouts.isEmpty else {
                    print("No outdoor workouts found in HealthKit.")
                    DispatchQueue.main.async { 
                        self.isImporting = false
                        self.isLoading = false
                    }
                    return
                }
                
                // Filter out duplicates AND restrict to last 7 days
                let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                
                let newWorkouts = workouts.filter { workout in
                    // 1. Date Check: Must be within last 7 days
                    guard workout.startDate >= sevenDaysAgo else { return false }
                    
                    // 2. Duplicate Check: Must not already exist
                    return !self.activityStore.activities.contains(where: { $0.startDate == workout.startDate })
                }
                
                guard !newWorkouts.isEmpty else {
                    print("No new workouts to import.")
                    DispatchQueue.main.async { 
                        self.isImporting = false
                        self.isLoading = false
                    }
                    return
                }
                
                print("Found \(newWorkouts.count) new workouts. Processing in background...")
                
                // Process in background to avoid blocking Main Thread
                DispatchQueue.global(qos: .utility).async {
                    var newSessions: [ActivitySession] = []
                    let group = DispatchGroup()
                    let semaphore = DispatchSemaphore(value: 1) // Process 1 at a time to save memory
                    
                    for workout in newWorkouts {
                        semaphore.wait() // Wait for slot
                        group.enter()
                        
                        HealthKitManager.shared.fetchRoute(for: workout) { routePoints, error in
                            defer { 
                                group.leave()
                                semaphore.signal() // Release slot
                            }
                            
                            if let points = routePoints, !points.isEmpty {
                                let type: ActivityType
                                switch workout.workoutActivityType {
                                case .running: type = .run
                                case .walking: type = .walk
                                case .cycling: type = .bike
                                default: type = .otherOutdoor
                                }
                                
                                let session = ActivitySession(
                                    startDate: workout.startDate,
                                    endDate: workout.endDate,
                                    activityType: type,
                                    distanceMeters: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                                    durationSeconds: workout.duration,
                                    route: points
                                )
                                
                                DispatchQueue.global(qos: .utility).sync {
                                    newSessions.append(session)
                                }
                            }
                        }
                    }
                    
                    group.wait() // Wait for all to finish
                    
                    // Save all at once on Main Thread
                    DispatchQueue.main.async {
                        if !newSessions.isEmpty {
                            // Sort by date ascending to ensure correct historical replay
                            let sortedSessions = newSessions.sorted { $0.startDate < $1.startDate }
                            
                            print("Saving \(sortedSessions.count) imported activities...")
                            
                            // 1. Save Activities
                            self.activityStore.saveActivities(sortedSessions)
                            
                            // 2. Process Territories & XP (Individually for accuracy)
                            Task {
                                let userId = AuthenticationService.shared.userId ?? "unknown_user"
                                var totalNewCells = 0
                                
                                do {
                                    let context = try await GamificationRepository.shared.buildXPContext(for: userId)
                                    
                                    for session in sortedSessions {
                                        // A. Process Territories for THIS session
                                        // This updates the store immediately, so subsequent sessions see the updated state.
                                        // This ensures that if Session 1 conquers a cell, Session 2 (later) sees it as "Defended", not "New".
                                        let stats = self.territoryService.processActivity(session)
                                        totalNewCells += stats.newCellsCount
                                        
                                        // B. Calculate XP
                                        let breakdown = try await GamificationService.shared.computeXP(for: session, territoryStats: stats, context: context)
                                        
                                        // C. Update Session with Stats & XP
                                        var updatedSession = session
                                        updatedSession.xpBreakdown = breakdown
                                        updatedSession.territoryStats = stats
                                        self.activityStore.updateActivity(updatedSession)
                                        
                                        // D. Apply XP to User
                                        try await GamificationService.shared.applyXP(breakdown, to: userId, at: session.endDate)
                                    }
                                    
                                    // 3. Post to Feed (Summary)
                                    if totalNewCells > 0 {
                                        let userName = AuthenticationService.shared.userName ?? "Un aventurero"
                                        
                                        let event = FeedEvent(
                                            id: nil,
                                            type: .territoryConquered,
                                            date: Date(),
                                            title: "Importación completada",
                                            subtitle: "Has reclamado \(totalNewCells) territorios de tus entrenamientos pasados.",
                                            xpEarned: totalNewCells * 10,
                                            userId: userId,
                                            relatedUserName: userName,
                                            miniMapRegion: nil,
                                            badgeName: nil,
                                            badgeRarity: nil,
                                            isPersonal: true
                                        )
                                        FeedRepository.shared.postEvent(event)
                                    }
                                    
                                } catch {
                                    print("Error processing import: \(error)")
                                }
                                
                                // Refresh UI
                                self.loadWorkouts()
                                self.isImporting = false
                                self.isLoading = false
                                print("Import complete.")
                            }
                        } else {
                            self.isImporting = false
                            self.isLoading = false
                        }
                    }
                }
            }
        }
    }
    
    private func fixMissingXP() async {
        let activities = activityStore.fetchAllActivities()
        let missingXP = activities.filter { $0.xpBreakdown == nil }
        
        guard !missingXP.isEmpty else { return }
        print("Fixing XP for \(missingXP.count) activities...")
        
        let userId = AuthenticationService.shared.userId ?? "unknown_user"
        
        do {
            let context = try await GamificationRepository.shared.buildXPContext(for: userId)
            
            for session in missingXP {
                // Compute XP (assuming 0 new territories for historical fix to avoid complexity)
                let zeroStats = TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0)
                let breakdown = try await GamificationService.shared.computeXP(for: session, territoryStats: zeroStats, context: context)
                
                // Update session in store ONLY (do not apply to user total again)
                var updatedSession = session
                updatedSession.xpBreakdown = breakdown
                activityStore.updateActivity(updatedSession)
            }
            
            // Reload UI
            await MainActor.run {
                self.loadWorkouts()
            }
            print("XP Fix complete.")
            
        } catch {
            print("Error fixing XP: \(error)")
        }
    }
    
    // MARK: - Formatting Helpers
    
    private func formatDistance(_ meters: Double) -> String {
        let km = meters / 1000.0
        return String(format: "%.1f km", km)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, d MMM · HH:mm"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date).capitalized
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: seconds) ?? "00:00"
    }
    
    private func calculatePace(distance: Double, duration: Double, type: ActivityType) -> String? {
        guard distance > 0, (type == .run || type == .walk) else { return nil }
        let paceSecondsPerKm = duration / (distance / 1000.0)
        let minutes = Int(paceSecondsPerKm / 60)
        let seconds = Int(paceSecondsPerKm.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d/km", minutes, seconds)
    }
}

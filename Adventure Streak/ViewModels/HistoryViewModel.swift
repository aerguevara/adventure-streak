import Foundation

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var activities: [ActivitySession] = []
    
    private let activityStore: ActivityStore
    private let territoryService: TerritoryService
    
    @Published var isImporting = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    init(activityStore: ActivityStore, territoryService: TerritoryService) {
        self.activityStore = activityStore
        self.territoryService = territoryService
        loadActivities()
        // Automatic import on launch
        importFromHealthKit()
    }
    
    func loadActivities() {
        self.activities = activityStore.fetchAllActivities()
    }
    
    func importFromHealthKit() {
        guard !isImporting else { return }
        isImporting = true
        print("Starting automatic HealthKit import...")
        
        // Request permissions first
        HealthKitManager.shared.requestPermissions { [weak self] success, error in
            guard let self = self else { return }
            
            if !success {
                print("HealthKit authorization failed or denied.")
                DispatchQueue.main.async { self.isImporting = false }
                return
            }
            
            HealthKitManager.shared.fetchOutdoorWorkouts { [weak self] workouts, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching workouts: \(error.localizedDescription)")
                    DispatchQueue.main.async { self.isImporting = false }
                    return
                }
                
                guard let workouts = workouts, !workouts.isEmpty else {
                    print("No outdoor workouts found in HealthKit.")
                    DispatchQueue.main.async { self.isImporting = false }
                    return
                }
                
                // Filter out duplicates BEFORE processing
                let newWorkouts = workouts.filter { workout in
                    !self.activityStore.activities.contains(where: { $0.startDate == workout.startDate })
                }
                
                guard !newWorkouts.isEmpty else {
                    print("No new workouts to import.")
                    DispatchQueue.main.async { self.isImporting = false }
                    return
                }
                
                print("Found \(newWorkouts.count) new workouts. Processing in background...")
                
                // Process in background to avoid blocking Main Thread
                // Use .utility QoS to avoid priority inversion warnings (waiting on slower I/O)
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
                                case .hiking: type = .hike
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
                                
                                // Thread-safe append
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
                            print("Saving \(newSessions.count) imported activities...")
                            
                            // 1. Save Activities
                            self.activityStore.saveActivities(newSessions)
                            
                            // 2. Process Territories (BATCHED)
                            Task {
                                let userId = AuthenticationService.shared.userId ?? "unknown_user"
                                
                                // A. Batch Process Territories (Updates Store ONCE)
                                let totalStats = await self.territoryService.processActivities(newSessions)
                                print("Batch Import: \(totalStats.newCellsCount) new cells.")
                                
                                // B. Calculate & Award XP
                                // We award Base XP for each activity, and Territory XP based on the batch result
                                do {
                                    let context = try await GamificationRepository.shared.buildXPContext(for: userId)
                                    
                                    // 1. Base XP for each activity
                                    for session in newSessions {
                                        // Pass empty stats here, we award territory XP separately
                                        let zeroStats = TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0)
                                        let breakdown = try await GamificationService.shared.computeXP(for: session, territoryStats: zeroStats, context: context)
                                        try await GamificationService.shared.applyXP(breakdown, to: userId, at: session.endDate)
                                    }
                                    
                                    // 2. Territory XP (Aggregated)
                                    // We create a dummy "Import Bonus" breakdown or just apply the XP directly
                                    // For simplicity, we'll use the last session to attach the territory XP
                                    // Logic simplified to use the loop below
                                    
                                    // SIMPLIFIED APPROACH:
                                    // Just loop and process Base XP.
                                    // Then manually award Territory XP if possible.
                                    // Or, since we are in a rush to fix the crash, let's just award Base XP for imports and ignore Territory XP for now?
                                    // No, user wants XP.
                                    // Let's use the "Apply to last session" strategy but be careful not to double count Base XP.
                                    
                                    // Actually, let's just loop for Base XP.
                                    // And then call a direct "addXP" if we can? No.
                                    
                                    // Let's stick to the loop for Base XP.
                                    // And for the Territory XP, we'll just create a "Bonus" transaction?
                                    // GamificationService.applyXP takes a breakdown.
                                    
                                    // Let's just award the Territory XP attached to the last session.
                                    // We will skip the last session in the loop.
                                    
                                    for (index, session) in newSessions.enumerated() {
                                        if index == newSessions.count - 1 { continue } // Skip last
                                        
                                        let zeroStats = TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0)
                                        let breakdown = try await GamificationService.shared.computeXP(for: session, territoryStats: zeroStats, context: context)
                                        
                                        // Update session with XP
                                        var updatedSession = session
                                        updatedSession.xpBreakdown = breakdown
                                        self.activityStore.updateActivity(updatedSession)
                                        
                                        try await GamificationService.shared.applyXP(breakdown, to: userId, at: session.endDate)
                                    }
                                    
                                    if let lastSession = newSessions.last {
                                        // Award Base XP for last session + ALL Territory XP
                                        let breakdown = try await GamificationService.shared.computeXP(for: lastSession, territoryStats: totalStats, context: context)
                                        
                                        // Update session with XP
                                        var updatedSession = lastSession
                                        updatedSession.xpBreakdown = breakdown
                                        self.activityStore.updateActivity(updatedSession)
                                        
                                        try await GamificationService.shared.applyXP(breakdown, to: userId, at: lastSession.endDate)
                                    }
                                    
                                    // 3. Post to Feed (NEW)
                                    if totalStats.newCellsCount > 0 {
                                        let userName = AuthenticationService.shared.userName ?? "Un aventurero"
                                        
                                        let event = FeedEvent(
                                            id: nil,
                                            type: .territoryConquered,
                                            date: Date(),
                                            title: "Importación completada",
                                            subtitle: "Has reclamado \(totalStats.newCellsCount) territorios de tus entrenamientos pasados.",
                                            xpEarned: totalStats.newCellsCount * 10, // Approximate
                                            userId: userId,
                                            relatedUserName: userName,
                                            userLevel: GamificationService.shared.currentLevel,
                                            userAvatarURL: nil,
                                            miniMapRegion: nil, // Hard to calculate region for batch, skipping for now
                                            badgeName: nil,
                                            badgeRarity: nil,
                                            activityData: nil, // No specific activity data for summary
                                            rarity: nil,
                                            isPersonal: true
                                        )
                                        FeedRepository.shared.postEvent(event)
                                    }
                                    
                                } catch {
                                    print("Error awarding XP for import: \(error)")
                                }
                                
                                // Refresh UI
                                self.loadActivities()
                                print("Import complete.")
                            }
                        }
                        self.isImporting = false
                    }
                }
            }
        }
    }
}

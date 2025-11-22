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
                            
                            // 2. Process Territories & XP
                            Task {
                                let userId = AuthenticationService.shared.userId ?? "unknown_user"
                                
                                for session in newSessions {
                                    // A. Process Territory
                                    let stats = self.territoryService.processActivity(session)
                                    
                                    // B. Calculate & Award XP
                                    do {
                                        // We fetch context fresh for each to ensure streaks/records update correctly sequentially
                                        // Optimization: In a real app, we might batch this or update context locally.
                                        let context = try await GamificationRepository.shared.buildXPContext(for: userId)
                                        let breakdown = try await GamificationService.shared.computeXP(for: session, territoryStats: stats, context: context)
                                        
                                        // Update session with breakdown (optional, if we want to persist it back to activityStore)
                                        // session.xpBreakdown = breakdown 
                                        // Note: session is a struct, so we'd need to update it in the array and re-save if we want the breakdown stored.
                                        // For MVP, just applying to User is enough.
                                        
                                        try await GamificationService.shared.applyXP(breakdown, to: userId, at: session.endDate)
                                        print("Imported Activity XP: \(breakdown.total)")
                                    } catch {
                                        print("Error awarding XP for import: \(error)")
                                    }
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

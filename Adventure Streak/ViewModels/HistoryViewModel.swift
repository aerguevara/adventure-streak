import Foundation
import HealthKit
import Combine
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var activities: [ActivitySession] = []
    
    private let activityStore: ActivityStore
    private let territoryService: TerritoryService
    private let configService: GameConfigService
    private let authService: AuthenticationService
    private let pendingRouteStore: PendingRouteStore
    
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isImporting = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    init(
        activityStore: ActivityStore,
        territoryService: TerritoryService,
        configService: GameConfigService,
        pendingRouteStore: PendingRouteStore = PendingRouteStore.shared,
        authService: AuthenticationService = .shared
    ) {
        self.activityStore = activityStore
        self.territoryService = territoryService
        self.configService = configService
        self.pendingRouteStore = pendingRouteStore
        self.authService = authService
        
        setupSubscriptions()
        loadActivities()
        
        Task {
            await configService.loadConfigIfNeeded()
            await MainActor.run {
                self.importFromHealthKit()
            }
        }
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    private func setupSubscriptions() {
        activityStore.$activities
            .receive(on: RunLoop.main)
            .sink { [weak self] updatedActivities in
                self?.activities = updatedActivities
            }
            .store(in: &cancellables)
    }
    
    // Eliminado: startObservingActivities() - Ahora lo gestiona ActivityStore
    
    func loadActivities() {
        self.activities = activityStore.fetchAllActivities()
    }
    
    func importFromHealthKit() {
        guard authService.userId != nil else {
            print("History import -> aborted: no authenticated user")
            return
        }
        guard configService.config.loadHistoricalWorkouts else {
            print("Historical import disabled by config")
            return
        }
        
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
            
            HealthKitManager.shared.fetchWorkouts { [weak self] workouts, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching workouts: \(error.localizedDescription)")
                    DispatchQueue.main.async { self.isImporting = false }
                    return
                }
                
                guard let workouts = workouts, !workouts.isEmpty else {
                    print("No se encontraron entrenos en HealthKit.")
                    DispatchQueue.main.async { self.isImporting = false }
                    return
                }
                
                // Filter out duplicates BEFORE processing and respect configured lookback
                let cutoffDate = self.configService.cutoffDate()
                let newWorkouts = workouts.filter { workout in
                    guard workout.startDate >= cutoffDate else { return false }
                    return !self.activityStore.activities.contains(where: { $0.startDate == workout.startDate })
                }
                
                guard !newWorkouts.isEmpty else {
                    print("No new workouts to import.")
                    DispatchQueue.main.async { self.isImporting = false }
                    return
                }
                
                print("Found \(newWorkouts.count) new workouts. Processing in background...")
                
                // Process in background to avoid blocking Main Thread
                // Use .utility QoS to avoid priority inversion warnings (waiting on slower I/O)
                let config = self.configService.config
                let pendingStore = self.pendingRouteStore
                DispatchQueue.global(qos: .utility).async {
                    var newSessions: [ActivitySession] = []
                    let group = DispatchGroup()
                    let semaphore = DispatchSemaphore(value: 1) // Process 1 at a time to save memory
                    
                    for workout in newWorkouts {
                        semaphore.wait() // Wait for slot
                        group.enter()
                        
                        let type = self.activityType(for: workout)
                        let bundleId = workout.sourceRevision.source.bundleIdentifier
                        let sourceName = workout.sourceRevision.source.name
                        let requiresRoute = config.requiresRoute(for: bundleId) && type.isOutdoor
                        
                        HealthKitManager.shared.fetchRoute(for: workout) { result in
                            defer { 
                                group.leave()
                                semaphore.signal() // Release slot
                            }
                            
                            let distanceMeters = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
                            let durationSeconds = workout.duration
                            let name = self.workoutName(for: workout)
                            
                            switch result {
                            case .success(let routePoints):
                                if requiresRoute && routePoints.isEmpty {
                                    Task { @MainActor in
                                        self.handlePendingRoute(
                                            workout: workout,
                                            type: type,
                                            workoutName: name,
                                            sourceBundleId: bundleId,
                                            sourceName: sourceName,
                                            status: .missingRoute,
                                            errorDescription: nil
                                        )
                                    }
                                    return
                                }
                                
                                pendingStore.remove(workoutId: workout.uuid)
                                
                                let session = ActivitySession(
                                    id: workout.uuid, // stable id from HKWorkout to prevent duplicates
                                    startDate: workout.startDate,
                                    endDate: workout.endDate,
                                    activityType: type,
                                    distanceMeters: distanceMeters,
                                    durationSeconds: durationSeconds,
                                    workoutName: name,
                                    route: routePoints
                                )
                                
                                // Thread-safe append
                                DispatchQueue.global(qos: .utility).sync {
                                    newSessions.append(session)
                                }
                            case .emptySeries:
                                if requiresRoute {
                                    Task { @MainActor in
                                        self.handlePendingRoute(
                                            workout: workout,
                                            type: type,
                                            workoutName: name,
                                            sourceBundleId: bundleId,
                                            sourceName: sourceName,
                                            status: .missingRoute,
                                            errorDescription: nil
                                        )
                                    }
                                    return
                                }
                                
                                let session = ActivitySession(
                                    id: workout.uuid,
                                    startDate: workout.startDate,
                                    endDate: workout.endDate,
                                    activityType: type,
                                    distanceMeters: distanceMeters,
                                    durationSeconds: durationSeconds,
                                    workoutName: name,
                                    route: []
                                )
                                
                                DispatchQueue.global(qos: .utility).sync {
                                    newSessions.append(session)
                                }
                            case .error(let error):
                                if requiresRoute {
                                    Task { @MainActor in
                                        self.handlePendingRoute(
                                            workout: workout,
                                            type: type,
                                            workoutName: name,
                                            sourceBundleId: bundleId,
                                            sourceName: sourceName,
                                            status: .fetchError,
                                            errorDescription: error.localizedDescription
                                        )
                                    }
                                    return
                                }
                                
                                print("⚠️ Route fetch error for optional source \(bundleId): \(error.localizedDescription)")
                                
                                let session = ActivitySession(
                                    id: workout.uuid,
                                    startDate: workout.startDate,
                                    endDate: workout.endDate,
                                    activityType: type,
                                    distanceMeters: distanceMeters,
                                    durationSeconds: durationSeconds,
                                    workoutName: name,
                                    route: []
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
                            print("Saving \(newSessions.count) imported activities...")
                            
                            // 1. Save Activities locally
                            self.activityStore.saveActivities(newSessions)
                            
                            // 1b. Persist remotely in independent collection
                            if let userId = AuthenticationService.shared.userId {
                                Task {
                                    await ActivityRepository.shared.saveActivities(newSessions, userId: userId)
                                }
                            }
                            
                            // 2. Process Territories (BATCHED)
                            Task {
                                guard let userId = AuthenticationService.shared.userId else {
                                    print("Batch Import (History) -> aborted: no authenticated user")
                                    return
                                }
                                
                                // A. Batch Process Territories (Updates Store ONCE)
                                let userName = AuthenticationService.shared.userName
                                let totalStats = await self.territoryService.processActivities(newSessions, ownerUserId: userId, ownerDisplayName: userName)
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
    
    private func handlePendingRoute(
        workout: HKWorkout,
        type: ActivityType,
        workoutName: String?,
        sourceBundleId: String,
        sourceName: String,
        status: PendingRouteStatus,
        errorDescription: String?
    ) {
        let id = workout.uuid
        let distance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
        let existing = pendingRouteStore.find(workoutId: workout.uuid)
        let retryCount = (existing?.retryCount ?? 0) + 1
        let pending = PendingRouteImport(
            id: workout.uuid,
            startDate: workout.startDate,
            endDate: workout.endDate,
            activityType: type,
            distanceMeters: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
            durationSeconds: workout.duration,
            workoutName: workoutName,
            sourceBundleId: sourceBundleId,
            sourceName: sourceName,
            status: status,
            lastErrorDescription: errorDescription,
            retryCount: retryCount,
            lastAttemptAt: Date()
        )
        
        pendingRouteStore.upsert(pending)
#if canImport(FirebaseCrashlytics)
        recordRouteNonFatal(
            workout: workout,
            type: type,
            sourceBundleId: sourceBundleId,
            sourceName: sourceName,
            status: status,
            errorDescription: errorDescription,
            retryCount: retryCount
        )
#endif
        
        DispatchQueue.main.async {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            let dateText = formatter.string(from: workout.startDate)
            let reason = status == .fetchError ? "por un error al leer la ruta" : "porque la ruta aún no está disponible"
            self.alertMessage = "La actividad del \(dateText) no se cargó \(reason). Reintentaremos automáticamente."
            self.showAlert = true
            let distanceText = String(format: "%.1fkm", distance / 1000)
            let errText = errorDescription ?? "-"
            print("⏸️ Pending route [history]. id:\(id) type:\(type) bundle:\(sourceBundleId) source:\(sourceName) status:\(status.rawValue) err:\(errText) distance:\(distanceText) retry:\(retryCount)")
        }
    }
    
#if canImport(FirebaseCrashlytics)
    private func recordRouteNonFatal(
        workout: HKWorkout,
        type: ActivityType,
        sourceBundleId: String,
        sourceName: String,
        status: PendingRouteStatus,
        errorDescription: String?,
        retryCount: Int
    ) {
        let crashlytics = Crashlytics.crashlytics()
        let userId = AuthenticationService.shared.userId ?? "unauthenticated"
        crashlytics.log("Route import issue (history): status=\(status.rawValue) bundle=\(sourceBundleId) retry=\(retryCount)")
        crashlytics.setCustomValue(workout.uuid.uuidString, forKey: "route_workout_uuid")
        crashlytics.setCustomValue(type.rawValue, forKey: "route_activity_type")
        crashlytics.setCustomValue(sourceBundleId, forKey: "route_source_bundle")
        crashlytics.setCustomValue(sourceName, forKey: "route_source_name")
        crashlytics.setCustomValue(true, forKey: "route_required")
        crashlytics.setCustomValue(retryCount, forKey: "route_retry_count")
        crashlytics.setCustomValue(errorDescription ?? "", forKey: "route_error_description")
        crashlytics.setCustomValue(userId, forKey: "route_user_id")
        let distanceKm = (workout.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000.0
        crashlytics.setCustomValue(String(format: "%.2f", distanceKm), forKey: "route_distance_km")
        crashlytics.setCustomValue(workout.duration, forKey: "route_duration_seconds")
        
        let nsError = NSError(
            domain: "com.adventurestreak.route",
            code: status == .fetchError ? 2 : 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Route import \(status.rawValue) for \(sourceBundleId)",
                "sourceName": sourceName,
                "requiresRoute": true,
                "retryCount": retryCount
            ]
        )
        crashlytics.record(error: nsError)
    }
#endif
    
    nonisolated private func activityType(for workout: HKWorkout) -> ActivityType {
        let isIndoor = (workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool) ?? false
        
        switch workout.workoutActivityType {
        case .traditionalStrengthTraining, .functionalStrengthTraining, .highIntensityIntervalTraining:
            return .indoor
        case .running:
            return isIndoor ? .indoor : .run
        case .walking:
            return isIndoor ? .indoor : .walk
        case .cycling:
            return isIndoor ? .indoor : .bike
        case .hiking:
            return .hike
        default:
            return isIndoor ? .indoor : .otherOutdoor
        }
    }
    
    nonisolated private func workoutName(for workout: HKWorkout) -> String {
        if let title = workout.metadata?["HKMetadataKeyWorkoutTitle"] as? String, !title.isEmpty {
            return title
        }
        if let brand = workout.metadata?[HKMetadataKeyWorkoutBrandName] as? String, !brand.isEmpty {
            return brand
        }
        
        return fallbackWorkoutName(for: workout.workoutActivityType)
    }
    
    nonisolated private func fallbackWorkoutName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .hiking: return "Hiking"
        case .traditionalStrengthTraining: return "Traditional Strength Training"
        case .functionalStrengthTraining: return "Functional Strength Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .flexibility: return "Flexibility"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        default: return "Workout"
        }
    }
}

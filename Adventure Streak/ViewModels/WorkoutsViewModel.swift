import Foundation
import Combine
import SwiftUI
import HealthKit
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

struct WorkoutItemViewData: Identifiable {
    let id: UUID
    let type: ActivityType
    let title: String
    let date: Date // NEW: For recency check
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
    
    // NEW: Mission info
    let missionName: String?
    let missionDescription: String?
    // NEW: Horarios
    let startDateTime: String
    let endDateTime: String
    
    // NEW: Rarity Logic
    var rarity: String {
        let totalXP = xp ?? 0
        if totalXP >= 200 { return "Épica" }
        if totalXP >= 80 { return "Rara" }
        return "Común"
    }
    
    var rarityColor: Color {
        switch rarity {
        case "Épica": return Color(hex: "C084FC") // Purple
        case "Rara": return Color(hex: "4DA8FF") // Blue
        default: return Color.gray
        }
    }
}

@MainActor
class WorkoutsViewModel: ObservableObject {
    @Published var workouts: [WorkoutItemViewData] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var importTotal: Int = 0
    @Published var importProcessed: Int = 0
    
    @Published var showProcessingSummary: Bool = false {
        didSet {
            if !showProcessingSummary {
                // Cleanup: prevents accumulation and stale data
                self.processingSummaryData = nil
                self.isSummaryTriggered = false
                self.importTotal = 0
                self.importProcessed = 0
                self.isImporting = false
            }
        }
    }
    @Published var processingSummaryData: GlobalImportSummary?
    
    private let activityStore: ActivityStore
    private let territoryService: TerritoryService
    private let configService: GameConfigService
    private let pendingRouteStore: PendingRouteStore
    private var cancellables = Set<AnyCancellable>()
    private var processingCancellable: AnyCancellable?
    private var isCheckingForWorkouts = false
    
    @Published var isImporting = false
    
    init(
        activityStore: ActivityStore? = nil,
        territoryService: TerritoryService? = nil,
        configService: GameConfigService,
        pendingRouteStore: PendingRouteStore = PendingRouteStore.shared
    ) {
        self.activityStore = activityStore ?? ActivityStore.shared
        self.territoryService = territoryService ?? TerritoryService(territoryStore: TerritoryStore.shared)
        self.configService = configService
        self.pendingRouteStore = pendingRouteStore
        
        Task {
            await configService.loadConfigIfNeeded()
            await MainActor.run {
                self.loadWorkouts()
            }
        }

        // Recargar cuando el store de actividades cambie (ej. tras volver a iniciar sesión y sincronizar desde remoto)
        self.activityStore.$activities
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadWorkouts()
            }
            .store(in: &cancellables)
        
        configService.$config
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadWorkouts()
            }
            .store(in: &cancellables)
            
        // NEW: React to login/logout
        AuthenticationService.shared.$userId
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadWorkouts()
            }
            .store(in: &cancellables)
            
        // NEW: Trigger import safely only after initial Firestore sync
        self.activityStore.$isSynced
            .receive(on: RunLoop.main)
            .filter { $0 } // Only when true
            .first() // Only the first time it becomes true
            .sink { [weak self] _ in
                print("🔄 ActivityStore synced -> Triggering initial HealthKit check...")
                self?.importFromHealthKit()
            }
            .store(in: &cancellables)
    }
    
    func loadWorkouts() {
        let activities = activityStore.fetchAllActivities()
        let cutoffDate = configService.cutoffDate()
        
        self.workouts = activities
            .filter { $0.startDate >= cutoffDate }
            .sorted(by: { $0.startDate > $1.startDate })
            .map { activity in
                let titlePrefix = activity.workoutName ?? activity.activityType.displayName
                // Filter out non-outdoor/processed activities from "Stolen" logic if needed, but for now map direct
                return WorkoutItemViewData(
                    id: activity.id,
                    type: activity.activityType,
                    title: "\(titlePrefix) · \(formatDistance(activity.distanceMeters))",
                    date: activity.endDate, // NEW
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
                    hasBadge: (activity.xpBreakdown?.xpBadges ?? 0) > 0,
                    missionName: activity.missions?.first?.name,
                    missionDescription: activity.missions?.first?.description,
                    startDateTime: formatDateTime(activity.startDate),
                    endDateTime: formatDateTime(activity.endDate)
                )
            }
        
        // DEBUG: Log mission data
        print("📊 Loaded \(self.workouts.count) workouts")
        for workout in self.workouts.prefix(3) {
            print("   Workout: \(workout.title)")
            print("   Mission: \(workout.missionName ?? "NONE")")
        }
    }
    
    func refresh() async {
        print("Pull-to-refresh -> refresh()")
        importFromHealthKit()
    }
    
    func retryPendingImports() {
        let pendingIds = Set(pendingRouteStore.pending.map { $0.id })
        guard !pendingIds.isEmpty else {
            print("Retry pending -> no pending route imports")
            return
        }
        
        isImporting = true
        isLoading = true
        errorMessage = nil
        
        HealthKitManager.shared.requestPermissions { [weak self] success, _ in
            guard let self else { return }
            guard success else {
                DispatchQueue.main.async {
                    self.isImporting = false
                    self.isLoading = false
                }
                return
            }
            
            HealthKitManager.shared.fetchWorkouts { [weak self] workouts, error in
                guard let self else { return }
                
                if let error {
                    print("Retry pending -> fetch error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isImporting = false
                        self.isLoading = false
                    }
                    return
                }
                
                guard let workouts, !workouts.isEmpty else {
                    print("Retry pending -> no workouts in HK")
                    DispatchQueue.main.async {
                        self.isImporting = false
                        self.isLoading = false
                    }
                    return
                }
                
                let target = workouts.filter { pendingIds.contains($0.uuid) }
                guard !target.isEmpty else {
                    print("Retry pending -> none of the pending workouts found in HK")
                    DispatchQueue.main.async {
                        self.isImporting = false
                        self.isLoading = false
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.importTotal = target.count
                    self.importProcessed = 0
                }
                
                let config = self.configService.config
                let pendingStore = self.pendingRouteStore
                
                DispatchQueue.global(qos: .utility).async {
                    var newSessions: [ActivitySession] = []
                    let group = DispatchGroup()
                    let semaphore = DispatchSemaphore(value: 1)
                    
                    for workout in target {
                        semaphore.wait()
                        group.enter()
                        
                        let type = self.activityType(for: workout)
                        let bundleId = workout.sourceRevision.source.bundleIdentifier
                        let sourceName = workout.sourceRevision.source.name
                        let requiresRoute = config.requiresRoute(for: bundleId) && type.isOutdoor
                        
                        HealthKitManager.shared.fetchRoute(for: workout) { result in
                            defer {
                                group.leave()
                                semaphore.signal()
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
                                    id: workout.uuid,
                                    startDate: workout.startDate,
                                    endDate: workout.endDate,
                                    activityType: type,
                                    distanceMeters: distanceMeters,
                                    durationSeconds: durationSeconds,
                                    workoutName: name,
                                    route: routePoints
                                )
                                
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
                    
                    group.wait()
                    
                    DispatchQueue.main.async {
                        if !newSessions.isEmpty {
                            let sortedSessions = newSessions.sorted { $0.endDate < $1.endDate }
                            Task {
                                guard let userId = AuthenticationService.shared.userId else {
                                    print("Retry pending -> aborted: user logged out during fetch")
                                    Task { @MainActor in
                                        self.isImporting = false
                                        self.isLoading = false
                                    }
                                    return
                                }
                                let userName = AuthenticationService.shared.userName
                                
                                defer {
                                    Task { @MainActor in
                                        self.importTotal = 0
                                        self.importProcessed = 0
                                        self.isImporting = false
                                        self.isLoading = false
                                    }
                                }
                                do {
                                    for session in sortedSessions {
                                        let stats = try await GameEngine.shared.completeActivity(session, for: userId, userName: userName)
                                        await MainActor.run {
                                            self.importProcessed += 1
                                        }
                                        print("Retry pending -> processed stats \(stats)")
                                    }
                                } catch {
                                    print("Retry pending -> processing error: \(error)")
                                }
                                await MainActor.run {
                                    self.loadWorkouts()
                                    self.isImporting = false
                                    self.isLoading = false
                                }
                            }
                        } else {
                            self.importTotal = 0
                            self.importProcessed = 0
                            self.isImporting = false
                            self.isLoading = false
                        }
                    }
                }
            }
        }
    }
    
    // Monitor specific activities for server-side completion
    private var isSummaryTriggered = false 

    private func monitorProcessing(for activityIds: [UUID]) {
        guard !activityIds.isEmpty else { return }
        
        print("⏳ Monitoring processing for \(activityIds.count) activities...")
        
        // Reset summary
        self.processingSummaryData = GlobalImportSummary()
        self.showProcessingSummary = false
        self.isSummaryTriggered = false
        
        // Cancel previous monitoring
        processingCancellable?.cancel()
        
        // Create a dedicated publisher to watch these specific IDs
        processingCancellable = activityStore.$activities
            .receive(on: RunLoop.main)
            .map { allActivities in
                allActivities.filter { activityIds.contains($0.id) }
            }
            .sink { [weak self] targetActivities in
                guard let self = self else { return }
                
                // Check progress - wait for status COMPLETED + XP + TERRITORY STATS
                let completed = targetActivities.filter { 
                    ($0.processingStatus == .completed && $0.xpBreakdown != nil && $0.territoryStats != nil) || 
                    $0.processingStatus == .error 
                }
                // Update imported count for progress bar
                self.importProcessed = completed.count
                
                if completed.count == activityIds.count && !targetActivities.isEmpty && !self.isSummaryTriggered {
                    print("✅ [Monitor] All activities processed! Waiting 1s for consistency...")
                    self.isSummaryTriggered = true
                    
                    // Aggregate stats asynchronously to fetch territories
                    Task {
                        // Safety delay to allow Firestore subcollections to propagate
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        
                        var summary = GlobalImportSummary()
                        for activity in completed {
                            // Extract stats
                            let stats = activity.territoryStats ?? TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0)
                            let xp = activity.xpBreakdown?.total ?? 0

                            let victims = activity.conqueredVictims ?? []
                            let loc = activity.locationLabel
                            
                            // Fetch actual territory geometries from repository
                            let territories = await TerritoryRepository.shared.fetchConqueredTerritories(forActivityId: activity.id.uuidString)
                            
                            // Rarity Logic (Shared with ItemView)
                            let rarity: String
                            if xp >= 200 { rarity = "Épica" }
                            else if xp >= 80 { rarity = "Rara" }
                            else { rarity = "Común" }
                            
                            summary.add(
                                stats: stats, 
                                xp: xp, 
                                victimNames: victims, 
                                location: loc, 
                                route: activity.route,
                                missions: activity.missions,
                                rarity: rarity,
                                territories: territories
                            )
                        }
                        
                        await MainActor.run {
                                self.processingSummaryData = summary
                                self.showProcessingSummary = true
                                
                                // Stop monitoring this batch
                                self.processingCancellable?.cancel()
                                
                                // FINAL RESET
                                self.isImporting = false
                                self.importTotal = 0
                                self.importProcessed = 0
                            }
                        }
                    }
                }
    }
    
    func importFromHealthKit() {
        // Require authenticated user to avoid importing under "unknown_user"
        guard let _ = AuthenticationService.shared.userId else {
            print("Import HK -> aborted: no authenticated user")
            return
        }
        
        // NEW: Prevent race condition (importing against empty local store before sync)
        guard activityStore.isSynced else {
            print("⏳ HK Import deferred: Waiting for ActivityStore sync.")
            return
        }

        // Recuperación: si quedó marcado importando pero sin progreso, reiniciar flags
        if isImporting && importTotal == 0 && importProcessed == 0 {
            print("Import HK -> recuperando estado (importing=true pero sin progreso), reseteando flags")
            isImporting = false
            isLoading = false
        }
        
        print("Import HK -> isImporting:\(isImporting) loadHistorical:\(configService.config.loadHistoricalWorkouts) lookback:\(configService.config.workoutLookbackDays)")
        guard !isImporting else {
            print("Import HK -> aborted, already importing")
            return
        }
        
        guard configService.config.loadHistoricalWorkouts else {
            print("Import HK -> disabled by config")
            errorMessage = "La importación de entrenos históricos está desactivada en la configuración."
            isImporting = false
            isLoading = false
            importTotal = 0
            importProcessed = 0
            return
        }
        
        print("Starting automatic HealthKit check (silent)...")

        // Watchdog: si en 12s no hubo progreso, resetea flags para permitir reintento
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            guard let self = self else { return }
            if (self.isImporting || self.isCheckingForWorkouts) && self.importProcessed == 0 && self.importTotal == 0 {
                print("Import HK -> watchdog sin progreso, reseteando flags (checking/importing)")
                self.isImporting = false
                self.isCheckingForWorkouts = false
                self.isLoading = false
            }
        }
        
        // Request permissions first
        HealthKitManager.shared.requestPermissions { [weak self] success, error in
            guard let self = self else { return }
            
            // Prevent concurrent calls
            guard !self.isImporting && !self.isCheckingForWorkouts else {
                print("⚠️ Import or check already in progress. Skipping.")
                return 
            }
            
            self.isCheckingForWorkouts = true
            
            // We don't set isImporting = true here anymore to avoid UI flickering
            // if we discover there are no new workouts.
            
            guard success else {
                print("Error HealthKit Auth: \(String(describing: error?.localizedDescription))")
                DispatchQueue.main.async {
                    self.isCheckingForWorkouts = false
                    self.isImporting = false
                    self.isLoading = false
                    self.importTotal = 0
                    self.importProcessed = 0
                }
                return
            }
            
            print("HK import -> permisos OK, solicitando workouts...")
            
            HealthKitManager.shared.fetchWorkouts { [weak self] workouts, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching workouts: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isCheckingForWorkouts = false
                        self.isImporting = false
                        self.isLoading = false
                        self.importTotal = 0
                        self.importProcessed = 0
                    }
                    return
                }
                
                guard let workouts = workouts, !workouts.isEmpty else {
                    print("No se encontraron entrenos en HealthKit.")
                    DispatchQueue.main.async {
                        self.isCheckingForWorkouts = false
                        self.isImporting = false
                        self.isLoading = false
                        self.importTotal = 0
                        self.importProcessed = 0
                    }
                    return
                }
                
                // Log de entrada
                print("HK import — recibidos \(workouts.count) entrenos.")
                
                // Fetch Remote IDs to check against existing cloud data (even if not synced locally yet)
                let cutoffDate = self.configService.cutoffDate()
                let userId = AuthenticationService.shared.userId ?? "unknown_user"
                
                // Async fetch inside MainActor context? 
                // We are inside a closure. We should use Task to fetch remote IDs, then proceed.
                Task {
                    let remoteIds = await ActivityRepository.shared.fetchAllActivityIds(userId: userId)
                    let localIds = Set(self.activityStore.activities.map { $0.id })
                    let allExistingIds = localIds.union(remoteIds.compactMap { UUID(uuidString: $0) })
                    
                    print("🔍 Check Silencioso: userId=\(userId), remote=\(remoteIds.count), local=\(localIds.count)")
                    
                    let newWorkouts = workouts.filter { workout in
                        // 1. Dentro de la ventana (usar endDate por seguridad)
                        guard workout.endDate >= cutoffDate else { return false }
                        
                        // 2. Duplicados por id (UUID estable de HealthKit)
                        if allExistingIds.contains(workout.uuid) { return false }
                        
                        return true
                    }
                    
                    print("HK import — total:\(workouts.count) nuevos:\(newWorkouts.count) (vs \(remoteIds.count) remotos)")
                    
                    guard !newWorkouts.isEmpty else {
                        print("No new workouts to import.")
                        self.isCheckingForWorkouts = false
                        self.isImporting = false
                        self.isLoading = false
                        self.importTotal = 0
                        self.importProcessed = 0
                        return
                    }
                    
                    // ONLY NOW trigger the UI
                    self.isCheckingForWorkouts = false // Done checking, now importing
                    self.isImporting = true
                    self.isLoading = true
                    
                    print("Found \(newWorkouts.count) new workouts. Processing in background...")
                    
                    // Proceed with background processing
                    self.processNewWorkouts(newWorkouts, userId: userId)
                }
            } // End of HK fetch closure
        }
    }
    
    // Extracted for clarity and async handling
    private func processNewWorkouts(_ newWorkouts: [WorkoutProtocol], userId: String) {
        let config = self.configService.config
        let pendingStore = self.pendingRouteStore
                
        DispatchQueue.global(qos: .utility).async {
            var newSessions: [ActivitySession] = []
            let group = DispatchGroup()
            let semaphore = DispatchSemaphore(value: 1)

                    
                    for workout in newWorkouts {
                        semaphore.wait() // Wait for slot
                        group.enter()
                        
                        let type = self.activityType(for: workout)
                        let bundleId = workout.sourceBundleIdentifier
                        let sourceName = workout.sourceName
                        let requiresRoute = config.requiresRoute(for: bundleId) && type.isOutdoor
                        
                        HealthKitManager.shared.fetchRoute(for: workout) { result in
                            defer { 
                                group.leave()
                                semaphore.signal() // Release slot
                            }

                            let distanceMeters = workout.totalDistanceMeters ?? 0
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
                                    id: workout.uuid, // use stable HKWorkout id to avoid duplicates
                                    startDate: workout.startDate,
                                    endDate: workout.endDate,
                                    activityType: type,
                                    distanceMeters: distanceMeters,
                                    durationSeconds: durationSeconds,
                                    workoutName: name,
                                    route: routePoints,
                                    processingStatus: .processing
                                )
                                
                                DispatchQueue.global(qos: .utility).sync {
                                    newSessions.append(session)
                                }
                            case .emptySeries:
                                let gracePeriod: TimeInterval = 30 * 60
                                let timeSinceEnd = Date().timeIntervalSince(workout.endDate)
                                
                                if requiresRoute && timeSinceEnd < gracePeriod {
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
                                
                                if requiresRoute {
                                    print("⚠️ Pending route -> Grace period expired for \(workout.uuid). Importing without GPS.")
                                }
                                
                                pendingStore.remove(workoutId: workout.uuid)
                                
                                let session = ActivitySession(
                                    id: workout.uuid,
                                    startDate: workout.startDate,
                                    endDate: workout.endDate,
                                    activityType: type,
                                    distanceMeters: distanceMeters,
                                    durationSeconds: durationSeconds,
                                    workoutName: name,
                                    route: [],
                                    processingStatus: .processing
                                )
                                
                                DispatchQueue.global(qos: .utility).sync {
                                    newSessions.append(session)
                                }
                            case .error(let error):
                                let gracePeriod: TimeInterval = 45 * 60 // Slightly longer for real errors
                                let timeSinceEnd = Date().timeIntervalSince(workout.endDate)
                                let existing = pendingStore.find(workoutId: workout.uuid)
                                let retryCount = existing?.retryCount ?? 0
                                
                                if requiresRoute && timeSinceEnd < gracePeriod && retryCount < 3 {
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
                                
                                if requiresRoute {
                                    print("⚠️ Pending route -> Error fallback (grace/retries expired) for \(workout.uuid): \(error.localizedDescription)")
                                }
                                
                                pendingStore.remove(workoutId: workout.uuid)
                                
                                let session = ActivitySession(
                                    id: workout.uuid,
                                    startDate: workout.startDate,
                                    endDate: workout.endDate,
                                    activityType: type,
                                    distanceMeters: distanceMeters,
                                    durationSeconds: durationSeconds,
                                    workoutName: name,
                                    route: [],
                                    processingStatus: .processing // Wait for GameEngine
                                )
                                
                                DispatchQueue.global(qos: .utility).sync {
                                    newSessions.append(session)
                                }
                            }
                        }
                    }
                    
                    group.wait() // Wait for all to finish
                    
                    // Save all at once on Main Thread
                    // Save all at once on Main Thread
                    DispatchQueue.main.async {
                        if !newSessions.isEmpty {
                            // Sort by date ascending to ensure correct historical replay
                            let sortedSessions = newSessions.sorted { $0.endDate < $1.endDate }
                            
                            self.importTotal = sortedSessions.count
                            self.importProcessed = 0
                            
                            print("Saving \(sortedSessions.count) imported activities...")
                            
                            // 2. Process through GameEngine (Individually for accuracy)
                            Task {
                                guard let userId = AuthenticationService.shared.userId else {
                                    print("HK import -> aborted: user logged out during processing")
                                    await MainActor.run {
                                        self.isImporting = false
                                        self.isLoading = false
                                    }
                                    return
                                }
                                let userName = AuthenticationService.shared.userName
                                
                                var activitiesToMonitor: [UUID] = []
                                                                   for session in sortedSessions {
                                        do {
                                            // IMPLEMENTATION: ADVENTURE STREAK GAME SYSTEM
                                            // Use GameEngine to process each imported activity
                                            let result = try await GameEngine.shared.completeActivity(session, for: userId, userName: userName)
                                            
                                            // Track total for UI progress
                                            await MainActor.run {
                                                self.importProcessed += 1
                                            }
                                            
                                            // Only monitor sessions that were newly processed
                                            if case .processed = result {
                                                activitiesToMonitor.append(session.id)
                                            }
                                        } catch {
                                            print("❌ Failed to process individual activity \(session.id): \(error)")
                                            // Increment processed count anyway so the progress bar moves
                                            await MainActor.run {
                                                self.importProcessed += 1
                                            }
                                        }
                                    }
                                
                                // Clean up and Monitor
                                await MainActor.run {
                                    // Refresh UI
                                    self.isLoading = false
                                    print("Import/Processing complete. Now monitoring...")
                                    
                                    if !activitiesToMonitor.isEmpty {
                                        // Only monitor TRULY new processed activities
                                        self.monitorProcessing(for: activitiesToMonitor)
                                    } else {
                                        print("✅ Import complete. No new activities to monitor for summary.")
                                        // Reset counters and hide bar
                                        self.isImporting = false
                                        self.importTotal = 0
                                        self.importProcessed = 0
                                    }
                                }
                            }
                        } else {
                            self.isImporting = false
                            self.isLoading = false
                            self.importTotal = 0
                            self.importProcessed = 0
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
        let distanceMeters = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
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
            let dateText = self.formatDate(workout.startDate)
            let reason = status == .fetchError ? "por un error al leer la ruta" : "porque la ruta aún no está disponible"
            self.errorMessage = "Tu actividad del \(dateText) no se cargó \(reason). Reintentaremos automáticamente."
            let distanceText = String(format: "%.1fkm", distanceMeters / 1000)
            let errText = errorDescription ?? "-"
            print("⏸️ Pending route [import]. id:\(id) type:\(type) bundle:\(sourceBundleId) source:\(sourceName) status:\(status.rawValue) err:\(errText) distance:\(distanceText) retry:\(retryCount)")
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
        crashlytics.log("Route import issue: status=\(status.rawValue) bundle=\(sourceBundleId) retry=\(retryCount)")
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
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: date)
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

    nonisolated private func activityType(for workout: WorkoutProtocol) -> ActivityType {
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
    
    nonisolated private func workoutName(for workout: WorkoutProtocol) -> String {
        // Usa el título que viene de HealthKit si existe
        if let title = workout.metadata?["HKMetadataKeyWorkoutTitle"] as? String, !title.isEmpty {
            return title
        }
        if let brand = workout.metadata?[HKMetadataKeyWorkoutBrandName] as? String, !brand.isEmpty {
            return brand
        }
        
        // Fallback: nombre por tipo en inglés (sin traducciones)
        return fallbackWorkoutName(for: workout.workoutActivityType)
    }
    
    nonisolated private func fallbackWorkoutName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Correr"
        case .walking: return "Caminar"
        case .cycling: return "Ciclismo"
        case .hiking: return "Senderismo"
        case .traditionalStrengthTraining: return "Fuerza Tradicional"
        case .functionalStrengthTraining: return "Fuerza Funcional"
        case .highIntensityIntervalTraining: return "HIIT"
        case .flexibility: return "Flexibilidad"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        default: return "Entrenamiento"
        }
    }
}

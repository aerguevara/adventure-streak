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
        
        self.workouts = activities
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
                        
                        let type = ActivitySyncService.shared.activityType(for: workout)
                        let bundleId = workout.sourceBundleIdentifier
                        let sourceName = workout.sourceName
                        let requiresRoute = config.requiresRoute(for: bundleId) && type.isOutdoor
                        
                        HealthKitManager.shared.fetchRoute(for: workout) { result in
                            defer {
                                group.leave()
                                semaphore.signal()
                            }
                            
                            let distanceMeters = workout.totalDistanceMeters ?? 0
                            let durationSeconds = workout.duration
                            let name = ActivitySyncService.shared.workoutName(for: workout)
                            
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
                            let stats = activity.territoryStats ?? TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0, stolenCellsCount: 0)
                            let xp = activity.xpBreakdown?.total ?? 0

                            let victims = activity.conqueredVictims ?? []
                            let loc = activity.locationLabel
                            
                            // Fetch actual territory geometries from repository
                            let territories = await TerritoryRepository.shared.fetchConqueredTerritories(forActivityId: activity.id.uuidString)
                            
                            // NEW: Immediately hydrate local store to update UI (Carousel)
                            // This ensures "Active Territories" updates instantly without waiting for a sync
                            if !territories.isEmpty {
                                let cells = territories.map { remote in
                                    TerritoryCell(
                                        id: remote.id ?? UUID().uuidString,
                                        centerLatitude: remote.centerLatitude,
                                        centerLongitude: remote.centerLongitude,
                                        boundary: remote.boundary,
                                        lastConqueredAt: remote.activityEndAt,
                                        expiresAt: remote.expiresAt,
                                        ownerUserId: remote.userId,
                                        ownerDisplayName: nil,
                                        ownerUploadedAt: remote.uploadedAt?.dateValue(),
                                        activityId: remote.activityId
                                    )
                                }
                                TerritoryStore.shared.upsertCells(cells)
                                print("✅ [Monitor] Hydrated TerritoryStore with \(cells.count) new cells")
                            }
                            
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
                                // FINAL RESET
                                // isImporting = false removed to keep bar visible until sheet covers it
                                // It will be set to false by showProcessingSummary.didSet when sheet dismisses
                                self.importTotal = 0
                                self.importProcessed = 0
                            }
                        }
                    }
                }
    }
    
    func importFromHealthKit() {
        guard AuthenticationService.shared.userId != nil else { return }
        guard activityStore.isSynced else { return }
        guard !isImporting && !isCheckingForWorkouts else { return }
        
        guard configService.config.loadHistoricalWorkouts else { return }
        
        isCheckingForWorkouts = true
        
        Task {
            let cutoffDate = configService.cutoffDate()
            let newSessions = await ActivitySyncService.shared.findNewWorkouts(from: cutoffDate)
            
            await MainActor.run {
                self.isCheckingForWorkouts = false
                guard !newSessions.isEmpty else { return }
                
                self.isImporting = true
                self.isLoading = true
                self.importTotal = newSessions.count
                self.importProcessed = 0
            }
            
            if !newSessions.isEmpty {
                await ActivitySyncService.shared.processSessions(newSessions) { processed, total in
                    DispatchQueue.main.async {
                        self.importProcessed = processed
                        self.importTotal = total
                    }
                }
            }
            
            await MainActor.run {
                self.isImporting = false
                self.isLoading = false
                self.loadWorkouts()
            }
        }
    }
    
    // MARK: - Legacy processing logic moved to ActivitySyncService.shared
    
    // UI Formatters
    private func handlePendingRoute(
        workout: WorkoutProtocol,
        type: ActivityType,
        workoutName: String,
        sourceBundleId: String,
        sourceName: String,
        status: PendingRouteStatus,
        errorDescription: String?
    ) {
        let id = workout.uuid
        let distanceMeters = workout.totalDistanceMeters ?? 0
        let existing = pendingRouteStore.find(workoutId: workout.uuid)
        let retryCount = (existing?.retryCount ?? 0) + 1
        let pending = PendingRouteImport(
            id: workout.uuid,
            startDate: workout.startDate,
            endDate: workout.endDate,
            activityType: type,
            distanceMeters: distanceMeters,
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
        workout: WorkoutProtocol,
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
        let distanceKm = (workout.totalDistanceMeters ?? 0) / 1000.0
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
}

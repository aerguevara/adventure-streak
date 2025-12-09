import Foundation
import Combine
import SwiftUI
import HealthKit

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
    
    private let activityStore: ActivityStore
    private let territoryService: TerritoryService
    private let configService: GameConfigService
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isImporting = false
    
    init(
        activityStore: ActivityStore? = nil,
        territoryService: TerritoryService? = nil,
        configService: GameConfigService
    ) {
        self.activityStore = activityStore ?? ActivityStore.shared
        self.territoryService = territoryService ?? TerritoryService(territoryStore: TerritoryStore.shared)
        self.configService = configService
        
        Task {
            await configService.loadConfigIfNeeded()
            await MainActor.run {
                self.loadWorkouts()
            }
            await fixMissingXP()
        }
        
        configService.$config
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadWorkouts()
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
                return WorkoutItemViewData(
                    id: activity.id,
                    type: activity.activityType,
                    title: "\(titlePrefix) · \(formatDistance(activity.distanceMeters))",
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
        importFromHealthKit()
    }
    
    func importFromHealthKit() {
        guard !isImporting else { return }
        
        guard configService.config.loadHistoricalWorkouts else {
            errorMessage = "La importación de entrenos históricos está desactivada en la configuración."
            importTotal = 0
            importProcessed = 0
            return
        }
        
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
                    self.importTotal = 0
                    self.importProcessed = 0
                }
                return
            }
            
            HealthKitManager.shared.fetchWorkouts { [weak self] workouts, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching workouts: \(error.localizedDescription)")
                    DispatchQueue.main.async {
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
                        self.isImporting = false
                        self.isLoading = false
                        self.importTotal = 0
                        self.importProcessed = 0
                    }
                    return
                }
                
                // Filter out duplicates AND restrict to configured window
                let cutoffDate = self.configService.cutoffDate()
                
                let newWorkouts = workouts.filter { workout in
                    // 1. Date Check: Must be within configured window
                    guard workout.startDate >= cutoffDate else { return false }
                    
                    // 2. Duplicate Check: Must not already exist
                    return !self.activityStore.activities.contains(where: { $0.startDate == workout.startDate })
                }
                
                guard !newWorkouts.isEmpty else {
                    print("No new workouts to import.")
                    DispatchQueue.main.async {
                        self.isImporting = false
                        self.isLoading = false
                        self.importTotal = 0
                        self.importProcessed = 0
                    }
                    return
                }
                
                print("Found \(newWorkouts.count) new workouts. Processing in background...")
                
                // Process in background to avoid blocking Main Thread
                DispatchQueue.main.async {
                    self.importTotal = newWorkouts.count
                    self.importProcessed = 0
                }
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

                            // Clasificamos indoor/outdoor y permitimos que sesiones indoor no tengan ruta
                            let type = self.activityType(for: workout)
                            let points = routePoints ?? []
                            
                            let session = ActivitySession(
                                id: workout.uuid, // use stable HKWorkout id to avoid duplicates
                                startDate: workout.startDate,
                                endDate: workout.endDate,
                                activityType: type,
                                distanceMeters: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                                durationSeconds: workout.duration,
                                workoutName: self.workoutName(for: workout),
                                route: points
                            )
                            
                            DispatchQueue.global(qos: .utility).sync {
                                newSessions.append(session)
                            }
                        }
                    }
                    
                    group.wait() // Wait for all to finish
                    
                    // Save all at once on Main Thread
                DispatchQueue.main.async {
                    if !newSessions.isEmpty {
                        // Sort by date ascending to ensure correct historical replay
                        let sortedSessions = newSessions.sorted { $0.endDate < $1.endDate }
                        
                        print("Saving \(sortedSessions.count) imported activities...")
                            
                            // 1. Save Activities - REMOVED: GameEngine handles saving individually
                            // self.activityStore.saveActivities(sortedSessions)
                            
                        // 2. Process through GameEngine (Individually for accuracy)
                        Task {
                            let userId = AuthenticationService.shared.userId ?? "unknown_user"
                            var totalNewCells = 0
                            defer {
                                // Reset progress when finished (success or failure)
                                Task { @MainActor in
                                    self.importTotal = 0
                                    self.importProcessed = 0
                                }
                            }
                            
                            do {
                                for session in sortedSessions {
                                    // IMPLEMENTATION: ADVENTURE STREAK GAME SYSTEM
                                    // Use GameEngine to process each imported activity
                                    let stats = try await GameEngine.shared.completeActivity(session, for: userId)
                                    
                                    // Track total for summary
                                    totalNewCells += stats.newCellsCount
                                    await MainActor.run {
                                        self.importProcessed += 1
                                    }
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
                            self.importTotal = 0
                            self.importProcessed = 0
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

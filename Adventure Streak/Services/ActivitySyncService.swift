import Foundation
import HealthKit

final class ActivitySyncService {
    static let shared = ActivitySyncService()
    
    @MainActor private(set) var isSyncing = false
    
    private init() {}
    
    /// Finds workouts in HealthKit that are NEW and within the specified window.
    /// Does not filter by GPS route presence.
    @MainActor
    func findNewWorkouts(from cutoffDate: Date) async -> [ActivitySession] {
        guard !isSyncing else {
            print("⚠️ [Sync] Already syncing. Aborting second find request.")
            return []
        }
        
        let userId = AuthenticationService.shared.userId ?? "unknown_user"
        
        // 1. Fetch from HealthKit
        let hkWorkouts = await withCheckedContinuation { continuation in
            HealthKitManager.shared.fetchWorkouts { workouts, _ in
                continuation.resume(returning: workouts ?? [])
            }
        }
        
        // 2. Fetch existing IDs from remote + local to avoid duplicates
        let remoteIds = await ActivityRepository.shared.fetchAllActivityIds(userId: userId)
        let localIds = Set(ActivityStore.shared.activities.map { $0.id })
        let allExistingIds = localIds.union(remoteIds.compactMap { UUID(uuidString: $0) })
        
        // 3. Filter by date and existence
        print("🔍 [Sync] Cutoff Date: \(cutoffDate)")
        print("🔍 [Sync] Total HK Workouts fetched: \(hkWorkouts.count)")
        
        let newHKWorkouts = hkWorkouts.filter { workout in
            let isAfter = workout.endDate >= cutoffDate
            let isNew = !allExistingIds.contains(workout.uuid)
            if !isAfter && !isNew {
                // Already exists and too old, skip
            } else if isAfter && !isNew {
                // New enough but already synced
            } else if !isAfter && isNew {
                 print("⏭️ [Sync] Skipping OLD workout: \(workoutName(for: workout) ?? "Unnamed") on \(workout.endDate)")
            }
            return isAfter && isNew
        }
        
        print("🔍 [Sync] New workouts to import: \(newHKWorkouts.count)")
        
        // 4. Map to ActivitySessions
        var sessions: [ActivitySession] = []
        for workout in newHKWorkouts {
            // Fetch route only if outdoor
            let type = activityType(for: workout)
            var route: [RoutePoint] = []
            
            if type.isOutdoor {
                route = await withCheckedContinuation { continuation in
                    HealthKitManager.shared.fetchRoute(for: workout) { result in
                        switch result {
                        case .success(let pts):
                            continuation.resume(returning: pts)
                        default:
                            continuation.resume(returning: [])
                        }
                    }
                }
            }
            
            let session = ActivitySession(
                id: workout.uuid,
                startDate: workout.startDate,
                endDate: workout.endDate,
                activityType: type,
                distanceMeters: workout.totalDistanceMeters ?? 0,
                durationSeconds: workout.duration,
                workoutName: workoutName(for: workout),
                route: route
            )
            sessions.append(session)
        }
        
        return sessions.sorted(by: { $0.startDate > $1.startDate })
    }
    
    /// Processes a list of activity sessions through the GameEngine.
    @MainActor
    func processSessions(_ sessions: [ActivitySession], progress: @escaping (Int, Int) -> Void) async {
        guard !isSyncing else { return }
        isSyncing = true
        
        defer {
            isSyncing = false
        }
        
        let userId = AuthenticationService.shared.userId ?? "unknown_user"
        let userName = AuthenticationService.shared.userName
        let total = sessions.count
        
        // Process in date order (oldest first for correct territory progression)
        let sortedSessions = sessions.sorted(by: { $0.startDate < $1.startDate })
        
        for (index, session) in sortedSessions.enumerated() {
            do {
                try await GameEngine.shared.completeActivity(session, for: userId, userName: userName)
            } catch {
                print("❌ [ActivitySyncService] Error processing session \(session.id): \(error)")
            }
            progress(index + 1, total)
        }
    }
    
    // MARK: - Helpers (accessible by ViewModels to maintain consistency)
    
    nonisolated func activityType(for workout: WorkoutProtocol) -> ActivityType {
        let isIndoor = (workout.metadata?["HKIndoorWorkout"] as? Bool) ?? false
        
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
    
    nonisolated func workoutName(for workout: WorkoutProtocol) -> String? {
        if let title = workout.metadata?["HKWorkoutTitle"] as? String, !title.isEmpty {
            return title
        }
        if let brand = workout.metadata?["HKWorkoutBrandName"] as? String, !brand.isEmpty {
            return brand
        }
        return nil
    }
}

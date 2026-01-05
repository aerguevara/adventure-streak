import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

class ActivityStore: ObservableObject {
    static let shared = ActivityStore()
    
    private let store = JSONStore<ActivitySession>(filename: "activities.json")
    @Published var activities: [ActivitySession] = []
    @Published var isSynced: Bool = false
    
    #if canImport(FirebaseFirestore)
    private var activityListener: ListenerRegistration?
    #endif
    
    private init() {
        self.activities = store.load()
        // If we have cached data, we consider it "synced" enough to prevent duplicate imports
        // until the real sync arrives.
        if !activities.isEmpty {
            self.isSynced = true
        }
        print("🗄️ ActivityStore loaded \(activities.count) activities")
        if let first = activities.first {
            print("   First activity missions: \(first.missions?.count ?? 0)")
            if let mission = first.missions?.first {
                print("   Mission name: \(mission.name)")
            }
        }
    }
    
    func saveActivity(_ activity: ActivitySession) {
        saveActivities([activity])
    }
    
    func saveActivities(_ newActivities: [ActivitySession]) {
        for newActivity in newActivities {
            if let index = activities.firstIndex(where: { $0.id == newActivity.id }) {
                activities[index] = newActivity
            } else {
                activities.append(newActivity)
            }
        }
        
        // Sort by date descending
        activities.sort { $0.startDate > $1.startDate }
        persist()
    }
    
    func startObserving(userId: String) {
        #if canImport(FirebaseFirestore)
        stopObserving()
        print("🔍 ActivityStore: Starting real-time observer for \(userId)")
        activityListener = ActivityRepository.shared.observeActivities(userId: userId) { [weak self] updatedActivities in
            guard let self = self else { return }
            print("📣 ActivityStore: Received snapshot update (\(updatedActivities.count) activities) for \(userId)")
            
            DispatchQueue.main.async {
                let remoteIds = Set(updatedActivities.map { $0.id })
                let previousCount = self.activities.count
                
                // 1. Reconcile: Purge local activities that are gone from the server
                self.activities.removeAll { local in
                    // Aggressive reconcile: if it's missing from server and NOT actively uploading, it's a ghost.
                    // We also skip purging 'error' state if we want to allow retries, 
                    // but for a reset we definitely want it gone if the server is empty.
                    let isStale = !remoteIds.contains(local.id) && local.processingStatus != .uploading
                    
                    if isStale {
                        print("🗑️ ActivityStore: REMOVING local activity (missing from server/reset): \(local.id) from \(local.startDate)")
                    }
                    return isStale
                }
                
                if self.activities.count != previousCount {
                    print("🧹 ActivityStore: Local activities reconciled. Removed \(previousCount - self.activities.count) items.")
                }
                
                // 2. Save/Update from remote snapshot
                self.saveActivities(updatedActivities)
                self.backfillSmartNames(for: updatedActivities)
                self.isSynced = true
            }
        }
        #endif
    }
    
    func stopObserving() {
        #if canImport(FirebaseFirestore)
        if activityListener != nil {
            print("🛑 ActivityStore: Stopping real-time observer")
            activityListener?.remove()
            activityListener = nil
        }
        #endif
    }
    
    
    func clear() {
        print("🧹 ActivityStore: Clearing all activities")
        activities = []
        persist()
    }
    
    func purgeBefore(date: Date) {
        let previousCount = activities.count
        activities.removeAll { $0.startDate < date }
        if activities.count != previousCount {
            print("🧹 ActivityStore: Purged \(previousCount - activities.count) activities before \(date)")
            persist()
        }
    }
    
    func updateActivity(_ updatedActivity: ActivitySession) {
        if let index = activities.firstIndex(where: { $0.id == updatedActivity.id }) {
            activities[index] = updatedActivity
            persist()
        }
    }
    
    private func persist() {
        do {
            try store.save(activities)
        } catch {
            print("Failed to save activities: \(error)")
        }
    }
    
    func fetchAllActivities() -> [ActivitySession] {
        return activities
    }
    
    // Helper for streak calculation
    func getActivitiesByWeek() -> [Int: [ActivitySession]] {
        // Group activities by week of year
        // This is a simplified logic for MVP
        let calendar = Calendar.current
        var grouped: [Int: [ActivitySession]] = [:]
        
        for activity in activities {
            // Also consider year to be correct across years, but for MVP simple week index might suffice or use a composite key
            // Better: number of weeks since reference date
            let weeksSinceRef = calendar.dateComponents([.weekOfYear], from: Date(timeIntervalSince1970: 0), to: activity.startDate).weekOfYear ?? 0
            
            var list = grouped[weeksSinceRef] ?? []
            list.append(activity)
            grouped[weeksSinceRef] = list
        }
        return grouped
    }
    
    @available(*, deprecated, message: "Use server-side stats from User profile instead to save battery.")
    func calculateCurrentStreak() -> Int {
        let grouped = getActivitiesByWeek()
        let calendar = Calendar.current
        let currentWeek = calendar.dateComponents([.weekOfYear], from: Date(timeIntervalSince1970: 0), to: Date()).weekOfYear ?? 0
        
        var streak = 0
        var checkWeek = currentWeek
        
        // If no activity this week yet, check last week to start counting
        if grouped[checkWeek] == nil {
            checkWeek -= 1
        }
        
        while grouped[checkWeek] != nil {
            streak += 1
            checkWeek -= 1
        }
        
        return streak
    }
    
    private var isBackfilling = false
    
    /// Checks for activities missing a location label and generates one.
    private func backfillSmartNames(for activities: [ActivitySession]) {
        guard !isBackfilling else { return }
        
        // Filter candidates: No label, and reasonably recent (optimization)
        let candidates = activities.filter { $0.locationLabel == nil }
        
        guard !candidates.isEmpty else { return }
        
        print("🌍 [Backfill] Found \(candidates.count) activities missing Smart Names. Starting backfill...")
        isBackfilling = true
        
        Task {
            defer { isBackfilling = false }
            
            for activity in candidates {
                // Throttle: 2 seconds between requests to avoid CLGeocoder limit (50 req/60s)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                
                // 1. Get Route
                var route = activity.route
                if route.isEmpty {
                    // Fetch from repo if missing locally
                    route = await ActivityRepository.shared.fetchRouteForActivity(activityId: activity.id.uuidString)
                }
                
                // 2. Generate Name
                var smartName: String?
                if !route.isEmpty {
                    smartName = await SmartPlaceNameService.shared.generateSmartTitle(for: route)
                }
                
                // 3. Update (Even if it fails or route is empty, we set a default to stop retrying)
                let finalName = smartName ?? activity.displayName
                
                if let name = smartName {
                    print("✅ [Backfill] Generated: '\(name)' for \(activity.id)")
                } else {
                    print("⚠️ [Backfill] No route or name for \(activity.id). Using default: \(finalName)")
                }
                
                // 3.1 Update Remote
                await ActivityRepository.shared.updateLocationLabel(activityId: activity.id, label: finalName)
                // 3.2 Update Feed
                await FeedRepository.shared.updateLocationLabel(activityId: activity.id.uuidString, label: finalName)
                
                // 4. Update Local
                await MainActor.run {
                    if let index = self.activities.firstIndex(where: { $0.id == activity.id }) {
                        var updated = self.activities[index]
                        updated.locationLabel = finalName
                        self.activities[index] = updated
                        self.persist()
                    }
                }
            }
            print("🏁 [Backfill] Completed.")
        }
    }
}

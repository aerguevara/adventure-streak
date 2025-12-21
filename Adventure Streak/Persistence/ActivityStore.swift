import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

class ActivityStore: ObservableObject {
    static let shared = ActivityStore()
    
    private let store = JSONStore<ActivitySession>(filename: "activities.json")
    @Published var activities: [ActivitySession] = []
    
    #if canImport(FirebaseFirestore)
    private var activityListener: ListenerRegistration?
    #endif
    
    private init() {
        self.activities = store.load()
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
            print("📣 ActivityStore: Received \(updatedActivities.count) activities from Firestore")
            DispatchQueue.main.async {
                self.saveActivities(updatedActivities)
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
        activities = []
        persist()
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
}

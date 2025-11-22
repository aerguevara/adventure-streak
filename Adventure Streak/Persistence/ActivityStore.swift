import Foundation

class ActivityStore: ObservableObject {
    private let store = JSONStore<ActivitySession>(filename: "activities.json")
    @Published var activities: [ActivitySession] = []
    
    init() {
        self.activities = store.load()
    }
    
    func saveActivity(_ activity: ActivitySession) {
        saveActivities([activity])
    }
    
    func saveActivities(_ newActivities: [ActivitySession]) {
        activities.append(contentsOf: newActivities)
        // Sort by date descending
        activities.sort { $0.startDate > $1.startDate }
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

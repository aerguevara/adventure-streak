import Foundation

struct ActivitySession: Identifiable, Codable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let activityType: ActivityType
    let distanceMeters: Double
    let durationSeconds: Double
    let workoutName: String?
    let route: [RoutePoint]
    // NEW: XP breakdown for this activity
    var xpBreakdown: XPBreakdown?
    // NEW: Territory stats for this activity
    var territoryStats: TerritoryStats?
    // NEW: Missions completed in this activity
    var missions: [Mission]?
    // NEW: Heart rate and calories
    var calories: Double?
    var averageHeartRate: Int?
    // NEW: Smart Location Label (e.g., "Retiro Park", "Gran Via")
    var locationLabel: String?
    
    init(id: UUID = UUID(), startDate: Date, endDate: Date, activityType: ActivityType, distanceMeters: Double, durationSeconds: Double, workoutName: String? = nil, route: [RoutePoint], xpBreakdown: XPBreakdown? = nil, territoryStats: TerritoryStats? = nil, missions: [Mission]? = nil, calories: Double? = nil, averageHeartRate: Int? = nil, locationLabel: String? = nil) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.activityType = activityType
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.workoutName = workoutName
        self.route = route
        self.xpBreakdown = xpBreakdown
        self.territoryStats = territoryStats
        self.missions = missions
        self.calories = calories
        self.averageHeartRate = averageHeartRate
        self.locationLabel = locationLabel
    }
}

import Foundation

struct ActivitySession: Identifiable, Codable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let activityType: ActivityType
    let distanceMeters: Double
    let durationSeconds: Double
    let route: [RoutePoint]
    // NEW: XP breakdown for this activity
    var xpBreakdown: XPBreakdown?
    // NEW: Territory stats for this activity
    var territoryStats: TerritoryStats?
    
    init(id: UUID = UUID(), startDate: Date, endDate: Date, activityType: ActivityType, distanceMeters: Double, durationSeconds: Double, route: [RoutePoint], xpBreakdown: XPBreakdown? = nil, territoryStats: TerritoryStats? = nil) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.activityType = activityType
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.route = route
        self.xpBreakdown = xpBreakdown
        self.territoryStats = territoryStats
    }
}

import Foundation

struct RankingEntry: Identifiable, Codable {
    var id: String { userId }
    let userId: String
    let displayName: String
    let level: Int
    let weeklyXP: Int
    var weeklyDistance: Double = 0.0
    var position: Int
    var isCurrentUser: Bool
    var totalDistance: Double = 0.0
    var totalDistanceNoGps: Double = 0.0
    
    // New properties for redesign
    var trend: RankingTrend = .neutral
    var xpProgress: Double = 0.0 // 0.0 to 1.0
    var avatarURL: URL? = nil
    var avatarData: Data? = nil
    var isFollowing: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case userId
        case displayName
        case level
        case weeklyXP
        case position
        case isCurrentUser
        case trend
        case xpProgress
        case avatarURL
        case avatarData
        case isFollowing
        case totalDistance
        case totalDistanceNoGps
    }
}

enum RankingTrend: String, Codable, CaseIterable {
    case up
    case down
    case neutral
}

enum RankingScope {
    case weekly
    case global
}

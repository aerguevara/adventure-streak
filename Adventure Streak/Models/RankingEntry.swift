import Foundation

struct RankingEntry: Identifiable, Codable {
    let id = UUID()
    let userId: String
    let displayName: String
    let level: Int
    let weeklyXP: Int
    var position: Int
    var isCurrentUser: Bool
    
    // New properties for redesign
    var trend: RankingTrend = .neutral
    var xpProgress: Double = 0.0 // 0.0 to 1.0
    var avatarURL: URL? = nil
    
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

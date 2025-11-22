import Foundation

struct RankingEntry: Identifiable, Codable {
    let id = UUID()
    let userId: String
    let displayName: String
    let level: Int
    let weeklyXP: Int
    var position: Int
    var isCurrentUser: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId
        case displayName
        case level
        case weeklyXP
        case position
        case isCurrentUser
    }
}

enum RankingScope {
    case weekly
    case global
}

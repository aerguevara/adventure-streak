import Foundation

enum ReactionType: String, Codable, CaseIterable, Hashable {
    case sword   // Respect / Attack
    case shield  // Defense
    case fire    // Motivation

    var emoji: String {
        switch self {
        case .sword: return "⚔️"
        case .shield: return "🛡️"
        case .fire: return "🔥"
        }
    }
}

struct ActivityReactionState: Equatable {
    var swordCount: Int
    var shieldCount: Int
    var fireCount: Int
    var currentUserReaction: ReactionType?

    static let empty = ActivityReactionState(swordCount: 0, shieldCount: 0, fireCount: 0, currentUserReaction: nil)
}

struct ActivityReactionRecord: Identifiable, Codable, Equatable {
    let id: String
    let activityId: String
    let reactedUserId: String
    let reactionType: ReactionType
    let createdAt: Date

    init(activityId: String, reactedUserId: String, reactionType: ReactionType, createdAt: Date = Date()) {
        self.id = "\(activityId)_\(reactedUserId)"
        self.activityId = activityId
        self.reactedUserId = reactedUserId
        self.reactionType = reactionType
        self.createdAt = createdAt
    }

    static func == (lhs: ActivityReactionRecord, rhs: ActivityReactionRecord) -> Bool {
        lhs.id == rhs.id
    }
}

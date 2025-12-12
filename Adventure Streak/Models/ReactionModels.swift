import Foundation

enum ReactionType: String, Codable, CaseIterable, Hashable {
    case fire
    case trophy
    case devil

    var emoji: String {
        switch self {
        case .fire: return "🔥"
        case .trophy: return "🏆"
        case .devil: return "😈"
        }
    }
}

struct ActivityReactionState: Equatable {
    var fireCount: Int
    var trophyCount: Int
    var devilCount: Int
    var currentUserReaction: ReactionType?

    static let empty = ActivityReactionState(fireCount: 0, trophyCount: 0, devilCount: 0, currentUserReaction: nil)
}

struct ActivityReactionRecord: Identifiable, Codable, Equatable {
    let id: String
    let activityId: UUID
    let reactedUserId: String
    let reactionType: ReactionType
    let createdAt: Date

    init(activityId: UUID, reactedUserId: String, reactionType: ReactionType, createdAt: Date = Date()) {
        self.id = "\(activityId.uuidString)_\(reactedUserId)"
        self.activityId = activityId
        self.reactedUserId = reactedUserId
        self.reactionType = reactionType
        self.createdAt = createdAt
    }

    static func == (lhs: ActivityReactionRecord, rhs: ActivityReactionRecord) -> Bool {
        lhs.id == rhs.id
    }
}

import Foundation

struct SocialUser: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let avatarURL: URL?
    let avatarData: Data?
    let level: Int
    var isFollowing: Bool
}

struct SocialPost: Identifiable, Codable, Hashable {
    let id: UUID
    let userId: String
    let user: SocialUser
    let date: Date
    let activityId: UUID?
    let activityData: SocialActivityData
    let eventType: FeedEventType?
    let eventTitle: String?
    let eventSubtitle: String?
    let rarity: MissionRarity?
}

struct SocialActivityData: Codable, Hashable {
    let activityType: ActivityType
    let distanceMeters: Double
    let durationSeconds: Double
    let xpEarned: Int
    let newZonesCount: Int
    let defendedZonesCount: Int
    let recapturedZonesCount: Int
    let fireCount: Int
    let trophyCount: Int
    let devilCount: Int
    let currentUserReaction: ReactionType?

    enum CodingKeys: String, CodingKey {
        case activityType
        case distanceMeters
        case durationSeconds
        case xpEarned
        case newZonesCount
        case defendedZonesCount
        case recapturedZonesCount
        case fireCount
        case trophyCount
        case devilCount
        case currentUserReaction
    }
    
    var distanceKm: Double {
        distanceMeters / 1000.0
    }
    
    init(activityType: ActivityType,
         distanceMeters: Double,
         durationSeconds: Double,
         xpEarned: Int,
         newZonesCount: Int,
         defendedZonesCount: Int,
         recapturedZonesCount: Int,
         fireCount: Int = 0,
         trophyCount: Int = 0,
         devilCount: Int = 0,
         currentUserReaction: ReactionType? = nil) {
        self.activityType = activityType
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.xpEarned = xpEarned
        self.newZonesCount = newZonesCount
        self.defendedZonesCount = defendedZonesCount
        self.recapturedZonesCount = recapturedZonesCount
        self.fireCount = fireCount
        self.trophyCount = trophyCount
        self.devilCount = devilCount
        self.currentUserReaction = currentUserReaction
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activityType = try container.decode(ActivityType.self, forKey: .activityType)
        distanceMeters = try container.decode(Double.self, forKey: .distanceMeters)
        durationSeconds = try container.decode(Double.self, forKey: .durationSeconds)
        xpEarned = try container.decode(Int.self, forKey: .xpEarned)
        newZonesCount = try container.decodeIfPresent(Int.self, forKey: .newZonesCount) ?? 0
        defendedZonesCount = try container.decodeIfPresent(Int.self, forKey: .defendedZonesCount) ?? 0
        recapturedZonesCount = try container.decodeIfPresent(Int.self, forKey: .recapturedZonesCount) ?? 0
        fireCount = try container.decodeIfPresent(Int.self, forKey: .fireCount) ?? 0
        trophyCount = try container.decodeIfPresent(Int.self, forKey: .trophyCount) ?? 0
        devilCount = try container.decodeIfPresent(Int.self, forKey: .devilCount) ?? 0
        currentUserReaction = try container.decodeIfPresent(ReactionType.self, forKey: .currentUserReaction)
    }
}

enum FeedImpactLevel {
    case high
    case medium
    case low
}

extension SocialPost {
    var impactLevel: FeedImpactLevel {
        if hasTerritoryImpact || hasSignificantXP || hasSystemEvent { return .high }
        if activityData.xpEarned > 0 { return .medium }
        return .low
    }

    var hasTerritoryImpact: Bool {
        activityData.newZonesCount > 0 || activityData.defendedZonesCount > 0 || activityData.recapturedZonesCount > 0
    }

    var hasSystemEvent: Bool {
        if let type = eventType {
            switch type {
            case .territoryConquered, .territoryLost, .territoryRecaptured, .distanceRecord, .streakMaintained:
                return true
            default:
                break
            }
        }
        return rarity != nil
    }

    var hasSignificantXP: Bool {
        activityData.xpEarned >= (XPConfig.dailyBaseXPCap / 2)
    }
}

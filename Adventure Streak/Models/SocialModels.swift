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
    
    // Reactions
    var currentUserReaction: ReactionType?
    var fireCount: Int
    var trophyCount: Int
    var devilCount: Int
    var latestReactorNames: [String]? // NEW: For "UserA and 2 others reacted"
    
    // Map Snapshot (Optional string to store a map image URL or data)
    let mapSnapshotURL: String?
    let calories: Double?
    let averageHeartRate: Int?

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
        case calories
        case averageHeartRate
        case latestReactorNames
        case mapSnapshotURL
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
         currentUserReaction: ReactionType? = nil,
         latestReactorNames: [String]? = nil,
         mapSnapshotURL: String? = nil,
         calories: Double? = nil,
         averageHeartRate: Int? = nil) {
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
        self.latestReactorNames = latestReactorNames
        self.mapSnapshotURL = mapSnapshotURL
        self.calories = calories
        self.averageHeartRate = averageHeartRate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields
        activityType = try container.decode(ActivityType.self, forKey: .activityType)
        distanceMeters = try container.decode(Double.self, forKey: .distanceMeters)
        durationSeconds = try container.decode(Double.self, forKey: .durationSeconds)
        xpEarned = try container.decode(Int.self, forKey: .xpEarned)
        newZonesCount = try container.decode(Int.self, forKey: .newZonesCount)
        defendedZonesCount = try container.decode(Int.self, forKey: .defendedZonesCount)
        recapturedZonesCount = try container.decode(Int.self, forKey: .recapturedZonesCount)
        
        // Optional/Newer fields with defaults
        fireCount = try container.decodeIfPresent(Int.self, forKey: .fireCount) ?? 0
        trophyCount = try container.decodeIfPresent(Int.self, forKey: .trophyCount) ?? 0
        devilCount = try container.decodeIfPresent(Int.self, forKey: .devilCount) ?? 0
        
        currentUserReaction = try container.decodeIfPresent(ReactionType.self, forKey: .currentUserReaction)
        latestReactorNames = try container.decodeIfPresent([String].self, forKey: .latestReactorNames)
        mapSnapshotURL = try container.decodeIfPresent(String.self, forKey: .mapSnapshotURL)
        calories = try container.decodeIfPresent(Double.self, forKey: .calories)
        averageHeartRate = try container.decodeIfPresent(Int.self, forKey: .averageHeartRate)
    }
}

enum ActivityImpactLevel {
    case high
    case medium
    case low
}

extension SocialPost {
    var impactLevel: ActivityImpactLevel {
        if hasTerritoryImpact || hasMissionImpact || hasSystemEvent || hasSignificantXP {
            return .high
        }
        if activityData.xpEarned > 0 {
            return .medium
        }
        return .low
    }

    var hasTerritoryImpact: Bool {
        activityData.newZonesCount > 0 || activityData.defendedZonesCount > 0 || activityData.recapturedZonesCount > 0
    }

    // Missions are optional; treat any non-common rarity as impactful
    var hasMissionImpact: Bool {
        guard let rarity else { return false }
        return rarity != .common
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

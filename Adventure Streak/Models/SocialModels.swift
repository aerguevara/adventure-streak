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
    let activityId: String?
    let activityData: SocialActivityData
    let eventType: FeedEventType?
    let eventTitle: String?
    let eventSubtitle: String?
    let rarity: MissionRarity?
    let miniMapRegion: MiniMapRegion?
}

struct UserStory: Identifiable, Hashable {
    var id: String { user.id }
    let user: SocialUser
    let activities: [SocialPost]
    
    var latestDate: Date {
        activities.map { $0.date }.max() ?? Date.distantPast
    }
}

struct SocialActivityData: Codable, Hashable {
    let activityType: ActivityType
    let distanceMeters: Double
    let durationSeconds: Double
    let xpEarned: Int
    let newZonesCount: Int
    let defendedZonesCount: Int
    let recapturedZonesCount: Int
    let stolenZonesCount: Int
    
    // Reactions
    var currentUserReaction: ReactionType?
    var swordCount: Int
    var shieldCount: Int
    var fireCount: Int
    var latestReactorNames: [String]? // NEW: For "UserA and 2 others reacted"
    let stolenVictimNames: [String]? // Names of players stolen from (if available)
    
    // Map Snapshot (Optional string to store a map image URL or data)
    let mapSnapshotURL: String?
    let locationLabel: String? // NEW: Smart Naming for Social Feed
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
        case stolenZonesCount
        case swordCount
        case shieldCount
        case fireCount
        case currentUserReaction
        case calories
        case averageHeartRate
        case latestReactorNames
        case stolenVictimNames
        case mapSnapshotURL
        case locationLabel
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
         stolenZonesCount: Int,
         swordCount: Int = 0,
         shieldCount: Int = 0,
         fireCount: Int = 0,
         currentUserReaction: ReactionType? = nil,
         latestReactorNames: [String]? = nil,
         stolenVictimNames: [String]? = nil,
         mapSnapshotURL: String? = nil,
         locationLabel: String? = nil,
         calories: Double? = nil,
         averageHeartRate: Int? = nil) {
        self.activityType = activityType
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.xpEarned = xpEarned
        self.newZonesCount = newZonesCount
        self.defendedZonesCount = defendedZonesCount
        self.recapturedZonesCount = recapturedZonesCount
        self.stolenZonesCount = stolenZonesCount
        self.swordCount = swordCount
        self.shieldCount = shieldCount
        self.fireCount = fireCount
        self.currentUserReaction = currentUserReaction
        self.latestReactorNames = latestReactorNames
        self.stolenVictimNames = stolenVictimNames
        self.mapSnapshotURL = mapSnapshotURL
        self.locationLabel = locationLabel
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
        stolenZonesCount = try container.decodeIfPresent(Int.self, forKey: .stolenZonesCount) ?? 0
        
        // Optional/Newer fields with defaults
        swordCount = try container.decodeIfPresent(Int.self, forKey: .swordCount) ?? 0
        shieldCount = try container.decodeIfPresent(Int.self, forKey: .shieldCount) ?? 0
        fireCount = try container.decodeIfPresent(Int.self, forKey: .fireCount) ?? 0
        
        currentUserReaction = try container.decodeIfPresent(ReactionType.self, forKey: .currentUserReaction)
        latestReactorNames = try container.decodeIfPresent([String].self, forKey: .latestReactorNames)
        stolenVictimNames = try container.decodeIfPresent([String].self, forKey: .stolenVictimNames)
        mapSnapshotURL = try container.decodeIfPresent(String.self, forKey: .mapSnapshotURL)
        locationLabel = try container.decodeIfPresent(String.self, forKey: .locationLabel)
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
        activityData.newZonesCount > 0 || activityData.defendedZonesCount > 0 || activityData.recapturedZonesCount > 0 || activityData.stolenZonesCount > 0
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

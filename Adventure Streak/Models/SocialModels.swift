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
}

struct SocialActivityData: Codable, Hashable {
    let activityType: ActivityType
    let distanceMeters: Double
    let durationSeconds: Double
    let xpEarned: Int
    let newZonesCount: Int
    let defendedZonesCount: Int
    let recapturedZonesCount: Int
    
    enum CodingKeys: String, CodingKey {
        case activityType, distanceMeters, durationSeconds, xpEarned, newZonesCount, defendedZonesCount, recapturedZonesCount
    }
    
    var distanceKm: Double {
        distanceMeters / 1000.0
    }
    
    init(activityType: ActivityType, distanceMeters: Double, durationSeconds: Double, xpEarned: Int, newZonesCount: Int, defendedZonesCount: Int, recapturedZonesCount: Int) {
        self.activityType = activityType
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.xpEarned = xpEarned
        self.newZonesCount = newZonesCount
        self.defendedZonesCount = defendedZonesCount
        self.recapturedZonesCount = recapturedZonesCount
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
    }
}

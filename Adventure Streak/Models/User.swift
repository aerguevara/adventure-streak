import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif
#else
// Fallback if SDK is missing
@propertyWrapper
struct DocumentID<T: Codable>: Codable {
    var wrappedValue: T
    init(wrappedValue: T) { self.wrappedValue = wrappedValue }
}
#endif

struct SeasonHistory: Codable, Identifiable {
    var id: String // seasonId
    let seasonName: String?
    let finalXp: Int
    let finalCells: Int?
    let prestigeEarned: Int
    let completedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id = "seasonId"
        case seasonName
        case finalXp
        case finalCells
        case prestigeEarned
        case completedAt
    }
}

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    let email: String?
    let displayName: String?
    let joinedAt: Date?
    var avatarURL: String?
    var mapIcon: String?
    var xp: Int
    var level: Int
    var totalActivities: Int?
    
    // Aggregated territory stats (propagados desde la app)
    var totalCellsOwned: Int?
    var recentTerritories: Int?
    var totalConqueredTerritories: Int?
    var totalStolenTerritories: Int?
    var totalDefendedTerritories: Int?
    var totalRecapturedTerritories: Int?
    
    // Extended Profile Info
    var prestige: Int?
    var fireReactions: Int?
    var swordReactions: Int?
    var shieldReactions: Int?
    var currentStreakWeeks: Int?
    var bestWeeklyDistanceKm: Double?
    var currentWeekDistanceKm: Double?
    var totalDistanceKm: Double?
    var currentWeekDistanceNoGpsKm: Double?
    var totalDistanceNoGpsKm: Double?
    
    // Remote logout control
    var forceLogoutVersion: Int?
    
    // Rivals
    var recentTheftVictims: [Rival]?
    var recentThieves: [Rival]?
    
    // Flag for global data reset acknowledgment
    var hasAcknowledgedDecReset: Bool?
    var lastAcknowledgeSeasonId: String?
    
    // Badges
    var badges: [String]?
    
    // Invitation & Hierarchy
    var invitationVerified: Bool?
    var invitedBy: String?
    var invitationPath: [String]?
    var invitationQuota: Int?
    var invitationCount: Int?
    
    // Seasonal History
    var seasonHistory: [String: SeasonHistory]?

    init(id: String? = nil,
         email: String? = nil,
         displayName: String? = nil,
         joinedAt: Date? = nil,
         avatarURL: String? = nil,
         mapIcon: String? = nil,
         xp: Int = 0,
         level: Int = 1,
         totalCellsOwned: Int? = nil,
         recentTerritories: Int? = nil,
         totalConqueredTerritories: Int? = nil,
         totalStolenTerritories: Int? = nil,
         totalDefendedTerritories: Int? = nil,
         totalRecapturedTerritories: Int? = nil,
         totalActivities: Int? = nil,
         prestige: Int? = nil,
         currentStreakWeeks: Int? = nil,
         bestWeeklyDistanceKm: Double? = nil,
         currentWeekDistanceKm: Double? = nil,
         forceLogoutVersion: Int? = nil,
         recentTheftVictims: [Rival]? = nil,
         recentThieves: [Rival]? = nil,
         hasAcknowledgedDecReset: Bool? = nil,
         lastAcknowledgeSeasonId: String? = nil,
         badges: [String]? = nil,
         invitationVerified: Bool? = nil,
         invitedBy: String? = nil,
         invitationPath: [String]? = nil,
         invitationQuota: Int? = nil,
         invitationCount: Int? = nil,
         seasonHistory: [String: SeasonHistory]? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.joinedAt = joinedAt
        self.avatarURL = avatarURL
        self.mapIcon = mapIcon
        self.xp = xp
        self.level = level
        self.totalCellsOwned = totalCellsOwned
        self.recentTerritories = recentTerritories
        self.totalConqueredTerritories = totalConqueredTerritories
        self.totalStolenTerritories = totalStolenTerritories
        self.totalDefendedTerritories = totalDefendedTerritories
        self.totalRecapturedTerritories = totalRecapturedTerritories
        self.totalActivities = totalActivities
        self.prestige = prestige
        self.currentStreakWeeks = currentStreakWeeks
        self.bestWeeklyDistanceKm = bestWeeklyDistanceKm
        self.currentWeekDistanceKm = currentWeekDistanceKm
        self.forceLogoutVersion = forceLogoutVersion
        self.recentTheftVictims = recentTheftVictims
        self.recentThieves = recentThieves
        self.hasAcknowledgedDecReset = hasAcknowledgedDecReset
        self.lastAcknowledgeSeasonId = lastAcknowledgeSeasonId
        self.badges = badges
        self.invitationVerified = invitationVerified
        self.invitedBy = invitedBy
        self.invitationPath = invitationPath
        self.invitationQuota = invitationQuota
        self.invitationCount = invitationCount
        self.seasonHistory = seasonHistory
    }

    enum CodingKeys: String, CodingKey {
        case email
        case displayName
        case joinedAt
        case avatarURL
        case mapIcon
        case xp
        case level
        case totalCellsOwned
        case recentTerritories
        case totalConqueredTerritories
        case totalStolenTerritories
        case totalDefendedTerritories
        case totalRecapturedTerritories
        case totalActivities
        case prestige
        case fireReactions
        case swordReactions
        case shieldReactions
        case currentStreakWeeks
        case bestWeeklyDistanceKm
        case currentWeekDistanceKm
        case forceLogoutVersion
        case recentTheftVictims
        case recentThieves
        case hasAcknowledgedDecReset
        case lastAcknowledgeSeasonId
        case badges
        case invitationVerified
        case invitedBy
        case invitationPath
        case invitationQuota
        case invitationCount
        case seasonHistory
        case totalDistanceKm
        case totalDistanceNoGpsKm
        case currentWeekDistanceNoGpsKm
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle DocumentID manually if needed or let FirestoreSwift handle it
        // Usually, with @DocumentID, we don't need to manually decode id from the container
        // if it's stored as the document name.
        
        email = try container.decodeIfPresent(String.self, forKey: .email)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        joinedAt = try container.decodeIfPresent(Date.self, forKey: .joinedAt)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        mapIcon = try container.decodeIfPresent(String.self, forKey: .mapIcon)
        
        // Fix: Provide defaults for missing XP/Level
        xp = try container.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        level = try container.decodeIfPresent(Int.self, forKey: .level) ?? 1
        
        totalCellsOwned = try container.decodeIfPresent(Int.self, forKey: .totalCellsOwned)
        recentTerritories = try container.decodeIfPresent(Int.self, forKey: .recentTerritories)
        totalConqueredTerritories = try container.decodeIfPresent(Int.self, forKey: .totalConqueredTerritories)
        totalStolenTerritories = try container.decodeIfPresent(Int.self, forKey: .totalStolenTerritories)
        totalDefendedTerritories = try container.decodeIfPresent(Int.self, forKey: .totalDefendedTerritories)
        totalRecapturedTerritories = try container.decodeIfPresent(Int.self, forKey: .totalRecapturedTerritories)
        totalActivities = try container.decodeIfPresent(Int.self, forKey: .totalActivities)
        prestige = try container.decodeIfPresent(Int.self, forKey: .prestige)
        fireReactions = try container.decodeIfPresent(Int.self, forKey: .fireReactions)
        swordReactions = try container.decodeIfPresent(Int.self, forKey: .swordReactions)
        shieldReactions = try container.decodeIfPresent(Int.self, forKey: .shieldReactions)
        currentStreakWeeks = try container.decodeIfPresent(Int.self, forKey: .currentStreakWeeks)
        bestWeeklyDistanceKm = try container.decodeIfPresent(Double.self, forKey: .bestWeeklyDistanceKm)
        currentWeekDistanceKm = try container.decodeIfPresent(Double.self, forKey: .currentWeekDistanceKm)
        totalDistanceKm = try container.decodeIfPresent(Double.self, forKey: .totalDistanceKm)
        totalDistanceNoGpsKm = try container.decodeIfPresent(Double.self, forKey: .totalDistanceNoGpsKm)
        currentWeekDistanceNoGpsKm = try container.decodeIfPresent(Double.self, forKey: .currentWeekDistanceNoGpsKm)
        forceLogoutVersion = try container.decodeIfPresent(Int.self, forKey: .forceLogoutVersion)
        
        recentTheftVictims = try container.decodeIfPresent([Rival].self, forKey: .recentTheftVictims)
        recentThieves = try container.decodeIfPresent([Rival].self, forKey: .recentThieves)
        hasAcknowledgedDecReset = try container.decodeIfPresent(Bool.self, forKey: .hasAcknowledgedDecReset)
        lastAcknowledgeSeasonId = try container.decodeIfPresent(String.self, forKey: .lastAcknowledgeSeasonId)
        badges = try container.decodeIfPresent([String].self, forKey: .badges)
        invitationVerified = try container.decodeIfPresent(Bool.self, forKey: .invitationVerified)
        invitedBy = try container.decodeIfPresent(String.self, forKey: .invitedBy)
        invitationPath = try container.decodeIfPresent([String].self, forKey: .invitationPath)
        invitationQuota = try container.decodeIfPresent(Int.self, forKey: .invitationQuota)
        invitationCount = try container.decodeIfPresent(Int.self, forKey: .invitationCount)
        seasonHistory = try container.decodeIfPresent([String: SeasonHistory].self, forKey: .seasonHistory)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(joinedAt, forKey: .joinedAt)
        try container.encodeIfPresent(avatarURL, forKey: .avatarURL)
        try container.encodeIfPresent(mapIcon, forKey: .mapIcon)
        try container.encode(xp, forKey: .xp)
        try container.encode(level, forKey: .level)
        try container.encodeIfPresent(totalCellsOwned, forKey: .totalCellsOwned)
        try container.encodeIfPresent(recentTerritories, forKey: .recentTerritories)
        try container.encodeIfPresent(totalConqueredTerritories, forKey: .totalConqueredTerritories)
        try container.encodeIfPresent(totalStolenTerritories, forKey: .totalStolenTerritories)
        try container.encodeIfPresent(totalDefendedTerritories, forKey: .totalDefendedTerritories)
        try container.encodeIfPresent(totalRecapturedTerritories, forKey: .totalRecapturedTerritories)
        try container.encodeIfPresent(totalActivities, forKey: .totalActivities)
        try container.encodeIfPresent(prestige, forKey: .prestige)
        try container.encodeIfPresent(fireReactions, forKey: .fireReactions)
        try container.encodeIfPresent(swordReactions, forKey: .swordReactions)
        try container.encodeIfPresent(shieldReactions, forKey: .shieldReactions)
        try container.encodeIfPresent(currentStreakWeeks, forKey: .currentStreakWeeks)
        try container.encodeIfPresent(bestWeeklyDistanceKm, forKey: .bestWeeklyDistanceKm)
        try container.encodeIfPresent(currentWeekDistanceKm, forKey: .currentWeekDistanceKm)
        try container.encodeIfPresent(totalDistanceKm, forKey: .totalDistanceKm)
        try container.encodeIfPresent(totalDistanceNoGpsKm, forKey: .totalDistanceNoGpsKm)
        try container.encodeIfPresent(currentWeekDistanceNoGpsKm, forKey: .currentWeekDistanceNoGpsKm)
        try container.encodeIfPresent(forceLogoutVersion, forKey: .forceLogoutVersion)
        try container.encodeIfPresent(recentTheftVictims, forKey: .recentTheftVictims)
        try container.encodeIfPresent(recentThieves, forKey: .recentThieves)
        try container.encodeIfPresent(hasAcknowledgedDecReset, forKey: .hasAcknowledgedDecReset)
        try container.encodeIfPresent(lastAcknowledgeSeasonId, forKey: .lastAcknowledgeSeasonId)
        try container.encodeIfPresent(badges, forKey: .badges)
        try container.encodeIfPresent(invitationVerified, forKey: .invitationVerified)
        try container.encodeIfPresent(invitedBy, forKey: .invitedBy)
        try container.encodeIfPresent(invitationPath, forKey: .invitationPath)
        try container.encodeIfPresent(invitationQuota, forKey: .invitationQuota)
        try container.encodeIfPresent(invitationCount, forKey: .invitationCount)
        try container.encodeIfPresent(seasonHistory, forKey: .seasonHistory)
    }
}

struct Rival: Identifiable, Codable {
    let userId: String
    let displayName: String
    let avatarURL: String?
    let lastInteractionAt: Date
    let count: Int
    
    var id: String { userId }
}

struct RivalryRelationship: Identifiable {
    let userId: String
    let displayName: String
    let avatarURL: String?
    let userScore: Int
    let rivalScore: Int
    let lastInteractionAt: Date
    let trend: RankingTrend
    
    var id: String { userId }
    var isUserLeading: Bool { userScore >= rivalScore }
    var isVengeancePending: Bool { rivalScore > userScore }
}


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

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    let email: String?
    let displayName: String?
    let joinedAt: Date?
    var avatarURL: String?
    var mapIcon: String?
    var xp: Int
    var level: Int
    
    // Aggregated territory stats (propagados desde la app)
    var totalCellsOwned: Int?
    var recentTerritories: Int?
    var totalConqueredTerritories: Int?
    var totalStolenTerritories: Int?
    var totalDefendedTerritories: Int?
    var totalRecapturedTerritories: Int?
    
    // Extended Profile Info
    var prestige: Int?
    var currentStreakWeeks: Int?
    var bestWeeklyDistanceKm: Double?
    var currentWeekDistanceKm: Double?
    
    // Remote logout control
    var forceLogoutVersion: Int?
    
    // Rivals
    var recentTheftVictims: [Rival]?
    var recentThieves: [Rival]?
    
    // Flag for global data reset acknowledgment
    var hasAcknowledgedDecReset: Bool?

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
         prestige: Int? = nil,
         currentStreakWeeks: Int? = nil,
         bestWeeklyDistanceKm: Double? = nil,
         currentWeekDistanceKm: Double? = nil,
         forceLogoutVersion: Int? = nil,
         recentTheftVictims: [Rival]? = nil,
         recentThieves: [Rival]? = nil,
         hasAcknowledgedDecReset: Bool? = nil) {
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
        self.prestige = prestige
        self.currentStreakWeeks = currentStreakWeeks
        self.bestWeeklyDistanceKm = bestWeeklyDistanceKm
        self.currentWeekDistanceKm = currentWeekDistanceKm
        self.forceLogoutVersion = forceLogoutVersion
        self.recentTheftVictims = recentTheftVictims
        self.recentThieves = recentThieves
        self.hasAcknowledgedDecReset = hasAcknowledgedDecReset
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
        case prestige
        case currentStreakWeeks
        case bestWeeklyDistanceKm
        case currentWeekDistanceKm
        case forceLogoutVersion
        case recentTheftVictims
        case recentThieves
        case hasAcknowledgedDecReset
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
        prestige = try container.decodeIfPresent(Int.self, forKey: .prestige)
        currentStreakWeeks = try container.decodeIfPresent(Int.self, forKey: .currentStreakWeeks)
        bestWeeklyDistanceKm = try container.decodeIfPresent(Double.self, forKey: .bestWeeklyDistanceKm)
        currentWeekDistanceKm = try container.decodeIfPresent(Double.self, forKey: .currentWeekDistanceKm)
        forceLogoutVersion = try container.decodeIfPresent(Int.self, forKey: .forceLogoutVersion)
        
        recentTheftVictims = try container.decodeIfPresent([Rival].self, forKey: .recentTheftVictims)
        recentThieves = try container.decodeIfPresent([Rival].self, forKey: .recentThieves)
        hasAcknowledgedDecReset = try container.decodeIfPresent(Bool.self, forKey: .hasAcknowledgedDecReset)
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


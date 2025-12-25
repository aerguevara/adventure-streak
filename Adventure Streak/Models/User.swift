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
    var xp: Int
    var level: Int
    
    // Aggregated territory stats (propagados desde la app)
    var totalCellsOwned: Int?
    var recentTerritories: Int?
    var totalConqueredTerritories: Int?
    var totalStolenTerritories: Int?
    var totalDefendedTerritories: Int?
    
    // Extended Profile Info
    var prestige: Int?
    var currentStreakWeeks: Int?
    var bestWeeklyDistanceKm: Double?
    var currentWeekDistanceKm: Double?
    
    // Remote logout control
    var forceLogoutVersion: Int?

    init(id: String? = nil,
         email: String? = nil,
         displayName: String? = nil,
         joinedAt: Date? = nil,
         avatarURL: String? = nil,
         xp: Int = 0,
         level: Int = 1,
         totalCellsOwned: Int? = nil,
         recentTerritories: Int? = nil,
         totalConqueredTerritories: Int? = nil,
         totalStolenTerritories: Int? = nil,
         totalDefendedTerritories: Int? = nil,
         prestige: Int? = nil,
         currentStreakWeeks: Int? = nil,
         bestWeeklyDistanceKm: Double? = nil,
         currentWeekDistanceKm: Double? = nil,
         forceLogoutVersion: Int? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.joinedAt = joinedAt
        self.avatarURL = avatarURL
        self.xp = xp
        self.level = level
        self.totalCellsOwned = totalCellsOwned
        self.recentTerritories = recentTerritories
        self.totalConqueredTerritories = totalConqueredTerritories
        self.totalStolenTerritories = totalStolenTerritories
        self.totalDefendedTerritories = totalDefendedTerritories
        self.prestige = prestige
        self.currentStreakWeeks = currentStreakWeeks
        self.bestWeeklyDistanceKm = bestWeeklyDistanceKm
        self.currentWeekDistanceKm = currentWeekDistanceKm
        self.forceLogoutVersion = forceLogoutVersion
    }

    enum CodingKeys: String, CodingKey {
        case email
        case displayName
        case joinedAt
        case avatarURL
        case xp
        case level
        case totalCellsOwned
        case recentTerritories
        case totalConqueredTerritories
        case totalStolenTerritories
        case totalDefendedTerritories
        case prestige
        case currentStreakWeeks
        case bestWeeklyDistanceKm
        case currentWeekDistanceKm
        case forceLogoutVersion
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
        
        // Fix: Provide defaults for missing XP/Level
        xp = try container.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        level = try container.decodeIfPresent(Int.self, forKey: .level) ?? 1
        
        totalCellsOwned = try container.decodeIfPresent(Int.self, forKey: .totalCellsOwned)
        recentTerritories = try container.decodeIfPresent(Int.self, forKey: .recentTerritories)
        totalConqueredTerritories = try container.decodeIfPresent(Int.self, forKey: .totalConqueredTerritories)
        totalStolenTerritories = try container.decodeIfPresent(Int.self, forKey: .totalStolenTerritories)
        totalDefendedTerritories = try container.decodeIfPresent(Int.self, forKey: .totalDefendedTerritories)
        prestige = try container.decodeIfPresent(Int.self, forKey: .prestige)
        currentStreakWeeks = try container.decodeIfPresent(Int.self, forKey: .currentStreakWeeks)
        bestWeeklyDistanceKm = try container.decodeIfPresent(Double.self, forKey: .bestWeeklyDistanceKm)
        currentWeekDistanceKm = try container.decodeIfPresent(Double.self, forKey: .currentWeekDistanceKm)
        forceLogoutVersion = try container.decodeIfPresent(Int.self, forKey: .forceLogoutVersion)
    }
}

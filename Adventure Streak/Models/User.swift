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
    
    // Extended Profile Info
    var prestige: Int?
    var currentStreakWeeks: Int?
    var bestWeeklyDistanceKm: Double?
    var currentWeekDistanceKm: Double?
    
    // Remote logout control
    var forceLogoutVersion: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName
        case joinedAt
        case avatarURL
        case xp
        case level
        case totalCellsOwned
        case recentTerritories
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
        prestige = try container.decodeIfPresent(Int.self, forKey: .prestige)
        currentStreakWeeks = try container.decodeIfPresent(Int.self, forKey: .currentStreakWeeks)
        bestWeeklyDistanceKm = try container.decodeIfPresent(Double.self, forKey: .bestWeeklyDistanceKm)
        currentWeekDistanceKm = try container.decodeIfPresent(Double.self, forKey: .currentWeekDistanceKm)
        forceLogoutVersion = try container.decodeIfPresent(Int.self, forKey: .forceLogoutVersion)
    }
}

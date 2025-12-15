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
    var xp: Int = 0
    var level: Int = 1
    
    // Aggregated territory stats (propagados desde la app)
    var totalCellsOwned: Int?
    var recentTerritories: Int?
    
    // Remote logout control
    var forceLogoutVersion: Int?
}

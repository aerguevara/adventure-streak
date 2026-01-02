import Foundation
import CoreLocation
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

/// Represents a territory that was stolen from the user and is available for reconquest with bonus XP.
struct VengeanceTarget: Identifiable, Codable, Equatable {
    @DocumentID var id: String? // Cell ID
    let cellId: String
    let activityId: String? // NEW: For grouping
    let centerLatitude: Double
    let centerLongitude: Double
    let thiefId: String
    let thiefName: String
    let stolenAt: Date
    let xpReward: Int
    var locationLabel: String? // NEW: Added for displaying zone name
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }
    
    static func == (lhs: VengeanceTarget, rhs: VengeanceTarget) -> Bool {
        return lhs.cellId == rhs.cellId && lhs.thiefId == rhs.thiefId && lhs.stolenAt == rhs.stolenAt
    }
}

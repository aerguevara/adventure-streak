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

struct RemoteTerritory: Identifiable, Codable {
    @DocumentID var id: String? // Format "x_y"
    let userId: String
    let centerLatitude: Double
    let centerLongitude: Double
    // NEW: Store exact boundary
    let boundary: [TerritoryPoint]
    let expiresAt: Date
    let timestamp: Date
    
    // Helper to get center coordinate
    var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }
}

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

struct RemoteTerritory: Identifiable, Codable, Equatable {
    @DocumentID var id: String? // Format "x_y"
    let userId: String
    let centerLatitude: Double
    let centerLongitude: Double
    // NEW: Store exact boundary
    let boundary: [TerritoryPoint]
    let expiresAt: Date
    // Domain time when the activity ended (not upload time)
    let activityEndAt: Date
    // Legacy field; kept for backward compatibility
    let timestamp: Date
    
    // Helper to get center coordinate
    var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }
    
    enum CodingKeys: String, CodingKey {
        case userId, centerLatitude, centerLongitude, boundary, expiresAt, activityEndAt, timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _id = DocumentID(wrappedValue: nil) // Initialize manually, repository will set it
        userId = try container.decode(String.self, forKey: .userId)
        centerLatitude = try container.decode(Double.self, forKey: .centerLatitude)
        centerLongitude = try container.decode(Double.self, forKey: .centerLongitude)
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        activityEndAt = try container.decodeIfPresent(Date.self, forKey: .activityEndAt)
            ?? (try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date())
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? activityEndAt
        
        if let storedBoundary = try container.decodeIfPresent([TerritoryPoint].self, forKey: .boundary) {
            boundary = storedBoundary
        } else {
            // Migration: Calculate boundary for legacy documents
            let halfSize = 0.002 / 2.0
            boundary = [
                TerritoryPoint(latitude: centerLatitude + halfSize, longitude: centerLongitude - halfSize),
                TerritoryPoint(latitude: centerLatitude + halfSize, longitude: centerLongitude + halfSize),
                TerritoryPoint(latitude: centerLatitude - halfSize, longitude: centerLongitude + halfSize),
                TerritoryPoint(latitude: centerLatitude - halfSize, longitude: centerLongitude - halfSize)
            ]
        }
    }
    
    // Default init
    init(id: String?, userId: String, centerLatitude: Double, centerLongitude: Double, boundary: [TerritoryPoint], expiresAt: Date, activityEndAt: Date) {
        self.id = id
        self.userId = userId
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.boundary = boundary
        self.expiresAt = expiresAt
        self.activityEndAt = activityEndAt
        self.timestamp = activityEndAt
    }
}

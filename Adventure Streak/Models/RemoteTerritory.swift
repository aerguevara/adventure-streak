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
    let isHotSpot: Bool
    let expiresAt: Date
    // Domain time when the activity ended (not upload time)
    let activityEndAt: Date
    // NEW: Activity that conquered this territory
    let activityId: String?
    // Legacy field; kept for backward compatibility
    let timestamp: Date
    @ServerTimestamp var uploadedAt: Timestamp?
    
    // Helper to get center coordinate
    var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }
    
    enum CodingKeys: String, CodingKey {
        case userId, centerLatitude, centerLongitude, boundary, isHotSpot, expiresAt, activityEndAt, activityId, timestamp, uploadedAt
        case lastConqueredAt // NEW: Match Firestore field
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _id = DocumentID(wrappedValue: nil) // Initialize manually, repository will set it
        userId = try container.decode(String.self, forKey: .userId)
        centerLatitude = try container.decode(Double.self, forKey: .centerLatitude)
        centerLongitude = try container.decode(Double.self, forKey: .centerLongitude)
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        isHotSpot = try container.decodeIfPresent(Bool.self, forKey: .isHotSpot) ?? false
        
        // Prioritize lastConqueredAt (Server Truth), then activityEndAt, then timestamp
        if let lastConquered = try container.decodeIfPresent(Date.self, forKey: .lastConqueredAt) {
            activityEndAt = lastConquered
        } else {
            activityEndAt = try container.decodeIfPresent(Date.self, forKey: .activityEndAt)
                ?? (try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date())
        }
        
        activityId = try container.decodeIfPresent(String.self, forKey: .activityId)
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? activityEndAt
        uploadedAt = try container.decodeIfPresent(Timestamp.self, forKey: .uploadedAt)
        
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
    init(id: String?, userId: String, centerLatitude: Double, centerLongitude: Double, boundary: [TerritoryPoint], expiresAt: Date, activityEndAt: Date, activityId: String? = nil, isHotSpot: Bool = false) {
        self._id = DocumentID(wrappedValue: id)
        self.userId = userId
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.boundary = boundary
        self.expiresAt = expiresAt
        self.activityEndAt = activityEndAt
        self.activityId = activityId
        self.isHotSpot = isHotSpot
        self.timestamp = activityEndAt
        self.uploadedAt = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(centerLatitude, forKey: .centerLatitude)
        try container.encode(centerLongitude, forKey: .centerLongitude)
        try container.encode(boundary, forKey: .boundary)
        try container.encode(expiresAt, forKey: .expiresAt)
        try container.encode(isHotSpot, forKey: .isHotSpot)
        try container.encode(activityEndAt, forKey: .activityEndAt)
        try container.encode(activityEndAt, forKey: .lastConqueredAt) // Map to new server field
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(activityId, forKey: .activityId)
        try container.encodeIfPresent(uploadedAt, forKey: .uploadedAt)
    }
}

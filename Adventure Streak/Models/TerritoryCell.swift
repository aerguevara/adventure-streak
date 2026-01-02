import Foundation
import CoreLocation

struct TerritoryPoint: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct TerritoryCell: Identifiable, Codable, Hashable {
    let id: String // Format "x_y"
    let centerLatitude: Double
    let centerLongitude: Double
    // NEW: Store exact boundary to ensure correct rendering
    let boundary: [TerritoryPoint]
    var lastConqueredAt: Date
    var expiresAt: Date
    // Ownership metadata (optional for backward compatibility)
    var ownerUserId: String?
    var ownerDisplayName: String?
    var ownerUploadedAt: Date?
    // NEW: Track which activity claimed this cell (critical for race condition handling)
    var activityId: String?
    var isHotSpot: Bool?
    var locationLabel: String? // NEW: Store location label
    
    var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }
    
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    // NEW: Explicit CodingKeys required for custom decoding
    enum CodingKeys: String, CodingKey {
        case id, centerLatitude, centerLongitude, boundary, lastConqueredAt, expiresAt, ownerUserId, ownerDisplayName, ownerUploadedAt, activityId, isHotSpot, locationLabel
        case serverLastConqueredAt = "activityEndAt" // Fallback key used by server
    }
    
    // NEW: Custom decoding to handle legacy data without 'boundary' or with mismatching date keys
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        centerLatitude = try container.decode(Double.self, forKey: .centerLatitude)
        centerLongitude = try container.decode(Double.self, forKey: .centerLongitude)
        
        // Try standard key, fallback to server key
        if let date = try container.decodeIfPresent(Date.self, forKey: .lastConqueredAt) {
            lastConqueredAt = date
        } else if let serverDate = try container.decodeIfPresent(Date.self, forKey: .serverLastConqueredAt) {
            lastConqueredAt = serverDate
        } else {
            // Throw the original error if both missing for clarity in logs
            lastConqueredAt = try container.decode(Date.self, forKey: .lastConqueredAt)
        }
        
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        ownerUserId = try container.decodeIfPresent(String.self, forKey: .ownerUserId)
        ownerDisplayName = try container.decodeIfPresent(String.self, forKey: .ownerDisplayName)
        ownerUploadedAt = try container.decodeIfPresent(Date.self, forKey: .ownerUploadedAt)
        activityId = try container.decodeIfPresent(String.self, forKey: .activityId)
        isHotSpot = try container.decodeIfPresent(Bool.self, forKey: .isHotSpot)
        locationLabel = try container.decodeIfPresent(String.self, forKey: .locationLabel)
        
        // Try to decode boundary, or calculate it if missing (migration)
        if let storedBoundary = try container.decodeIfPresent([TerritoryPoint].self, forKey: .boundary) {
            boundary = storedBoundary
        } else {
            // Recalculate boundary for legacy cells
            // We need to duplicate the grid logic here briefly or assume a standard size
            // Since we can't easily access TerritoryGrid.cellSizeDegrees here without import cycle issues if not careful,
            // we'll use the known constant 0.002
            let halfSize = 0.002 / 2.0
            boundary = [
                TerritoryPoint(latitude: centerLatitude + halfSize, longitude: centerLongitude - halfSize),
                TerritoryPoint(latitude: centerLatitude + halfSize, longitude: centerLongitude + halfSize),
                TerritoryPoint(latitude: centerLatitude - halfSize, longitude: centerLongitude + halfSize),
                TerritoryPoint(latitude: centerLatitude - halfSize, longitude: centerLongitude - halfSize)
            ]
        }
    }
    
    // NEW: Explicit encoding required when custom decoding is present
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(centerLatitude, forKey: .centerLatitude)
        try container.encode(centerLongitude, forKey: .centerLongitude)
        try container.encode(boundary, forKey: .boundary)
        try container.encode(lastConqueredAt, forKey: .lastConqueredAt)
        try container.encode(expiresAt, forKey: .expiresAt)
        try container.encodeIfPresent(ownerUserId, forKey: .ownerUserId)
        try container.encodeIfPresent(ownerDisplayName, forKey: .ownerDisplayName)
        try container.encodeIfPresent(ownerUploadedAt, forKey: .ownerUploadedAt)
        try container.encodeIfPresent(activityId, forKey: .activityId)
        try container.encodeIfPresent(isHotSpot, forKey: .isHotSpot)
        try container.encodeIfPresent(locationLabel, forKey: .locationLabel)
    }
    
    // Default init for creating new cells
    init(id: String, centerLatitude: Double, centerLongitude: Double, boundary: [TerritoryPoint], lastConqueredAt: Date, expiresAt: Date, ownerUserId: String? = nil, ownerDisplayName: String? = nil, ownerUploadedAt: Date? = nil, activityId: String? = nil, isHotSpot: Bool? = nil, locationLabel: String? = nil) {
        self.id = id
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.boundary = boundary
        self.lastConqueredAt = lastConqueredAt
        self.expiresAt = expiresAt
        self.ownerUserId = ownerUserId
        self.ownerDisplayName = ownerDisplayName
        self.ownerUploadedAt = ownerUploadedAt
        self.activityId = activityId
        self.isHotSpot = isHotSpot
        self.locationLabel = locationLabel
    }
}

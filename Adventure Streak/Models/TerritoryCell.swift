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
    
    var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }
    
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    // NEW: Explicit CodingKeys required for custom decoding
    enum CodingKeys: String, CodingKey {
        case id, centerLatitude, centerLongitude, boundary, lastConqueredAt, expiresAt, ownerUserId, ownerDisplayName, ownerUploadedAt
    }
    
    // NEW: Custom decoding to handle legacy data without 'boundary'
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        centerLatitude = try container.decode(Double.self, forKey: .centerLatitude)
        centerLongitude = try container.decode(Double.self, forKey: .centerLongitude)
        lastConqueredAt = try container.decode(Date.self, forKey: .lastConqueredAt)
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        ownerUserId = try container.decodeIfPresent(String.self, forKey: .ownerUserId)
        ownerDisplayName = try container.decodeIfPresent(String.self, forKey: .ownerDisplayName)
        ownerUploadedAt = try container.decodeIfPresent(Date.self, forKey: .ownerUploadedAt)
        
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
    
    // Default init for creating new cells
    init(id: String, centerLatitude: Double, centerLongitude: Double, boundary: [TerritoryPoint], lastConqueredAt: Date, expiresAt: Date, ownerUserId: String? = nil, ownerDisplayName: String? = nil, ownerUploadedAt: Date? = nil) {
        self.id = id
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.boundary = boundary
        self.lastConqueredAt = lastConqueredAt
        self.expiresAt = expiresAt
        self.ownerUserId = ownerUserId
        self.ownerDisplayName = ownerDisplayName
        self.ownerUploadedAt = ownerUploadedAt
    }
}

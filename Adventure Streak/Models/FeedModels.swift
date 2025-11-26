import Foundation
import CoreLocation
import SwiftUI
import MapKit

// MARK: - Enums

enum FeedEventType: String, Codable {
    case weeklySummary
    case streakMaintained
    case newBadge
    case levelUp
    case territoryConquered
    case territoryLost
    case territoryRecaptured
    case distanceRecord
}

enum BadgeRarity: String, Codable {
    case common
    case rare
    case epic
    case legendary
}

// MARK: - Helper Models

struct MiniMapRegion: Codable, Equatable {
    let centerLatitude: Double
    let centerLongitude: Double
    let spanLatitudeDelta: Double
    let spanLongitudeDelta: Double
    
    var coordinateRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude),
            span: MKCoordinateSpan(latitudeDelta: spanLatitudeDelta, longitudeDelta: spanLongitudeDelta)
        )
    }
}

// MARK: - Main Event Model

struct FeedEvent: Identifiable, Codable {
    var id: String?
    let type: FeedEventType
    let date: Date
    
    let title: String
    let subtitle: String?
    let xpEarned: Int?
    
    // Social
    let userId: String?
    let relatedUserName: String?
    
    // Territory
    let miniMapRegion: MiniMapRegion?
    
    // Badges
    let badgeName: String?
    let badgeRarity: BadgeRarity?
    
    // Flags
    let isPersonal: Bool
    
    // Custom CodingKeys to handle the id mapping if needed, 
    // but default might work if we use the same @DocumentID approach in Repository.
    // For now, we keep it simple conformant to Codable.
}

// MARK: - View Data for Weekly Summary

struct WeeklySummaryViewData {
    let totalDistance: Double
    let territoriesConquered: Int
    let territoriesLost: Int
    let currentStreakWeeks: Int
    let rivalName: String?
}

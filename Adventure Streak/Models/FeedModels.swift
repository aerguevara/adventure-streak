import Foundation
import CoreLocation
import SwiftUI
import MapKit

// MARK: - Enums

enum FeedEventType: String, Codable {
    case weeklySummary = "weekly_summary"
    case streakMaintained = "streak_maintained"
    case newBadge = "new_badge"
    case levelUp = "level_up"
    case territoryConquered = "territory_conquered"
    case territoryLost = "territory_lost"
    case territoryRecaptured = "territory_recaptured"
    case distanceRecord = "distance_record"
    
    // Custom decoding to support both snake_case (legacy/backend) and camelCase (iOS generated)
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawString = try container.decode(String.self)
        
        switch rawString {
        case "weekly_summary", "weeklySummary": self = .weeklySummary
        case "streak_maintained", "streakMaintained": self = .streakMaintained
        case "new_badge", "newBadge": self = .newBadge
        case "level_up", "levelUp": self = .levelUp
        case "territory_conquered", "territoryConquered": self = .territoryConquered
        case "territory_lost", "territoryLost": self = .territoryLost
        case "territory_recaptured", "territoryRecaptured": self = .territoryRecaptured
        case "distance_record", "distanceRecord": self = .distanceRecord
        default:
            // Try to initialize with raw value, otherwise throw
            if let type = FeedEventType(rawValue: rawString) {
                self = type
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot initialize FeedEventType from invalid String value \(rawString)")
            }
        }
    }
}

enum BadgeRarity: String, Codable {
    case common
    case rare
    case epic
    case legendary
}

// MARK: - Helper Models

struct MiniMapRegion: Codable, Equatable, Hashable {
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
    var id: String
    let type: FeedEventType
    let date: Date
    
    // Link to activity when applicable to deduplicar eventos reimportados
    let activityId: String?
    
    let title: String
    let subtitle: String?
    let xpEarned: Int?
    
    // Social
    let userId: String?
    let relatedUserName: String?
    let userLevel: Int?
    let userAvatarURL: URL?
    
    // Territory
    let miniMapRegion: MiniMapRegion?
    
    // Badges
    // Badges
    let badgeName: String?
    let badgeRarity: BadgeRarity?
    
    // Activity Data (New for Social Feed)
    let activityData: SocialActivityData?
    
    // Game Logic
    var rarity: MissionRarity? // Optional because not all events are missions
    
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

import Foundation

enum ActivityType: String, Codable, CaseIterable, Identifiable {
    case run
    case walk
    case bike
    case hike
    case otherOutdoor
    case indoor
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .run: return "Run"
        case .walk: return "Walk"
        case .bike: return "Bike"
        case .hike: return "Hiking"
        case .otherOutdoor: return "Outdoor"
        case .indoor: return "Indoor"
        }
    }
    
    var iconName: String {
        switch self {
        case .run: return "figure.run"
        case .walk: return "figure.walk"
        case .bike: return "bicycle"
        case .hike: return "figure.hiking"
        case .otherOutdoor: return "figure.hiking"
        case .indoor: return "dumbbell"
        }
    }
    
    var isOutdoor: Bool {
        switch self {
        case .run, .walk, .bike, .hike, .otherOutdoor:
            return true
        case .indoor:
            return false
        }
    }
}

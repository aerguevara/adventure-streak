import Foundation

enum ActivityType: String, Codable, CaseIterable, Identifiable {
    case run
    case walk
    case bike
    case otherOutdoor
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .run: return "Carrera"
        case .walk: return "Caminata"
        case .bike: return "Bici"
        case .otherOutdoor: return "Otro"
        }
    }
    
    var iconName: String {
        switch self {
        case .run: return "figure.run"
        case .walk: return "figure.walk"
        case .bike: return "bicycle"
        case .otherOutdoor: return "figure.hiking"
        }
    }
}

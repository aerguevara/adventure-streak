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
        case .run: return "Correr"
        case .walk: return "Caminar"
        case .bike: return "Ciclismo"
        case .hike: return "Senderismo"
        case .otherOutdoor: return "Aire Libre"
        case .indoor: return "Interior"
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

import HealthKit

extension ActivityType {
    init(hkType: HKWorkoutActivityType, isIndoor: Bool = false) {
        if isIndoor {
            self = .indoor
            return
        }
        
        switch hkType {
        case .running: self = .run
        case .walking: self = .walk
        case .cycling: self = .bike
        case .hiking: self = .hike
        case .traditionalStrengthTraining, .functionalStrengthTraining, .highIntensityIntervalTraining:
            self = .indoor
        default: self = .otherOutdoor
        }
    }
}

extension HKWorkout {
    var activityType: ActivityType {
        let isIndoor = (metadata?["HKIndoorWorkout"] as? Bool) ?? false
        return ActivityType(hkType: workoutActivityType, isIndoor: isIndoor)
    }
    
    var workoutName: String {
        if let title = metadata?["HKWorkoutTitle"] as? String, !title.isEmpty {
            return title
        }
        if let brand = metadata?["HKWorkoutBrandName"] as? String, !brand.isEmpty {
            return brand
        }
        
        switch workoutActivityType {
        case .running: return "Correr"
        case .walking: return "Caminar"
        case .cycling: return "Ciclismo"
        case .hiking: return "Senderismo"
        case .traditionalStrengthTraining: return "Fuerza Tradicional"
        case .functionalStrengthTraining: return "Fuerza Funcional"
        case .highIntensityIntervalTraining: return "HIIT"
        case .flexibility: return "Flexibilidad"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        default: return "Entrenamiento"
        }
    }
}

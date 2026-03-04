import Foundation

enum ActivityType: String, Codable, CaseIterable, Identifiable {
    case run
    case walk
    case bike
    case hike
    case otherOutdoor
    case indoor // Legacy/Generic
    
    // Detailed Indoor/Gym types
    case strength
    case functional
    case hiit
    case yoga
    case pilates
    case crossTraining
    case dance
    case core
    case flexibility
    case preparationAndRecovery
    case stairClimbing
    case swimming
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .run: return "Correr"
        case .walk: return "Caminar"
        case .bike: return "Ciclismo"
        case .hike: return "Senderismo"
        case .otherOutdoor: return "Aire Libre"
        case .indoor: return "Interior"
        case .strength: return "Fuerza"
        case .functional: return "Funcional"
        case .hiit: return "HIIT"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .crossTraining: return "Cross Training"
        case .dance: return "Baile"
        case .core: return "Core"
        case .flexibility: return "Flexibilidad"
        case .preparationAndRecovery: return "Recuperación"
        case .stairClimbing: return "Escaleras"
        case .swimming: return "Natación"
        }
    }
    
    var iconName: String {
        switch self {
        case .run: return "figure.run"
        case .walk: return "figure.walk"
        case .bike: return "bicycle"
        case .hike: return "figure.hiking"
        case .otherOutdoor: return "figure.outdoor.cycle"
        case .indoor: return "dumbbell"
        case .strength: return "figure.strengthtraining.traditional"
        case .functional: return "figure.strengthtraining.functional"
        case .hiit: return "figure.highintensity.intervaltraining"
        case .yoga: return "figure.yoga"
        case .pilates: return "figure.pilates"
        case .crossTraining: return "figure.cross.training"
        case .dance: return "figure.dance"
        case .core: return "figure.core.training"
        case .flexibility: return "figure.flexibility"
        case .preparationAndRecovery: return "figure.mindful.cooldown"
        case .stairClimbing: return "figure.stair.stepper"
        case .swimming: return "figure.pool.swim"
        }
    }
    
    var isOutdoor: Bool {
        switch self {
        case .run, .walk, .bike, .hike, .otherOutdoor:
            return true
        default:
            return false
        }
    }
}

import SwiftUI

extension ActivityType {
    var color: Color {
        switch self {
        case .run: return Color(hex: "FF3B30") // Red
        case .walk: return Color(hex: "32D74B") // Green
        case .bike: return Color(hex: "5856D6") // Indigo
        case .hike: return Color(hex: "FF9500") // Orange
        case .otherOutdoor: return Color(hex: "64D2FF") // Light Blue
        case .indoor: return Color(hex: "A259FF") // Purple
        case .strength, .functional, .crossTraining, .core: return Color(hex: "FF2D55") // Rose
        case .hiit: return Color(hex: "FFCC00") // Yellow
        case .yoga, .pilates, .flexibility, .preparationAndRecovery: return Color(hex: "AF52DE") // Purple/Lavender
        case .dance: return Color(hex: "FF9500") // Orange/Gold
        case .stairClimbing: return Color(hex: "8E8E93") // Gray
        case .swimming: return Color(hex: "007AFF") // Blue
        }
    }
}

import HealthKit

extension ActivityType {
    init(hkType: HKWorkoutActivityType, isIndoor: Bool = false) {
        switch hkType {
        case .running: self = isIndoor ? .indoor : .run
        case .walking: self = isIndoor ? .indoor : .walk
        case .cycling: self = isIndoor ? .indoor : .bike
        case .hiking: self = .hike
        case .traditionalStrengthTraining: self = .strength
        case .functionalStrengthTraining: self = .functional
        case .highIntensityIntervalTraining: self = .hiit
        case .yoga: self = .yoga
        case .pilates: self = .pilates
        case .crossTraining: self = .crossTraining
        case .dance, .danceInspiredTraining: self = .dance
        case .coreTraining: self = .core
        case .flexibility: self = .flexibility
        case .preparationAndRecovery: self = .preparationAndRecovery
        case .stairClimbing: self = .stairClimbing
        case .swimming: self = .swimming
        default:
            self = isIndoor ? .indoor : .otherOutdoor
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

// IMPLEMENTATION: ADVENTURE STREAK GAME SYSTEM
import Foundation

@MainActor
class MissionEngine {
    static let shared = MissionEngine()
    
    private init() {}
    
    /// Classifies an activity into one or more missions based on achievements
    func classifyMissions(
        for activity: ActivitySession,
        territoryStats: TerritorialDelta,
        context: XPContext
    ) async throws -> [Mission] {
        var missions: [Mission] = []
        let userId = context.userId
        
        // 1. Territorial Missions
        if territoryStats.newCellsCount > 0 {
            let mission = createTerritorialMission(
                userId: userId,
                activity: activity,
                territoryStats: territoryStats
            )
            missions.append(mission)
        }
        
        // 2. Recapture Mission (Epic)
        if territoryStats.recapturedCellsCount > 0 {
            let mission = createRecaptureMission(
                userId: userId,
                activity: activity,
                territoryStats: territoryStats
            )
            missions.append(mission)
        }
        
        // 3. Streak Mission
        if context.currentStreakWeeks > 0 {
            let mission = createStreakMission(
                userId: userId,
                activity: activity,
                streakWeeks: context.currentStreakWeeks
            )
            missions.append(mission)
        }
        
        // 4. Weekly Record Mission
        let newWeekDistance = context.currentWeekDistanceKm + (activity.distanceMeters / 1000.0)
        if let bestWeekly = context.bestWeeklyDistanceKm, newWeekDistance > bestWeekly {
            let mission = createWeeklyRecordMission(
                userId: userId,
                activity: activity,
                newDistance: newWeekDistance,
                previousBest: bestWeekly
            )
            missions.append(mission)
        }
        
        // 5. Physical Effort Mission (High intensity)
        if isHighIntensity(activity) {
            let mission = createPhysicalEffortMission(
                userId: userId,
                activity: activity
            )
            missions.append(mission)
        }
        
        return missions
    }
    
    // MARK: - Mission Creators
    
    private func createTerritorialMission(
        userId: String,
        activity: ActivitySession,
        territoryStats: TerritorialDelta
    ) -> Mission {
        let cellCount = territoryStats.newCellsCount
        let rarity: MissionRarity
        let name: String
        let description: String
        
        switch cellCount {
        case 0..<5:
            rarity = .common
            name = "Exploración Inicial"
            description = "Has conquistado \(cellCount) nuevos territorios"
        case 5..<15:
            rarity = .rare
            name = "Expedición"
            description = "Has expandido tu dominio con \(cellCount) territorios"
        case 15..<XPConfig.legendaryThresholdCells:
            rarity = .epic
            name = "Conquista Épica"
            description = "¡Impresionante! \(cellCount) territorios conquistados"
        default:
            rarity = .legendary
            name = "Dominio Legendario"
            description = "¡Hazaña legendaria! \(cellCount) territorios bajo tu control"
        }
        
        return Mission(
            userId: userId,
            category: .territorial,
            name: name,
            description: description,
            rarity: rarity
        )
    }
    
    private func createRecaptureMission(
        userId: String,
        activity: ActivitySession,
        territoryStats: TerritorialDelta
    ) -> Mission {
        let count = territoryStats.recapturedCellsCount
        
        return Mission(
            userId: userId,
            category: .territorial,
            name: "Reconquista",
            description: "Has recuperado \(count) territorios perdidos",
            rarity: .epic
        )
    }
    
    private func createStreakMission(
        userId: String,
        activity: ActivitySession,
        streakWeeks: Int
    ) -> Mission {
        let rarity: MissionRarity = streakWeeks >= 4 ? .epic : .rare
        
        return Mission(
            userId: userId,
            category: .progression,
            name: "Racha Activa",
            description: "Semana #\(streakWeeks) de tu racha",
            rarity: rarity
        )
    }
    
    private func createWeeklyRecordMission(
        userId: String,
        activity: ActivitySession,
        newDistance: Double,
        previousBest: Double
    ) -> Mission {
        let improvement = newDistance - previousBest
        let rarity: MissionRarity = improvement > 10 ? .legendary : .epic
        
        return Mission(
            userId: userId,
            category: .progression,
            name: "Nuevo Récord Semanal",
            description: String(format: "¡%.1f km esta semana! Superaste tu récord", newDistance),
            rarity: rarity
        )
    }
    
    private func createPhysicalEffortMission(
        userId: String,
        activity: ActivitySession
    ) -> Mission {
        let pace = activity.durationSeconds / (activity.distanceMeters / 1000.0)
        let isSprintPace = activity.activityType == .run && pace < 360 // < 6 min/km
        
        return Mission(
            userId: userId,
            category: .physicalEffort,
            name: isSprintPace ? "Sprint Intenso" : "Esfuerzo Destacado",
            description: "Entrenamiento de alta intensidad completado",
            rarity: isSprintPace ? .rare : .common
        )
    }
    
    // MARK: - Helpers
    
    private func isHighIntensity(_ activity: ActivitySession) -> Bool {
        guard activity.distanceMeters > 0 else { return false }
        
        let pace = activity.durationSeconds / (activity.distanceMeters / 1000.0) // seconds per km
        
        switch activity.activityType {
        case .run:
            return pace < 360 // < 6 min/km
        case .bike:
            return pace < 180 // < 3 min/km (20+ km/h)
        case .walk, .hike:
            return pace < 720 // < 12 min/km
        case .otherOutdoor:
            return false
        }
    }
}

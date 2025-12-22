import Foundation

@MainActor
class GamificationService: ObservableObject {
    nonisolated static let shared = GamificationService()
    
    private let repository = GamificationRepository.shared
    
    @Published var currentXP: Int = 0
    @Published var currentLevel: Int = 1
    
    nonisolated init() {}
    
    // MARK: - Public Interface
    
    func syncState(xp: Int, level: Int) {
        self.currentXP = xp
        self.currentLevel = level
    }
    
    /// ESTIMATION ONLY: Used for UI suggestions (Next Goal). 
    /// Real calculation is performed on the Server.
    func estimateXP(for activity: ActivitySession,
                    context: XPContext) -> Int {
        
        let xpBase = estimateBaseXP(for: activity, context: context)
        
        // Simplified: ignore territory/streak/bonus for simple UI estimations
        return xpBase
    }
    
    // MARK: - Internal Estimation Logic
    
    private func estimateBaseXP(for activity: ActivitySession, context: XPContext) -> Int {
        let distanceKm = activity.distanceMeters / 1000.0
        let durationSeconds = activity.durationSeconds
        
        if activity.activityType == .indoor {
            guard durationSeconds >= XPConfig.minDurationSeconds else { return 0 }
            let minutes = durationSeconds / 60.0
            let rawXP = Int(minutes * XPConfig.indoorXPPerMinute)
            return rawXP
        }
        
        guard distanceKm >= XPConfig.minDistanceKm,
              durationSeconds >= XPConfig.minDurationSeconds else {
            return 0
        }
        
        var factor = XPConfig.baseFactorPerKm
        switch activity.activityType {
        case .run: factor *= XPConfig.factorRun
        case .bike: factor *= XPConfig.factorBike
        case .walk: factor *= XPConfig.factorWalk
        case .hike: factor *= XPConfig.factorWalk
        case .otherOutdoor: factor *= XPConfig.factorOther
        case .indoor: factor *= XPConfig.factorIndoor
        }
        
        return Int(distanceKm * factor)
    }
    
    // Helper for UI progress
    func xpForNextLevel(level: Int) -> Int {
        return level * 1000
    }
    
    func progressToNextLevel(currentXP: Int, currentLevel: Int) -> Double {
        let nextLevelThreshold = xpForNextLevel(level: currentLevel)
        let previousLevelThreshold = xpForNextLevel(level: currentLevel - 1)
        
        let xpInCurrentLevel = currentXP - previousLevelThreshold
        let xpNeededForLevel = nextLevelThreshold - previousLevelThreshold
        
        guard xpNeededForLevel > 0 else { return 0.0 }
        
        return Double(xpInCurrentLevel) / Double(xpNeededForLevel)
    }
}

import Foundation

// NEW: Added for multiplayer conquest feature
protocol GamificationServiceProtocol {
    func computeXP(for activity: ActivitySession,
                   territoryStats: TerritoryStats,
                   context: XPContext) async throws -> XPBreakdown

    func applyXP(_ breakdown: XPBreakdown,
                 to userId: String,
                 at date: Date) async throws
}

class GamificationService: ObservableObject, GamificationServiceProtocol {
    static let shared = GamificationService()
    
    private let repository = GamificationRepository.shared
    
    @Published var currentXP: Int = 0
    @Published var currentLevel: Int = 1
    
    // MARK: - Public Interface
    
    func syncState(xp: Int, level: Int) {
        Task { @MainActor in
            self.currentXP = xp
            self.currentLevel = level
        }
    }
    
    func computeXP(for activity: ActivitySession,
                   territoryStats: TerritoryStats,
                   context: XPContext) async throws -> XPBreakdown {
        
        // 1. Base XP
        let xpBase = computeBaseXP(for: activity, context: context)
        
        // 2. Territory XP
        let xpTerritory = computeTerritoryXP(from: territoryStats)
        
        // 3. Streak Bonus
        // Logic: If activity duration > min and it's a new week (simplified for MVP: always check context)
        // For MVP, let's assume any valid activity maintains streak if not already extended this week
        let maintainsStreak = activity.durationSeconds >= XPConfig.minDurationSeconds
        let xpStreak = computeStreakBonus(for: activity, context: context, maintainsStreak: maintainsStreak)
        
        // 4. Weekly Record
        let newWeekDistance = context.currentWeekDistanceKm + (activity.distanceMeters / 1000.0)
        let xpWeeklyRecord = computeWeeklyRecordBonus(for: activity, context: context, newWeekDistanceKm: newWeekDistance)
        
        // 5. Badges (Placeholder for now, would integrate BadgeService)
        let xpBadges = 0 
        
        return XPBreakdown(
            xpBase: xpBase,
            xpTerritory: xpTerritory,
            xpStreak: xpStreak,
            xpWeeklyRecord: xpWeeklyRecord,
            xpBadges: xpBadges
        )
    }
    
    func applyXP(_ breakdown: XPBreakdown,
                 to userId: String,
                 at date: Date) async throws {
        
        // GUARD: Never apply XP to "unknown_user"
        guard userId != "unknown_user" && !userId.isEmpty else {
            print("⚠️ [Gamification] Aborting applyXP: Invalid userId '\(userId)'")
            return
        }
        
        // 1. Fetch current state (or use context if passed, but safer to fetch fresh)
        // For MVP we rely on repository update which merges
        let context = try await repository.buildXPContext(for: userId)
        var state = context.gamificationState
        
        // 2. Update State
        state.totalXP += breakdown.total
        
        // 3. Recalculate Level (Simple formula: Level = 1 + XP / 1000)
        let newLevel = 1 + (state.totalXP / 1000)
        state.level = newLevel
        
        // 4. Persist
        repository.updateUserStats(userId: userId, xp: state.totalXP, level: state.level)
        
        // Update local published state ONLY if it's the current user
        let finalXP = state.totalXP
        let finalLevel = state.level
        
        if userId == AuthenticationService.shared.userId {
            await MainActor.run {
                self.currentXP = finalXP
                self.currentLevel = finalLevel
            }
        }
    }
    
    // MARK: - Internal Calculation Logic
    
    func computeBaseXP(for activity: ActivitySession, context: XPContext) -> Int {
        let distanceKm = activity.distanceMeters / 1000.0
        let durationSeconds = activity.durationSeconds
        
        // Indoor sin distancia: calcula por minutos
        if activity.activityType == .indoor {
            guard durationSeconds >= XPConfig.minDurationSeconds else { return 0 }
            let minutes = durationSeconds / 60.0
            let rawXP = Int(minutes * XPConfig.indoorXPPerMinute)
            let remainingCap = max(0, XPConfig.dailyBaseXPCap - context.todayBaseXPEarned)
            return min(rawXP, remainingCap)
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

        // Outdoor sin ruta: factor reducido
        if activity.activityType.isOutdoor && activity.route.isEmpty {
            factor = XPConfig.baseFactorPerKm * XPConfig.factorIndoor
        }
        
        let rawXP = Int(distanceKm * factor)
        
        let remainingCap = max(0, XPConfig.dailyBaseXPCap - context.todayBaseXPEarned)
        return min(rawXP, remainingCap)
    }
    
    func computeTerritoryXP(from stats: TerritoryStats) -> Int {
        let effectiveNewCells = min(stats.newCellsCount, XPConfig.maxNewCellsXPPerActivity)
        
        let xpNew = effectiveNewCells * XPConfig.xpPerNewCell
        let xpDef = stats.defendedCellsCount * XPConfig.xpPerDefendedCell
        let xpRec = stats.recapturedCellsCount * XPConfig.xpPerRecapturedCell
        
        return xpNew + xpDef + xpRec
    }
    
    func computeStreakBonus(for activity: ActivitySession, context: XPContext, maintainsStreak: Bool) -> Int {
        guard maintainsStreak else { return 0 }
        // Bonus is proportional to streak length
        return XPConfig.baseStreakXPPerWeek * context.currentStreakWeeks
    }
    
    func computeWeeklyRecordBonus(for activity: ActivitySession, context: XPContext, newWeekDistanceKm: Double) -> Int {
        guard let best = context.bestWeeklyDistanceKm, best >= XPConfig.minWeeklyRecordKm else {
            return 0 // No previous record or record too low
        }
        
        if newWeekDistanceKm > best {
            let diff = newWeekDistanceKm - best
            return XPConfig.weeklyRecordBaseXP + Int(diff * Double(XPConfig.weeklyRecordPerKmDiffXP))
        }
        
        return 0
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

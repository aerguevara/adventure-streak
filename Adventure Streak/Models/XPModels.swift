import Foundation

// NEW: XP system implementation for Adventure Streak

// 1. Configuration
enum XPConfig {
    static let minDistanceKm: Double = 0.5
    static let minDurationSeconds: Double = 5 * 60

    static let baseFactorPerKm: Double = 10.0
    static let factorRun: Double = 1.2
    static let factorBike: Double = 0.7
    static let factorWalk: Double = 0.9
    static let factorOther: Double = 1.0

    static let dailyBaseXPCap: Int = 300

    static let xpPerNewCell: Int = 8
    static let xpPerDefendedCell: Int = 3
    static let xpPerRecapturedCell: Int = 12
    static let maxNewCellsXPPerActivity: Int = 50

    static let baseStreakXPPerWeek: Int = 10  // XP = 10 * currentStreakWeeks

    static let weeklyRecordBaseXP: Int = 30
    static let weeklyRecordPerKmDiffXP: Int = 5
    static let minWeeklyRecordKm: Double = 5.0
}

// 2. Breakdown of earned XP
struct XPBreakdown: Codable, Hashable {
    let xpBase: Int
    let xpTerritory: Int
    let xpStreak: Int
    let xpWeeklyRecord: Int
    let xpBadges: Int
    
    var total: Int {
        xpBase + xpTerritory + xpStreak + xpWeeklyRecord + xpBadges
    }
}

// 3. Context required for calculation
struct XPContext {
    let userId: String
    let currentWeekDistanceKm: Double
    let bestWeeklyDistanceKm: Double?
    let currentStreakWeeks: Int
    let todayBaseXPEarned: Int
    let gamificationState: GamificationState
}

// 4. Territory Stats for calculation
struct TerritoryStats {
    let newCellsCount: Int
    let defendedCellsCount: Int
    let recapturedCellsCount: Int
}

// 5. User Gamification State
struct GamificationState: Codable {
    var totalXP: Int
    var level: Int
    var currentStreakWeeks: Int
    // Add other persistent state if needed
}

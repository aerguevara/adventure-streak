import Foundation

struct NextObjective: Identifiable {
    let id = UUID()
    let user: RankingEntry
    let rival: RankingEntry
    let deltaXP: Int

    var progress: Double {
        guard rival.weeklyXP > 0 else { return 0 }
        return min(1.0, max(0.0, Double(user.weeklyXP) / Double(rival.weeklyXP)))
    }
}

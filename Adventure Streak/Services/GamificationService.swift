import Foundation

// NEW: Added for multiplayer conquest feature
class GamificationService: ObservableObject {
    static let shared = GamificationService()
    
    private let repository = GamificationRepository.shared
    
    @Published var currentXP: Int = 0
    @Published var currentLevel: Int = 1
    
    // NEW: Constants for balancing
    private let xpPerLevel = 1000
    private let xpPerConquest = 100
    private let xpPerRecapture = 150
    
    // NEW: Award XP for conquering a territory
    func awardConquestXP() {
        addXP(amount: xpPerConquest)
    }
    
    // NEW: Award Bonus XP for recapturing a lost territory
    func awardRecaptureBonusXP(cellId: String) {
        addXP(amount: xpPerRecapture)
        // Check for "Defensor" badge logic here (simplified)
        checkBadgeEligibility(badgeId: "defensor")
    }
    
    // NEW: Award XP for weekly distance milestone
    func awardWeeklyDistanceBonusIfEligible(distance: Double) {
        if distance > 50000 { // 50km example
            addXP(amount: 500)
        }
    }
    
    private func addXP(amount: Int) {
        currentXP += amount
        checkLevelUp()
        // Sync with repository
        // repository.updateUserStats(userId: "current_user_id", xp: currentXP, level: currentLevel)
    }
    
    private func checkLevelUp() {
        let newLevel = (currentXP / xpPerLevel) + 1
        if newLevel > currentLevel {
            currentLevel = newLevel
            // Trigger level up notification or event
        }
    }
    
    private func checkBadgeEligibility(badgeId: String) {
        // Logic to check if badge is already owned, if not, award it
        // repository.awardBadge(userId: "current_user_id", badgeId: badgeId)
    }
    // NEW: Helper to calculate XP required for next level
    func xpForNextLevel(level: Int) -> Int {
        return level * xpPerLevel
    }
    
    // NEW: Helper to calculate progress to next level (0.0 - 1.0)
    func progressToNextLevel(currentXP: Int, currentLevel: Int) -> Double {
        let nextLevelThreshold = xpForNextLevel(level: currentLevel)
        let previousLevelThreshold = xpForNextLevel(level: currentLevel - 1)
        
        let xpInCurrentLevel = currentXP - previousLevelThreshold
        let xpNeededForLevel = nextLevelThreshold - previousLevelThreshold
        
        guard xpNeededForLevel > 0 else { return 0.0 }
        
        return Double(xpInCurrentLevel) / Double(xpNeededForLevel)
    }
}

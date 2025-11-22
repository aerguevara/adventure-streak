import Foundation
import SwiftUI

@MainActor
class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var userDisplayName: String = "Adventurer"
    @Published var avatarURL: URL? = nil
    @Published var level: Int = 1
    @Published var totalXP: Int = 0
    @Published var nextLevelXP: Int = 1000
    @Published var xpProgress: Double = 0.0
    @Published var streakWeeks: Int = 0
    @Published var territoriesCount: Int = 0
    @Published var activitiesCount: Int = 0
    @Published var totalCellsConquered: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // MARK: - Dependencies
    private let activityStore: ActivityStore
    private let territoryStore: TerritoryStore
    private let userRepository: UserRepository
    private let authService: AuthenticationService
    private let gamificationService: GamificationService
    
    // MARK: - Init
    init(activityStore: ActivityStore, 
         territoryStore: TerritoryStore, 
         userRepository: UserRepository = .shared,
         authService: AuthenticationService = .shared,
         gamificationService: GamificationService = .shared) {
        self.activityStore = activityStore
        self.territoryStore = territoryStore
        self.userRepository = userRepository
        self.authService = authService
        self.gamificationService = gamificationService
        
        // Initial load
        fetchProfileData()
    }
    
    // MARK: - Actions
    func fetchProfileData() {
        isLoading = true
        errorMessage = nil
        
        // 1. Refresh local stats
        refreshLocalStats()
        
        // 2. Fetch remote user profile
        guard let userId = authService.userId else {
            isLoading = false
            return
        }
        
        userRepository.fetchUser(userId: userId) { [weak self] user in
            guard let self = self else { return }
            self.isLoading = false
            
            if let user = user {
                self.updateWithUser(user)
            } else {
                // If fetch fails but we have local auth, maybe show error or just keep defaults
                // For MVP, we might just rely on defaults or local cache if we had it
                print("Could not fetch user profile")
            }
        }
    }
    
    func signOut() {
        authService.signOut()
    }
    
    func refreshGamification() {
        // In a real app, this might trigger a cloud function or re-fetch
        fetchProfileData()
    }
    
    // MARK: - Helpers
    private func refreshLocalStats() {
        self.streakWeeks = activityStore.calculateCurrentStreak()
        self.activitiesCount = activityStore.activities.count
        self.territoriesCount = territoryStore.conqueredCells.count
        // For total cells conquered historically, we might need a separate counter in ActivityStore or User model.
        // For MVP, we'll use the current count as a proxy or sum from activities if available.
        // Let's use current count for now as "Cells Owned"
        self.totalCellsConquered = territoryStore.conqueredCells.count 
    }
    
    private func updateWithUser(_ user: User) {
        self.userDisplayName = user.displayName ?? "Adventurer"
        self.level = user.level
        self.totalXP = user.xp
        
        // Calculate progress
        self.nextLevelXP = gamificationService.xpForNextLevel(level: self.level)
        self.xpProgress = gamificationService.progressToNextLevel(currentXP: self.totalXP, currentLevel: self.level)
    }
}

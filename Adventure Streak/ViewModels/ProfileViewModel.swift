import Foundation
import SwiftUI
import Combine

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
    
    // MARK: - Computed Properties
    var userTitle: String {
        switch level {
        case 1...5: return "Rookie Scout"
        case 6...10: return "Pathfinder"
        case 11...20: return "Trailblazer"
        case 21...30: return "Explorer"
        case 31...50: return "Conqueror"
        case 51...99: return "Legend"
        default: return "Novice"
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Dependencies
    let activityStore: ActivityStore
    let territoryStore: TerritoryStore
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
        
        // Observe GamificationService for real-time updates
        setupObservers()
    }
    
    private func setupObservers() {
        // When GamificationService updates (e.g. after activity), update local UI
        gamificationService.$currentXP
            .receive(on: RunLoop.main)
            .sink { [weak self] xp in
                self?.totalXP = xp
            }
            .store(in: &cancellables)
            
        gamificationService.$currentLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                self?.level = level
            }
            .store(in: &cancellables)
            
        // Re-calculate progress when XP/Level changes
        gamificationService.$currentXP
            .combineLatest(gamificationService.$currentLevel)
            .receive(on: RunLoop.main)
            .sink { [weak self] (xp, level) in
                guard let self = self else { return }
                self.nextLevelXP = self.gamificationService.xpForNextLevel(level: level)
                self.xpProgress = self.gamificationService.progressToNextLevel(currentXP: xp, currentLevel: level)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    func fetchProfileData() {
        isLoading = true
        errorMessage = nil
        
        // 1. Refresh local stats
        refreshLocalStats()
        
        // 2. Fetch remote user profile (Real-time)
        guard let userId = authService.userId else {
            isLoading = false
            return
        }
        
        print("DEBUG: Observing User ID: \(userId)")
        
        // Remove existing listener if any
        // (In a real app we'd track the listener registration to remove it on deinit)
        
        _ = userRepository.observeUser(userId: userId) { [weak self] user in
            guard let self = self else { return }
            self.isLoading = false
            
            if let user = user {
                print("DEBUG: Fetched user (ID: \(user.id ?? "nil")): \(user.displayName ?? "nil"), XP: \(user.xp), Level: \(user.level)")
                self.updateWithUser(user)
            } else {
                print("DEBUG: Could not fetch user profile or user is nil for ID: \(userId)")
            }
        }
    }
    
    func signOut() {
        // Clear local data to allow fresh import for next user
        activityStore.clear()
        territoryStore.clear()
        FeedRepository.shared.clear()
        SocialService.shared.clear()
        
        authService.signOut()
    }
    
    func refreshGamification() {
        // In a real app, this might trigger a cloud function or re-fetch
        fetchProfileData()
    }
    
    // MARK: - Helpers
    private func refreshLocalStats() {
        self.streakWeeks = activityStore.calculateCurrentStreak()
        
        // Filter for last 7 days
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        // Activities in last 7 days
        self.activitiesCount = activityStore.activities.filter { $0.startDate >= sevenDaysAgo }.count
        
        // Territories conquered in last 7 days
        // Note: 'conqueredCells' contains current ownership. We check 'lastConqueredAt'.
        self.territoriesCount = territoryStore.conqueredCells.values.filter { $0.lastConqueredAt >= sevenDaysAgo }.count
        
        // Total Cells Owned (Historical/Current Total)
        self.totalCellsConquered = territoryStore.conqueredCells.count 
    }
    
    private func updateWithUser(_ user: User) {
        self.userDisplayName = user.displayName ?? "Adventurer"
        
        // Sync GamificationService with fetched data
        // This will trigger the observers above to update the UI properties
        gamificationService.syncState(xp: user.xp, level: user.level)
    }
}

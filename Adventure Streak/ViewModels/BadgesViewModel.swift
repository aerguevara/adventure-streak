import Foundation
import SwiftUI

@MainActor
class BadgesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var badges: [Badge] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var selectedBadge: Badge? = nil
    
    // MARK: - Computed Properties
    var unlockedCount: Int {
        badges.filter { $0.isUnlocked }.count
    }
    
    var totalCount: Int {
        badges.count
    }
    
    // MARK: - Dependencies
    private let repository: GamificationRepository
    private let authService: AuthenticationService
    
    // MARK: - Init
    init(repository: GamificationRepository = .shared, authService: AuthenticationService = .shared) {
        self.repository = repository
        self.authService = authService
        fetchBadges()
    }
    
    // MARK: - Actions
    func fetchBadges() {
        guard let userId = authService.userId else {
            errorMessage = "User not logged in"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        repository.fetchBadges(userId: userId) { [weak self] fetchedBadges in
            guard let self = self else { return }
            self.badges = fetchedBadges
            self.isLoading = false
        }
    }
    
    func onBadgeSelected(_ badge: Badge) {
        self.selectedBadge = badge
    }
}

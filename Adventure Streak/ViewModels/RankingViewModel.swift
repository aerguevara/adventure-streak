import Foundation
import SwiftUI

@MainActor
class RankingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var entries: [RankingEntry] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var selectedScope: RankingScope = .weekly
    
    // MARK: - Computed Properties
    var currentUserEntry: RankingEntry? {
        entries.first { $0.isCurrentUser }
    }
    
    var hasEntries: Bool {
        !entries.isEmpty
    }
    
    // MARK: - Dependencies
    private let repository: GamificationRepository
    private let authService: AuthenticationService
    
    // MARK: - Init
    init(repository: GamificationRepository = .shared, authService: AuthenticationService = .shared) {
        self.repository = repository
        self.authService = authService
        fetchRanking()
    }
    
    // MARK: - Actions
    func fetchRanking() {
        isLoading = true
        errorMessage = nil
        
        repository.fetchWeeklyRanking(limit: 50) { [weak self] fetchedEntries in
            guard let self = self else { return }
            
            Task { @MainActor in
                // Mark current user
                var processedEntries = fetchedEntries
                if let currentUserId = self.authService.userId {
                    for i in 0..<processedEntries.count {
                        if processedEntries[i].userId == currentUserId {
                            processedEntries[i].isCurrentUser = true
                        }
                        
                        // Mock data for redesign
                        processedEntries[i].xpProgress = Double.random(in: 0.3...0.9)
                        // processedEntries[i].trend = RankingTrend.allCases.randomElement() ?? .neutral
                        processedEntries[i].isFollowing = SocialService.shared.isFollowing(userId: processedEntries[i].userId)
                    }
                }
                
                // Sort by position to ensure Podium works correctly
                processedEntries.sort { $0.position < $1.position }
                
                self.entries = processedEntries
                self.isLoading = false
                
                if self.entries.isEmpty {
                    // Optional: Set specific message if empty but no error
                    // self.errorMessage = "No ranking data available yet."
                }
            }
        }
    }
    
    func onScopeChanged(_ scope: RankingScope) {
        self.selectedScope = scope
        fetchRanking()
    }
    
    func toggleFollow(for entry: RankingEntry) {
        if entry.isFollowing {
            SocialService.shared.unfollowUser(userId: entry.userId)
        } else {
            SocialService.shared.followUser(userId: entry.userId)
        }
        
        // Update local state
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index].isFollowing.toggle()
        }
    }
}

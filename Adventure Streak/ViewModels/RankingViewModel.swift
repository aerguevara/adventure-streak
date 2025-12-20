import Foundation
import SwiftUI

@MainActor
class RankingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var entries: [RankingEntry] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var selectedScope: RankingScope = .weekly
    
    // Profile Sheet
    @Published var showProfileSheet: Bool = false
    @Published var selectedUser: User? = nil
    
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
    private let socialService: SocialService
    private var followingCancellable: Any?
    private let avatarCache = AvatarCacheManager.shared
    
    // MARK: - Init
    init(repository: GamificationRepository = .shared,
         authService: AuthenticationService = .shared,
         socialService: SocialService? = nil) {
        self.repository = repository
        self.authService = authService
        self.socialService = socialService ?? SocialService.shared
        observeFollowing()
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
                var missingAvatarIds: Set<String> = []
                if let currentUserId = self.authService.userId {
                    for i in 0..<processedEntries.count {
                        if processedEntries[i].userId == currentUserId {
                            processedEntries[i].isCurrentUser = true
                        }
                        
                        // Mock data for redesign
                        processedEntries[i].xpProgress = Double.random(in: 0.3...0.9)
                        processedEntries[i].isFollowing = self.socialService.isFollowing(userId: processedEntries[i].userId)
                        if let data = self.avatarCache.data(for: processedEntries[i].userId) {
                            processedEntries[i].avatarData = data
                        } else {
                            missingAvatarIds.insert(processedEntries[i].userId)
                        }
                    }
                }
                
                // Sort by position to ensure Podium works correctly
                processedEntries.sort { $0.position < $1.position }
                
                self.entries = processedEntries
                self.isLoading = false
                
                if !missingAvatarIds.isEmpty {
                    Task {
                        await self.socialService.fetchAvatars(for: missingAvatarIds)
                        await MainActor.run {
                            self.entries = self.entries.map { entry in
                                var updated = entry
                                if let data = self.avatarCache.data(for: entry.userId) {
                                    updated.avatarData = data
                                }
                                return updated
                            }
                        }
                    }
                }
                
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
            socialService.unfollowUser(userId: entry.userId)
        } else {
            socialService.followUser(userId: entry.userId, displayName: entry.displayName)
        }
        
        // Update local state
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index].isFollowing.toggle()
        }
    }
    
    func selectUser(userId: String) {
        UserRepository.shared.fetchUser(userId: userId) { [weak self] user in
            guard let self = self else { return }
            Task { @MainActor in
                self.selectedUser = user
                self.showProfileSheet = true
            }
        }
    }
    
    private func observeFollowing() {
        followingCancellable = socialService.$followingIds
            .sink { [weak self] ids in
                guard let self = self else { return }
                self.entries = self.entries.map { entry in
                    var updated = entry
                    updated.isFollowing = ids.contains(entry.userId)
                    return updated
                }
            }
    }
}

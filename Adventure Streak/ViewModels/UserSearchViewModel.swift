import Foundation
import Combine

@MainActor
class UserSearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [RankingEntry] = []
    @Published var topActive: [RankingEntry] = []
    @Published var isLoading: Bool = false
    
    private let repository = GamificationRepository.shared
    private let socialService = SocialService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Debounce search text changes
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
        
        // Load top active on init
        fetchTopActive()
        
        // NEW: Observar cambios globales en seguidos
        socialService.$followingIds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.searchResults = self.applyFollowStatus(to: self.searchResults)
                self.topActive = self.applyFollowStatus(to: self.topActive)
            }
            .store(in: &cancellables)
    }
    
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            // Default to top active list when search is empty
            searchResults = topActive
            return
        }
        
        isLoading = true
        
        repository.searchUsers(query: query) { [weak self] results in
            guard let self = self else { return }
            
            Task { @MainActor in
                // Filter out current user
                let currentUserId = AuthenticationService.shared.userId
                var filteredResults = results.filter { $0.userId != currentUserId }
                filteredResults = self.applyFollowStatus(to: filteredResults)
                filteredResults = self.applyAvatarData(to: filteredResults)
                self.searchResults = filteredResults
                
                let missingIds = Set(filteredResults.filter { $0.avatarData == nil && $0.avatarURL == nil }.map { $0.userId })
                if !missingIds.isEmpty {
                    Task {
                        await SocialService.shared.fetchAvatars(for: missingIds)
                        await MainActor.run {
                            self.searchResults = self.applyAvatarData(to: self.searchResults)
                            self.topActive = self.applyAvatarData(to: self.topActive)
                        }
                    }
                }
                self.isLoading = false
            }
        }
    }
    
    private func fetchTopActive() {
        isLoading = true
        repository.fetchWeeklyRanking(limit: 20) { [weak self] results in
            guard let self = self else { return }
            Task { @MainActor in
                let currentUserId = AuthenticationService.shared.userId
                var filtered = results.filter { $0.userId != currentUserId }
                filtered = self.applyFollowStatus(to: filtered)
                filtered = self.applyAvatarData(to: filtered)
                self.topActive = filtered
                // If no search text, show these
                if self.searchText.isEmpty {
                    self.searchResults = filtered
                }
                
                let missingIds = Set(filtered.filter { $0.avatarData == nil && $0.avatarURL == nil }.map { $0.userId })
                if !missingIds.isEmpty {
                    Task {
                        await SocialService.shared.fetchAvatars(for: missingIds)
                        await MainActor.run {
                            self.searchResults = self.applyAvatarData(to: self.searchResults)
                            self.topActive = self.applyAvatarData(to: self.topActive)
                        }
                    }
                }
                self.isLoading = false
            }
        }
    }
    
    private func applyFollowStatus(to entries: [RankingEntry]) -> [RankingEntry] {
        return entries.map { entry in
            var updated = entry
            updated.isFollowing = socialService.isFollowing(userId: entry.userId)
            return updated
        }
    }
    
    private func applyAvatarData(to entries: [RankingEntry]) -> [RankingEntry] {
        let cache = AvatarCacheManager.shared
        return entries.map { entry in
            var updated = entry
            if let data = cache.data(for: entry.userId) {
                updated.avatarData = data
            }
            return updated
        }
    }
    
    func toggleFollow(for entry: RankingEntry) {
        if entry.isFollowing {
            socialService.unfollowUser(userId: entry.userId)
        } else {
            socialService.followUser(userId: entry.userId, displayName: entry.displayName)
        }
        
        // Se elimina la actualización manual local; el sink de followingIds se encarga
    }
}

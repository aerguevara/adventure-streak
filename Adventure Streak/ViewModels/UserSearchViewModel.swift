import Foundation
import Combine

@MainActor
class UserSearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [RankingEntry] = []
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
    }
    
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        
        repository.searchUsers(query: query) { [weak self] results in
            guard let self = self else { return }
            
            Task { @MainActor in
                // Filter out current user
                let currentUserId = AuthenticationService.shared.userId
                var filteredResults = results.filter { $0.userId != currentUserId }
                
                // Update follow status
                for i in 0..<filteredResults.count {
                    filteredResults[i].isFollowing = self.socialService.isFollowing(userId: filteredResults[i].userId)
                }
                
                self.searchResults = filteredResults
                self.isLoading = false
            }
        }
    }
    
    func toggleFollow(for entry: RankingEntry) {
        if entry.isFollowing {
            socialService.unfollowUser(userId: entry.userId)
        } else {
            socialService.followUser(userId: entry.userId)
        }
        
        // Update local state
        if let index = searchResults.firstIndex(where: { $0.id == entry.id }) {
            searchResults[index].isFollowing.toggle()
        }
    }
}

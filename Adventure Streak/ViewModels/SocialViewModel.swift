import Foundation
import Combine

@MainActor
class SocialViewModel: ObservableObject {
    @Published var posts: [SocialPost] = []
    @Published var isLoading: Bool = false
    
    private let socialService = SocialService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Subscribe to service posts
        socialService.$posts
            .receive(on: DispatchQueue.main)
            .assign(to: \.posts, on: self)
            .store(in: &cancellables)
            
        // Initial load check (optional, as service starts observing on init)
    }
    
    func refresh() async {
        // No-op for now as it's real-time, or could trigger a re-fetch in repository
    }
}

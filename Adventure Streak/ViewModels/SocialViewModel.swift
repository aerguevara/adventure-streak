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
            
        // Ensure service is observing
        socialService.startObserving()
    }
    
    func refresh() async {
        socialService.startObserving()
    }
}

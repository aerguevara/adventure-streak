import Foundation
import Combine

@MainActor
class SocialRelationsViewModel: ObservableObject {
    @Published var followers: [SocialUser] = []
    @Published var following: [SocialUser] = []
    @Published var isLoading: Bool = false
    
    private let socialService = SocialService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        socialService.$followingIds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ids in
                guard let self = self else { return }
                self.followers = self.followers.map { user in
                    var u = user
                    u.isFollowing = ids.contains(user.id)
                    return u
                }
                self.following = self.following.map { user in
                    var u = user
                    u.isFollowing = ids.contains(user.id)
                    return u
                }
            }
            .store(in: &cancellables)
    }
    
    func load(for userId: String) async {
        isLoading = true
        #if canImport(FirebaseFirestore)
        async let followingTask = socialService.fetchFollowing(for: userId)
        async let followersTask = socialService.fetchFollowers(for: userId)
        
        let results = await (followingTask, followersTask)
        self.following = results.0
        self.followers = results.1
        #else
        self.following = []
        self.followers = []
        #endif
        isLoading = false
    }
    
    func toggleFollow(userId: String, displayName: String) {
        if socialService.isFollowing(userId: userId) {
            socialService.unfollowUser(userId: userId)
        } else {
            socialService.followUser(userId: userId, displayName: displayName)
        }
        // Se elimina la actualización manual; el observador en init se encarga
    }
}

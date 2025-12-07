import Foundation

@MainActor
class SocialRelationsViewModel: ObservableObject {
    @Published var followers: [SocialUser] = []
    @Published var following: [SocialUser] = []
    @Published var isLoading: Bool = false
    
    private let socialService = SocialService.shared
    
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
    
    func toggleFollow(userId: String) {
        if socialService.isFollowing(userId: userId) {
            socialService.unfollowUser(userId: userId)
            followers = followers.map { user in
                var u = user
                if u.id == userId { u.isFollowing = false }
                return u
            }
            following = following.map { user in
                var u = user
                if u.id == userId { u.isFollowing = false }
                return u
            }
        } else {
            socialService.followUser(userId: userId)
            followers = followers.map { user in
                var u = user
                if u.id == userId { u.isFollowing = true }
                return u
            }
            following = following.map { user in
                var u = user
                if u.id == userId { u.isFollowing = true }
                return u
            }
        }
    }
}

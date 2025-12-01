import Foundation
import Combine

class SocialService: ObservableObject {
    static let shared = SocialService()
    
    @Published var followingIds: Set<String> = []
    @Published var posts: [SocialPost] = []
    
    private let feedRepository = FeedRepository.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Load persisted following state
        loadFollowingState()
        
        // Start observing feed
        feedRepository.observeFeed()
        
        // Subscribe to repository updates
        feedRepository.$events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] events in
                self?.updatePosts(from: events)
            }
            .store(in: &cancellables)
        
        // Also update when following changes
        $followingIds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePosts(from: self?.feedRepository.events ?? [])
            }
            .store(in: &cancellables)
    }
    
    private func updatePosts(from events: [FeedEvent]) {
        self.posts = events.compactMap { event -> SocialPost? in
            guard let userId = event.userId,
                  let userName = event.relatedUserName else {
                return nil
            }
            
            // Fallback for legacy events without activityData
            let finalActivityData = event.activityData ?? SocialActivityData(
                activityType: .otherOutdoor,
                distanceMeters: 0,
                durationSeconds: 0,
                xpEarned: event.xpEarned ?? 0,
                newZonesCount: 0
            )
            
            let user = SocialUser(
                id: userId,
                displayName: userName,
                avatarURL: event.userAvatarURL,
                level: event.userLevel ?? 1,
                isFollowing: followingIds.contains(userId)
            )
            
            return SocialPost(
                id: UUID(uuidString: event.id ?? "") ?? UUID(),
                userId: userId,
                user: user,
                date: event.date,
                activityData: finalActivityData
            )
        }
        .sorted(by: { $0.date > $1.date })
    }
    
    // MARK: - Follow System
    
    func followUser(userId: String) {
        followingIds.insert(userId)
        saveFollowingState()
        // In a real app, this would trigger a backend call
    }
    
    func unfollowUser(userId: String) {
        followingIds.remove(userId)
        saveFollowingState()
        // In a real app, this would trigger a backend call
    }
    
    func isFollowing(userId: String) -> Bool {
        return followingIds.contains(userId)
    }
    
    private func saveFollowingState() {
        // Simple persistence using UserDefaults for MVP
        UserDefaults.standard.set(Array(followingIds), forKey: "Social_FollowingIds")
    }
    
    private func loadFollowingState() {
        if let savedIds = UserDefaults.standard.array(forKey: "Social_FollowingIds") as? [String] {
            followingIds = Set(savedIds)
        }
    }
    
    // MARK: - Feed System
    
    // MARK: - Feed System
    
    // Posts are now exposed via @Published var posts
    
    func createPost(from activity: ActivitySession) {
        guard let userId = AuthenticationService.shared.userId,
              let userName = AuthenticationService.shared.userName else { return }
        
        let activityData = SocialActivityData(
            activityType: activity.activityType,
            distanceMeters: activity.distanceMeters,
            durationSeconds: activity.durationSeconds,
            xpEarned: activity.xpBreakdown?.total ?? 0,
            newZonesCount: activity.territoryStats?.newCellsCount ?? 0
        )
        
        // Create FeedEvent
        let event = FeedEvent(
            id: nil, // Firestore will assign ID
            type: .weeklySummary, // Using generic type for now, or add .activity
            date: activity.endDate,
            title: "Activity Completed",
            subtitle: nil,
            xpEarned: activity.xpBreakdown?.total,
            userId: userId,
            relatedUserName: userName,
            userLevel: GamificationService.shared.currentLevel,
            userAvatarURL: nil, // TODO: Get from profile
            miniMapRegion: nil, // Could add if available
            badgeName: nil,
            badgeRarity: nil,
            activityData: activityData,
            rarity: nil,
            isPersonal: false
        )
        
        feedRepository.postEvent(event)
    }
    
    // MARK: - Mock Data
    // Removed mock data generation
}

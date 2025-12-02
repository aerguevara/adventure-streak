import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
class SocialService: ObservableObject {
    static let shared = SocialService()
    
    @Published var followingIds: Set<String> = []
    @Published var posts: [SocialPost] = []
    
    private let feedRepository = FeedRepository.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Dependencies
    private var db: Any?
    #if canImport(FirebaseFirestore)
    private var listenerRegistration: ListenerRegistration?
    #else
    private var listenerRegistration: Any?
    #endif
    
    private init() {
        #if canImport(FirebaseFirestore)
        db = Firestore.firestore()
        #endif
        
        // Load persisted following state
        startObservingFollowing() // Changed to startObservingFollowing()
        
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
        guard let currentUserId = AuthenticationService.shared.userId else { return }
        
        // Optimistic update
        followingIds.insert(userId)
        
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        let data: [String: Any] = [
            "followedAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("users").document(currentUserId)
            .collection("following").document(userId)
            .setData(data) { error in
                if let error = error {
                    print("Error following user: \(error)")
                    // Rollback on error
                    DispatchQueue.main.async {
                        self.followingIds.remove(userId)
                    }
                }
            }
        #endif
    }
    
    func unfollowUser(userId: String) {
        guard let currentUserId = AuthenticationService.shared.userId else { return }
        
        // Optimistic update
        followingIds.remove(userId)
        
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        db.collection("users").document(currentUserId)
            .collection("following").document(userId)
            .delete { error in
                if let error = error {
                    print("Error unfollowing user: \(error)")
                    // Rollback on error
                    DispatchQueue.main.async {
                        self.followingIds.insert(userId)
                    }
                }
            }
        #endif
    }
    
    func isFollowing(userId: String) -> Bool {
        return followingIds.contains(userId)
    }
    
    func clear() {
        posts = []
        followingIds = []
        listenerRegistration?.remove() // Removed old UserDefaults clear, added listener removal
        listenerRegistration = nil
    }
    
    func startObserving() {
        feedRepository.observeFeed()
        startObservingFollowing() // Added call to start observing following
    }
    
    private func startObservingFollowing() {
        guard let currentUserId = AuthenticationService.shared.userId else { return }
        
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        listenerRegistration?.remove() // Remove any existing listener
        
        listenerRegistration = db.collection("users").document(currentUserId)
            .collection("following")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching following list: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let ids = documents.map { $0.documentID }
                self?.followingIds = Set(ids)
            }
        #endif
    }
    
    // MARK: - Feed System
    
    // MARK: - Feed System
    
    // Posts are now exposed via @Published var posts
    
    func createPost(from activity: ActivitySession) {
        guard let userId = AuthenticationService.shared.userId else { return }
        let userName = AuthenticationService.shared.resolvedUserName()
        
        let activityData = SocialActivityData(
            activityType: activity.activityType,
            distanceMeters: activity.distanceMeters,
            durationSeconds: activity.durationSeconds,
            xpEarned: activity.xpBreakdown?.total ?? 0,
            newZonesCount: activity.territoryStats?.newCellsCount ?? 0
        )
        
        // Create FeedEvent
        let event = FeedEvent(
            id: "activity-\(activity.id.uuidString)-social",
            type: .weeklySummary, // Using generic type for now, or add .activity
            date: activity.endDate,
            activityId: activity.id,
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

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
    private var avatarCache: [String: URL] = [:]
    private let avatarDataCache = AvatarCacheManager.shared
    
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
        let currentUserId = AuthenticationService.shared.userId
        let allowedIds: Set<String> = {
            var set = followingIds
            if let current = currentUserId {
                set.insert(current)
            }
            return set
        }()
        
        var missingAvatarIds: Set<String> = []
        
        self.posts = events.compactMap { event -> SocialPost? in
            guard let userId = event.userId,
                  let userName = event.relatedUserName else {
                return nil
            }

            // Solo mostrar posts de seguidos (y el propio)
            if !allowedIds.contains(userId) {
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
            
            let avatarURL: URL? = {
                if let provided = event.userAvatarURL {
                    avatarCache[userId] = provided
                    return provided
                }
                if let cached = avatarCache[userId] {
                    return cached
                }
                missingAvatarIds.insert(userId)
                return nil
            }()
            
            let avatarData = avatarDataCache.data(for: userId)
            
            let user = SocialUser(
                id: userId,
                displayName: userName,
                avatarURL: avatarURL,
                avatarData: avatarData,
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
        
        // Evita flasheos si la lista es idéntica
        if newPosts == self.posts {
            return
        }
        
        self.posts = newPosts
        
        if !missingAvatarIds.isEmpty {
            Task {
                await fetchAvatars(for: missingAvatarIds)
                await MainActor.run {
                    self.updatePosts(from: events)
                }
            }
        }
    }
    
    // MARK: - Follow System
    
    func followUser(userId: String, displayName: String? = nil) {
        guard let currentUserId = AuthenticationService.shared.userId else { return }
        
        // Optimistic update
        followingIds.insert(userId)
        
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        let now = FieldValue.serverTimestamp()
        
        Task {
            let currentName = await resolveCurrentUserName()
            var targetName = displayName ?? "Usuario"
            var targetAvatarURL: String? = nil
            var followerAvatarURL: String? = nil
            
            do {
                let targetDoc = try await db.collection("users").document(userId).getDocument()
                if let remoteName = targetDoc.get("displayName") as? String, !remoteName.isEmpty {
                    targetName = remoteName
                }
                targetAvatarURL = targetDoc.get("avatarURL") as? String
            } catch {
                print("Error fetching target user for follow: \(error)")
            }
            
            do {
                let currentDoc = try await db.collection("users").document(currentUserId).getDocument()
                followerAvatarURL = currentDoc.get("avatarURL") as? String
            } catch {
                print("Error fetching current user avatar for follow: \(error)")
            }
            
            let followingData: [String: Any?] = [
                "followedAt": now,
                "displayName": targetName,
                "avatarURL": targetAvatarURL
            ]
            
            let followerData: [String: Any?] = [
                "followedAt": now,
                "displayName": currentName,
                "avatarURL": followerAvatarURL
            ]
            
            do {
                try await db.collection("users").document(currentUserId)
                    .collection("following").document(userId)
                    .setData(followingData.compactMapValues { $0 })
                
                try await db.collection("users").document(userId)
                    .collection("followers").document(currentUserId)
                    .setData(followerData.compactMapValues { $0 })
            } catch {
                print("Error following user: \(error)")
                self.followingIds.remove(userId)
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
        
        db.collection("users").document(userId)
            .collection("followers").document(currentUserId)
            .delete { error in
                if let error = error {
                    print("Error removing follower: \(error)")
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
    
    // MARK: - Relations fetchers
    #if canImport(FirebaseFirestore)
    func fetchFollowing(for userId: String) async -> [SocialUser] {
        guard let db = db as? Firestore else { return [] }
        do {
            let snapshot = try await db.collection("users").document(userId).collection("following").getDocuments()
            var users: [SocialUser] = []
            for doc in snapshot.documents {
                let name = (doc.get("displayName") as? String) ?? "Usuario"
                let avatar = (doc.get("avatarURL") as? String).flatMap(URL.init(string:))
                if let avatar {
                    avatarCache[doc.documentID] = avatar
                }
                var data = avatarDataCache.data(for: doc.documentID)
                if data == nil, let avatar {
                    if let (download, _) = try? await URLSession.shared.data(from: avatar) {
                        avatarDataCache.save(data: download, for: doc.documentID)
                        data = download
                    }
                }
                let user = SocialUser(id: doc.documentID, displayName: name, avatarURL: avatar, avatarData: data, level: 0, isFollowing: followingIds.contains(doc.documentID))
                users.append(user)
            }
            return users
        } catch {
            print("Error fetching following: \(error)")
            return []
        }
    }
    
    func fetchFollowers(for userId: String) async -> [SocialUser] {
        guard let db = db as? Firestore else { return [] }
        do {
            let snapshot = try await db.collection("users").document(userId).collection("followers").getDocuments()
            var users: [SocialUser] = []
            for doc in snapshot.documents {
                let name = (doc.get("displayName") as? String) ?? "Usuario"
                let avatar = (doc.get("avatarURL") as? String).flatMap(URL.init(string:))
                if let avatar {
                    avatarCache[doc.documentID] = avatar
                }
                var data = avatarDataCache.data(for: doc.documentID)
                if data == nil, let avatar {
                    if let (download, _) = try? await URLSession.shared.data(from: avatar) {
                        avatarDataCache.save(data: download, for: doc.documentID)
                        data = download
                    }
                }
                let user = SocialUser(id: doc.documentID, displayName: name, avatarURL: avatar, avatarData: data, level: 0, isFollowing: followingIds.contains(doc.documentID))
                users.append(user)
            }
            return users
        } catch {
            print("Error fetching followers: \(error)")
            return []
        }
    }
    #endif

    private func resolveCurrentUserName() async -> String {
        let auth = AuthenticationService.shared
        let emailPrefix = auth.userEmail?
            .split(separator: "@")
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // Si el nombre actual existe y es distinto al prefijo del correo, úsalo
        if let name = auth.userName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty,
           name != emailPrefix {
            return name
        }
        
        // Intentar obtener displayName desde Firestore (perfil remoto)
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore, let currentUserId = auth.userId else {
            let fallback = !emailPrefix.isEmpty ? emailPrefix : "Aventurero"
            return fallback
        }
        
        do {
            let snapshot = try await db.collection("users").document(currentUserId).getDocument()
            if let remoteName = snapshot.get("displayName") as? String,
               !remoteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return remoteName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if !emailPrefix.isEmpty { return emailPrefix }
            return "Aventurero"
        } catch {
            if !emailPrefix.isEmpty { return emailPrefix }
            return "Aventurero"
        }
        #else
        let fallback = !emailPrefix.isEmpty ? emailPrefix : "Aventurero"
        return fallback
        #endif
    }
    
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
    
    @MainActor
    func fetchAvatars(for userIds: Set<String>) async {
        guard !userIds.isEmpty else { return }
        guard let db = db as? Firestore else { return }
        
        for userId in userIds {
            do {
                let doc = try await db.collection("users").document(userId).getDocument()
                if let urlString = doc.get("avatarURL") as? String,
                   let url = URL(string: urlString) {
                    avatarCache[userId] = url
                    // Download and cache data
                    let (data, _) = try await URLSession.shared.data(from: url)
                    avatarDataCache.save(data: data, for: userId)
                }
            } catch {
                print("Error fetching avatar for \(userId): \(error)")
            }
        }
    }
    
    func updateAvatar(for userId: String, url: URL, data: Data) {
        avatarCache[userId] = url
        avatarDataCache.save(data: data, for: userId)
        
        posts = posts.map { post in
            if post.userId == userId {
                let updatedUser = SocialUser(
                    id: post.user.id,
                    displayName: post.user.displayName,
                    avatarURL: url,
                    avatarData: data,
                    level: post.user.level,
                    isFollowing: post.user.isFollowing
                )
                return SocialPost(
                    id: post.id,
                    userId: post.userId,
                    user: updatedUser,
                    date: post.date,
                    activityData: post.activityData
                )
            }
            return post
        }
    }
    
    // MARK: - Mock Data
    // Removed mock data generation
}

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
    nonisolated static let shared = SocialService()
    
    @Published var followingIds: Set<String> = []
    @Published var posts: [SocialPost] = []
    private var avatarCache: [String: URL] = [:]
    private let avatarDataCache = AvatarCacheManager.shared
    private var noAvatarIds: Set<String> = []
    
    private let feedRepository = FeedRepository.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Dependencies
    nonisolated private let db: Any? = {
        #if canImport(FirebaseFirestore)
        return Firestore.shared
        #else
        return nil
        #endif
    }()
    
    #if canImport(FirebaseFirestore)
    private var listenerRegistration: ListenerRegistration?
    #else
    private var listenerRegistration: Any?
    #endif
    
    nonisolated private init() {
        Task {
            await MainActor.run {
                // Load persisted following state
                self.startObservingFollowing()
                
                // Start observing feed
                self.feedRepository.observeFeed()
                
                // Subscribe to repository updates
                self.feedRepository.$events
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] events in
                        self?.updatePosts(from: events)
                    }
                    .store(in: &self.cancellables)
                
                // Also update when following changes
                self.$followingIds
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] _ in
                        self?.updatePosts(from: self?.feedRepository.events ?? [])
                    }
                    .store(in: &self.cancellables)
                    
                // NEW: React to manual sync/reset notification
                NotificationCenter.default.publisher(for: NSNotification.Name("TriggerImmediateImport"))
                    .receive(on: RunLoop.main)
                    .sink { [weak self] _ in
                        guard let self = self else { return }
                        print("📣 SocialService: TriggerImmediateImport received, restarting observers...")
                        self.startObservingFollowing()
                        self.feedRepository.observeFeed()
                    }
                    .store(in: &self.cancellables)

                // NEW: React to login/logout
                AuthenticationService.shared.$userId
                    .receive(on: RunLoop.main)
                    .sink { [weak self] userId in
                        guard let self = self else { return }
                        if userId != nil {
                            print("SocialService: userId found, restarting observers...")
                            self.startObservingFollowing()
                            self.feedRepository.observeFeed()
                        } else {
                            print("SocialService: user logged out, clearing state")
                            self.followingIds.removeAll()
                            self.posts.removeAll()
                            self.feedRepository.clear()
                        }
                    }
                    .store(in: &self.cancellables)
            }
        }
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
        // Mostrar todo si aún no tenemos lista de seguidos (evita feed vacío en primer arranque)
        let allowAll = followingIds.isEmpty
        
        var missingAvatarIds: Set<String> = []
        
        let newPosts = events.compactMap { event -> SocialPost? in
            guard let userId = event.userId,
                  let userName = event.relatedUserName else {
                return nil
            }

            // Solo mostrar posts de seguidos (y el propio)
            if !allowAll && !allowedIds.contains(userId) {
                return nil
            }
            
            // Fallback for legacy events without activityData
            let finalActivityData = event.activityData ?? SocialActivityData(
                activityType: .otherOutdoor,
                distanceMeters: 0,
                durationSeconds: 0,
                xpEarned: event.xpEarned ?? 0,
                newZonesCount: 0,
                defendedZonesCount: 0,
                recapturedZonesCount: 0,
                stolenZonesCount: 0,
                swordCount: 0,
                shieldCount: 0,
                fireCount: 0,
                currentUserReaction: nil,
                locationLabel: nil, // Fallback
                calories: 0,
                averageHeartRate: 0
            )
            
            let avatarURL: URL? = {
                if let provided = event.userAvatarURL {
                    if let existing = avatarCache[userId], existing.absoluteString != provided.absoluteString {
                        // URL changed, clear cache
                        AvatarCacheManager.shared.clear(for: userId)
                    }
                    avatarCache[userId] = provided
                    return provided
                }
                if let cached = avatarCache[userId] {
                    return cached
                }
                if !noAvatarIds.contains(userId) {
                    missingAvatarIds.insert(userId)
                }
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
                id: event.id,
                userId: userId,
                user: user,
                date: event.date,
                activityId: event.activityId,
                activityData: finalActivityData,
                eventType: event.type,
                eventTitle: event.title,
                eventSubtitle: event.subtitle,
                rarity: event.rarity,
                miniMapRegion: event.miniMapRegion
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
                
                // Create Notification for the followed user
                let notificationRef = db.collection("notifications").document()
                let notificationData: [String: Any] = [
                    "recipientId": userId,
                    "senderId": currentUserId,
                    "senderName": currentName,
                    "senderAvatarURL": followerAvatarURL ?? "",
                    "type": "follow",
                    "timestamp": now,
                    "isRead": false
                ]
                try await notificationRef.setData(notificationData.compactMapValues { 
                    if let s = $0 as? String, s.isEmpty { return nil }
                    return $0
                })
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
    
    func refreshFeed() async {
        await feedRepository.fetchLatest()
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
    

    
    @MainActor
    func fetchAvatars(for userIds: Set<String>) async {
        guard !userIds.isEmpty else { return }
        guard let db = db as? Firestore else { return }
        
        let idsArray = Array(userIds)
        // Firestore 'in' query supports up to 10 elements (up to 30 in some versions, but 10 is safest/standard for older SDKs, actually up to 30 in modern ones).
        // Let's use chunks of 10 for maximum compatibility.
        let chunks = idsArray.chunked(into: 10)
        
        for chunk in chunks {
            do {
                let snapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                
                for doc in snapshot.documents {
                    let userId = doc.documentID
                    if let urlString = doc.get("avatarURL") as? String,
                       let url = URL(string: urlString) {
                        avatarCache[userId] = url
                        // Download and cache data asynchronously
                        Task.detached(priority: .background) {
                            if let (data, _) = try? await URLSession.shared.data(from: url) {
                                await MainActor.run {
                                    AvatarCacheManager.shared.save(data: data, for: userId)
                                    // Optionally trigger a refresh if needed, but updatePosts will handle it next time
                                }
                            }
                        }
                    } else {
                        noAvatarIds.insert(userId)
                    }
                }
                
                // Mark IDs not found as noAvatar to avoid re-fetching
                let foundIds = Set(snapshot.documents.map { $0.documentID })
                for id in chunk {
                    if !foundIds.contains(id) {
                        noAvatarIds.insert(id)
                    }
                }
            } catch {
                print("❌ [SocialService] Error batch fetching avatars: \(error)")
                chunk.forEach { noAvatarIds.insert($0) }
            }
        }
    }

    @MainActor
    func updateAvatar(for userId: String, url: URL, data: Data) {
        avatarCache[userId] = url
        AvatarCacheManager.shared.save(data: data, for: userId)
        noAvatarIds.remove(userId)
        
        // Trigger a re-calculation of posts to reflect the new avatar
        self.updatePosts(from: self.feedRepository.events)
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

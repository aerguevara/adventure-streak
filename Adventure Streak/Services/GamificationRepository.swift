import Foundation
// NEW: Added for multiplayer conquest feature
#if canImport(FirebaseFirestore)
@preconcurrency import FirebaseFirestore
#endif

@MainActor
class GamificationRepository: ObservableObject {
    nonisolated static let shared = GamificationRepository()
    
    nonisolated private let db: Any? = {
        #if canImport(FirebaseFirestore)
        return Firestore.shared
        #else
        return nil
        #endif
    }()
    
    nonisolated init() {}
    
    // NEW: Update user XP and Level
    func updateUserStats(userId: String, xp: Int, level: Int) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        let data: [String: Any] = [
            "xp": xp,
            "level": level,
            "lastUpdated": FieldValue.serverTimestamp()
        ]
        
        db.collection("users").document(userId).setData(data, merge: true)
        #endif
    }
    
    // NEW: Award a badge to the user
    func awardBadge(userId: String, badgeId: String) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        let badgeData: [String: Any] = [
            "badgeId": badgeId,
            "awardedAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("users").document(userId).collection("badges").addDocument(data: badgeData)
        
        // Create Notification for the badge
        createNotification(recipientId: userId, type: "achievement", badgeId: badgeId)
        #endif
    }
    
    // NEW: Generic notification creation
    func createNotification(recipientId: String, type: String, badgeId: String? = nil) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        let notificationData: [String: Any?] = [
            "recipientId": recipientId,
            "senderId": "system",
            "senderName": "Adventure Streak",
            "type": type,
            "badgeId": badgeId,
            "timestamp": FieldValue.serverTimestamp(),
            "isRead": false
        ]
        db.collection("notifications").addDocument(data: notificationData.compactMapValues { $0 })
        #endif
    }
    // NEW: Fetch all badges with their unlocked status for a user
    func fetchBadges(userId: String, completion: @escaping ([Badge]) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else {
            completion([])
            return
        }
        
        // 1. Fetch User Doc to get "badges" array
        db.collection("users").document(userId).getDocument { (snapshot, error) in
            let userData = snapshot?.data() ?? [:]
            let unlockedIds = Set(userData["badges"] as? [String] ?? [])
            
            // 2. Generate Badge List from BadgeSystem definitions
            var allBadges: [Badge] = []
            
            // Iterate over all definitions in BadgeSystem
            for (_, def) in BadgeSystem.definitions {
                
                // Determine Category based on ID (simple heuristic or need to add category to BadgeDefinition)
                var cat: BadgeCategory = .training
                let id = def.id
                if ["shadow_hunter", "chaos_lord", "takeover", "reconquest_king", "uninvited", "streak_breaker", "white_glove", "lightning_counter", "summit_looter"].contains(id) {
                    cat = .aggressive
                } else if ["steel_influencer", "war_correspondent", "sports_spirit", "community_voice", "trust_circle"].contains(id) {
                    cat = .social
                }
                
                let badge = Badge(
                    id: def.id,
                    name: def.name,
                    shortDescription: def.description, // Mapping description
                    longDescription: def.description,   // Mapping description
                    isUnlocked: unlockedIds.contains(def.id),
                    unlockedAt: nil, // Timestamp not stored in array, assume recent if needed
                    iconSystemName: def.icon, // Using the emoji/icon string here. View must handle it.
                    category: cat
                )
                
                allBadges.append(badge)
            }
            
            // Sort: Unlocked first, then by name? Or by category?
            // Let's sort by Category then Name.
            // But 'aggressive' vs 'social' order?
            // For now just consistent sort by ID or Name.
            allBadges.sort { $0.isUnlocked && !$1.isUnlocked } 
            
            completion(allBadges)
        }
        #else
        completion([])
        #endif
    }
    // NEW: Fetch weekly ranking (One-shot)
    func fetchWeeklyRanking(limit: Int, completion: @escaping ([RankingEntry]) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else {
            completion([])
            return
        }
        
        db.collection("users")
            .order(by: "xp", descending: true)
            .limit(to: limit)
            .getDocuments { (snapshot, error) in
                if let documents = snapshot?.documents {
                    Task { @MainActor in
                        let entries = self.processRankingDocuments(documents)
                        completion(entries)
                    }
                } else {
                    print("Error fetching ranking: \(String(describing: error))")
                    completion([])
                }
            }
        #else
        completion([])
        #endif
    }
    
    // NEW: Observe weekly ranking (Real-time)
    func observeWeeklyRanking(limit: Int, completion: @escaping ([RankingEntry]) -> Void) -> ListenerRegistration? {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else {
            completion([])
            return nil
        }
        
        return db.collection("users")
            .order(by: "xp", descending: true)
            .limit(to: limit)
            .addSnapshotListener { (snapshot, error) in
                if let documents = snapshot?.documents {
                    Task { @MainActor in
                        let entries = self.processRankingDocuments(documents)
                        completion(entries)
                    }
                } else if let error = error {
                    print("Error observing ranking: \(error.localizedDescription)")
                }
            }
        #else
        completion([])
        return nil
        #endif
    }
    
    #if canImport(FirebaseFirestore)
    private func processRankingDocuments(_ documents: [QueryDocumentSnapshot]) -> [RankingEntry] {
        var entries: [RankingEntry] = []
        for (index, doc) in documents.enumerated() {
            let data = doc.data()
            let currentRank = index + 1
            let previousRank = data["previousRank"] as? Int ?? 0
            var trend: RankingTrend = .neutral
            
            if previousRank > 0 {
                if currentRank < previousRank {
                    trend = .up
                } else if currentRank > previousRank {
                    trend = .down
                }
            }
            
            var entry = RankingEntry(
                userId: doc.documentID,
                displayName: data["displayName"] as? String ?? "Unknown",
                level: data["level"] as? Int ?? 1,
                weeklyXP: data["xp"] as? Int ?? 0,
                position: currentRank,
                isCurrentUser: false
            )
            entry.weeklyDistance = data["currentWeekDistanceKm"] as? Double ?? 0.0
            entry.trend = trend
            entries.append(entry)
        }
        return entries
    }
    #endif
    // NEW: Build context for XP calculation
    func buildXPContext(for userId: String) async throws -> XPContext {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else {
            // Fallback for preview/testing
            return XPContext(userId: userId, currentWeekDistanceKm: 0, bestWeeklyDistanceKm: nil, currentStreakWeeks: 0, todayBaseXPEarned: 0, gamificationState: GamificationState(totalXP: 0, level: 1, currentStreakWeeks: 0))
        }
        
        // 1. Fetch User Stats
        let userDoc = try await db.collection("users").document(userId).getDocument()
        let data = userDoc.data() ?? [:]
        
        let totalXP = data["xp"] as? Int ?? 0
        let level = data["level"] as? Int ?? 1
        let streak = data["currentStreakWeeks"] as? Int ?? 0
        
        // 2. Fetch Weekly Stats (Mocked for MVP, ideally from a separate collection)
        // In a real app, we would query ActivityRepository for this week's activities
        let currentWeekDist = data["currentWeekDistanceKm"] as? Double ?? 0.0
        let bestWeekDist = data["bestWeeklyDistanceKm"] as? Double
        
        // 3. Fetch Today's XP (Mocked)
        let todayXP = 0 // TODO: Query activities from today and sum base XP
        
        let state = GamificationState(totalXP: totalXP, level: level, currentStreakWeeks: streak)
        
        return XPContext(
            userId: userId,
            currentWeekDistanceKm: currentWeekDist,
            bestWeeklyDistanceKm: bestWeekDist,
            currentStreakWeeks: streak,
            todayBaseXPEarned: todayXP,
            gamificationState: state
        )
        #else
        return XPContext(userId: userId, currentWeekDistanceKm: 0, bestWeeklyDistanceKm: nil, currentStreakWeeks: 0, todayBaseXPEarned: 0, gamificationState: GamificationState(totalXP: 0, level: 1, currentStreakWeeks: 0))
        #endif
    }
    
    // NEW: Search users by display name
    func searchUsers(query: String, completion: @escaping ([RankingEntry]) -> Void) {
        guard !query.isEmpty else {
            completion([])
            return
        }
        
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else {
            completion([])
            return
        }
        
        // Firestore prefix search using range query
        let endQuery = query + "\u{f8ff}"
        
        db.collection("users")
            .whereField("displayName", isGreaterThanOrEqualTo: query)
            .whereField("displayName", isLessThanOrEqualTo: endQuery)
            .limit(to: 20)
            .getDocuments { (snapshot, error) in
                if let documents = snapshot?.documents {
                    let entries = documents.map { doc -> RankingEntry in
                        let data = doc.data()
                        var entry = RankingEntry(
                            userId: doc.documentID,
                            displayName: data["displayName"] as? String ?? "Unknown",
                            level: data["level"] as? Int ?? 1,
                            weeklyXP: data["xp"] as? Int ?? 0,
                            position: 0, // Not applicable for search
                            isCurrentUser: false
                        )
                        entry.weeklyDistance = data["currentWeekDistanceKm"] as? Double ?? 0.0
                        entry.totalDistance = data["totalDistanceKm"] as? Double ?? 0.0
                        entry.totalDistanceNoGps = data["totalDistanceNoGpsKm"] as? Double ?? 0.0
                        return entry
                    }
                    completion(entries)
                } else {
                    print("Error searching users: \(String(describing: error))")
                    completion([])
                }
            }
        #else
        completion([])
        #endif
    }
    
    // NEW: Snapshot current rankings to history (Simulating Backend Job)
    func snapshotRankings(completion: @escaping (Bool) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else {
            completion(false)
            return
        }
        
        // Fetch all users ordered by XP to determine current rank
        db.collection("users")
            .order(by: "xp", descending: true)
            .getDocuments { (snapshot, error) in
                guard let documents = snapshot?.documents else {
                    print("Error fetching users for snapshot: \(String(describing: error))")
                    completion(false)
                    return
                }
                
                guard let db = self.db as? Firestore else { return }
                let batch = db.batch()
                
                for (index, doc) in documents.enumerated() {
                    let currentRank = index + 1
                    let ref = db.collection("users").document(doc.documentID)
                    // Update previousRank with the current rank
                    batch.updateData(["previousRank": currentRank], forDocument: ref)
                }
                
                batch.commit { error in
                    if let error = error {
                        print("Error committing ranking snapshot: \(error)")
                        completion(false)
                    } else {
                        print("Successfully snapshotted rankings for \(documents.count) users.")
                        completion(true)
                    }
                }
            }
        #else
        completion(false)
        #endif
    }
}

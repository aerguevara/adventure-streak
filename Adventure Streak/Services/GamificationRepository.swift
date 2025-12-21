import Foundation
// NEW: Added for multiplayer conquest feature
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class GamificationRepository: ObservableObject {
    nonisolated static let shared = GamificationRepository()
    
    nonisolated private let db: Any? = {
        #if canImport(FirebaseFirestore)
        return Firestore.firestore()
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
        // 1. Define all available badges (Static Definitions)
        var allBadges = [
            Badge.definition(id: "first_steps", name: "First Steps", shortDescription: "Complete your first activity", longDescription: "Awarded for completing your very first activity tracking session.", icon: "figure.walk", category: .activity),
            Badge.definition(id: "week_streak", name: "On Fire", shortDescription: "Maintain a 1-week streak", longDescription: "Awarded for maintaining your adventure streak for 7 consecutive days.", icon: "flame.fill", category: .streak),
            Badge.definition(id: "explorer_novice", name: "Novice Explorer", shortDescription: "Conquer 10 territory cells", longDescription: "Awarded for conquering a total of 10 unique territory cells.", icon: "map.fill", category: .territory),
            Badge.definition(id: "marathoner", name: "Marathoner", shortDescription: "Travel 42km total", longDescription: "Awarded for accumulating 42 kilometers of total distance traveled.", icon: "figure.run", category: .distance),
            Badge.definition(id: "defensor", name: "Defender", shortDescription: "Recapture a lost territory", longDescription: "Awarded for recapturing a territory that was taken by another player.", icon: "shield.fill", category: .territory)
        ]
        
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else {
            completion(allBadges)
            return
        }
        
        // 2. Fetch unlocked badges from Firestore
        db.collection("users").document(userId).collection("badges").getDocuments { (snapshot, error) in
            if let documents = snapshot?.documents {
                let unlockedIds = Set(documents.compactMap { $0.data()["badgeId"] as? String })
                
                // 3. Merge status
                for i in 0..<allBadges.count {
                    if unlockedIds.contains(allBadges[i].id) {
                        allBadges[i].isUnlocked = true
                        // Ideally we would fetch the timestamp too, but for MVP just marking true is enough
                        // or we could map it from the document if we needed the date
                    }
                }
            }
            completion(allBadges)
        }
        #else
        // Fallback for no Firestore
        completion(allBadges)
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
                    let entries = self.processRankingDocuments(documents)
                    completion(entries)
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
                    let entries = self.processRankingDocuments(documents)
                    completion(entries)
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
                        return RankingEntry(
                            userId: doc.documentID,
                            displayName: data["displayName"] as? String ?? "Unknown",
                            level: data["level"] as? Int ?? 1,
                            weeklyXP: data["xp"] as? Int ?? 0,
                            position: 0, // Not applicable for search
                            isCurrentUser: false
                        )
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

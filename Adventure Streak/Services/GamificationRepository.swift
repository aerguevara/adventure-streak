import Foundation
// NEW: Added for multiplayer conquest feature
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

class GamificationRepository: ObservableObject {
    static let shared = GamificationRepository()
    
    private var db: Any?
    
    init() {
        #if canImport(FirebaseFirestore)
        db = Firestore.firestore()
        #endif
    }
    
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
    // NEW: Fetch weekly ranking
    func fetchWeeklyRanking(limit: Int, completion: @escaping ([RankingEntry]) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else {
            completion([])
            return
        }
        
        // For MVP, we'll query users ordered by XP descending.
        // Ideally, we'd have a separate 'weeklyXP' field reset periodically or a separate collection.
        // For this MVP, we will use total 'xp' as a proxy for ranking, or 'weeklyXP' if it existed.
        // Let's assume we query 'xp' for now to show something working.
        
        db.collection("users")
            .order(by: "xp", descending: true)
            .limit(to: limit)
            .getDocuments { (snapshot, error) in
                if let documents = snapshot?.documents {
                    var entries: [RankingEntry] = []
                    for (index, doc) in documents.enumerated() {
                        let data = doc.data()
                        let entry = RankingEntry(
                            userId: doc.documentID,
                            displayName: data["displayName"] as? String ?? "Unknown",
                            level: data["level"] as? Int ?? 1,
                            weeklyXP: data["xp"] as? Int ?? 0, // Using total XP as proxy for MVP
                            position: index + 1,
                            isCurrentUser: false // Will be set by ViewModel
                        )
                        entries.append(entry)
                    }
                    completion(entries)
                } else {
                    print("Error fetching ranking: \(String(describing: error))")
                    completion([])
                }
            }
        #else
        // Fallback for no Firestore
        completion([])
        #endif
    }
}

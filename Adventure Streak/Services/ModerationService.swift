import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
class ModerationService: ObservableObject {
    static let shared = ModerationService()
    
    @Published private(set) var blockedUserIds: Set<String> = []
    
    private var db: Any? {
        #if canImport(FirebaseFirestore)
        return Firestore.shared
        #else
        return nil
        #endif
    }
    
    private init() {
        loadBlockedUsersLocally()
    }
    
    // MARK: - Blocking Logic
    
    func blockUser(userId: String) {
        guard !userId.isEmpty else { return }
        blockedUserIds.insert(userId)
        saveBlockedUsersLocally()
        
        #if canImport(FirebaseFirestore)
        if let db = db as? Firestore, let currentUserId = Auth.auth().currentUser?.uid {
            let userRef = db.collection("users").document(currentUserId)
            userRef.updateData([
                "blockedUsers": FieldValue.arrayUnion([userId])
            ])
        }
        #endif
        
        print("[Moderation] User \(userId) blocked.")
        NotificationCenter.default.post(name: NSNotification.Name("UserBlockedStatusChanged"), object: nil)
    }
    
    func unblockUser(userId: String) {
        blockedUserIds.remove(userId)
        saveBlockedUsersLocally()
        
        #if canImport(FirebaseFirestore)
        if let db = db as? Firestore, let currentUserId = Auth.auth().currentUser?.uid {
            let userRef = db.collection("users").document(currentUserId)
            userRef.updateData([
                "blockedUsers": FieldValue.arrayRemove([userId])
            ])
        }
        #endif
        
        print("[Moderation] User \(userId) unblocked.")
        NotificationCenter.default.post(name: NSNotification.Name("UserBlockedStatusChanged"), object: nil)
    }
    
    func isBlocked(userId: String) -> Bool {
        return blockedUserIds.contains(userId)
    }
    
    func syncBlockedUsers(from remoteIds: [String]) {
        self.blockedUserIds = Set(remoteIds)
        saveBlockedUsersLocally()
    }
    
    // MARK: - Reporting Logic
    
    func reportUser(userId: String, reason: String, context: String? = nil) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        let currentUserId = Auth.auth().currentUser?.uid ?? "anonymous"
        
        let reportData: [String: Any] = [
            "reporterId": currentUserId,
            "reportedId": userId,
            "reason": reason,
            "context": context ?? "",
            "timestamp": FieldValue.serverTimestamp(),
            "status": "pending"
        ]
        
        db.collection("reports").addDocument(data: reportData) { error in
            if let error = error {
                print("[Moderation] Error sending report: \(error.localizedDescription)")
            } else {
                print("[Moderation] User \(userId) reported for: \(reason)")
            }
        }
        #endif
    }
    
    // MARK: - Persistence (Local fallback for faster UI)
    
    private func saveBlockedUsersLocally() {
        UserDefaults.standard.set(Array(blockedUserIds), forKey: "blocked_users_cache")
    }
    
    private func loadBlockedUsersLocally() {
        if let saved = UserDefaults.standard.stringArray(forKey: "blocked_users_cache") {
            self.blockedUserIds = Set(saved)
        }
    }
}

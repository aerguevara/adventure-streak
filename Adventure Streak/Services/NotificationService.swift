import Foundation
import UserNotifications
import Combine
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
class NotificationService: ObservableObject {
    nonisolated static let shared = NotificationService()
    
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    
    private let userDefaults = UserDefaults.standard
    private let cachedTokenKey = "fcm_cached_token"
    private let lastUploadedTokenBaseKey = "last_uploaded_fcm_token_"
    
    #if canImport(FirebaseFirestore)
    private var db = Firestore.shared
    private var listenerRegistration: ListenerRegistration?
    #endif
    
    nonisolated private init() {}
    
    // MARK: - In-App Notifications
    
    func startObserving() {
        guard let userId = AuthenticationService.shared.userId,
              Auth.auth().currentUser != nil else { return }
        
        #if canImport(FirebaseFirestore)
        listenerRegistration?.remove()
        
        listenerRegistration = db.collection("notifications")
            .whereField("recipientId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching notifications: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let fetched = documents.compactMap { doc -> AppNotification? in
                    try? doc.data(as: AppNotification.self)
                }
                
                self?.notifications = fetched
                self?.unreadCount = fetched.filter { !$0.isRead }.count
            }
        #endif
    }
    
    func markAsRead(_ notification: AppNotification) {
        guard let id = notification.id else { return }
        #if canImport(FirebaseFirestore)
        db.collection("notifications").document(id).setData(["isRead": true], merge: true)
        #endif
    }
    
    func markAllAsRead() {
        #if canImport(FirebaseFirestore)
        let batch = db.batch()
        for notification in notifications where !notification.isRead {
            if let id = notification.id {
                let ref = db.collection("notifications").document(id)
                batch.setData(["isRead": true], forDocument: ref, merge: true)
            }
        }
        batch.commit()
        #endif
    }
    
    // MARK: - Permissions & Push
    
    func requestPermissions(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permissions granted")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else if let error = error {
                print("Notification permissions error: \(error)")
            }
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }
    
    func notifyTerritoryAtRisk(cellId: String) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Territory at Risk!"
        content.body = "Your territory \(cellId) is about to expire. Go for a run to defend it!"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "risk_\(cellId)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func notifyTerritoryLost(cellId: String) {
        let content = UNMutableNotificationContent()
        content.title = "❌ Territory Lost"
        content.body = "You lost zone \(cellId). Reclaim it within 24h for a bonus!"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "lost_\(cellId)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleExpirationWarning(daysRemaining: Int) { }
    
    func cacheFCMToken(_ token: String) {
        userDefaults.set(token, forKey: cachedTokenKey)
    }
    
    private var cachedToken: String? {
        userDefaults.string(forKey: cachedTokenKey)
    }
    
    func handleNewFCMToken(_ token: String, userId: String?) {
        cacheFCMToken(token)
        guard let userId else { return }
        uploadActiveToken(token, for: userId)
    }
    
    func syncCachedFCMToken(for userId: String) {
        if let token = cachedToken {
            uploadActiveToken(token, for: userId)
            return
        }
        
        #if canImport(FirebaseMessaging)
        Messaging.messaging().token { [weak self] token, error in
            guard let token = token, error == nil else { return }
            Task { @MainActor in
                guard let self = self else { return }
                self.cacheFCMToken(token)
                self.uploadActiveToken(token, for: userId)
            }
        }
        #endif
    }
    
    func removeActiveToken(for userId: String) {
        guard let token = cachedToken else { return }
        UserRepository.shared.removeFCMToken(userId: userId, token: token)
    }
    
    func refreshFCMTokenIfNeeded(for userId: String) {
        #if canImport(FirebaseFirestore)
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { [weak self] snapshot, _ in
            guard let self else { return }
            let data = snapshot?.data() ?? [:]
            let needsRefresh = (data["needsTokenRefresh"] as? Bool) == true
            let existingToken: String = {
                if let str = data["fcmTokens"] as? String, !str.isEmpty { return str }
                if let arr = data["fcmTokens"] as? [String], let first = arr.first, !first.isEmpty { return first }
                return ""
            }()
            let missingTokens = existingToken.isEmpty
            
            guard needsRefresh || missingTokens else { return }
            
            #if canImport(FirebaseMessaging)
            Messaging.messaging().deleteToken { _ in
                Messaging.messaging().token { [weak self] token, error in
                    guard let token = token, error == nil else { return }
                    Task { @MainActor in
                        guard let self = self else { return }
                        self.cacheFCMToken(token)
                        self.uploadActiveToken(token, for: userId)
                        userRef.setData([
                            "needsTokenRefresh": false,
                            "needsTokenRefreshAt": FieldValue.delete()
                        ], merge: true)
                    }
                }
            }
            #endif
        }
        #endif
    }
    
    private func uploadActiveToken(_ token: String, for userId: String) {
        let lastKey = "\(lastUploadedTokenBaseKey)\(userId)"
        let lastToken = userDefaults.string(forKey: lastKey)
        
        if lastToken == token {
            print("ℹ️ [Notifications] FCM Token already synced for \(userId). Skipping redundant write.")
            return
        }
        
        print("🚀 [Notifications] FCM Token changed for \(userId). Updating server...")
        UserRepository.shared.updateFCMToken(userId: userId, token: token)
        
        // Optimistically update cache
        userDefaults.set(token, forKey: lastKey)
    }
    
    // MARK: - Notification Creation
    
    func createFirestoreNotification(
        recipientId: String,
        type: NotificationType,
        senderId: String = "system",
        senderName: String = "Adventure Streak",
        senderAvatarURL: String? = nil,
        reactionType: String? = nil,
        activityId: String? = nil,
        message: String? = nil,
        locationLabel: String? = nil
    ) {
        #if canImport(FirebaseFirestore)
        let notification = AppNotification(
            recipientId: recipientId,
            senderId: senderId,
            senderName: senderName,
            senderAvatarURL: senderAvatarURL,
            type: type,
            reactionType: reactionType,
            activityId: activityId,
            message: message,
            locationLabel: locationLabel,
            timestamp: Date(),
            isRead: false
        )
        
        do {
            _ = try db.collection("notifications").addDocument(from: notification)
        } catch {
            print("Error creating notification: \(error)")
        }
        #endif
    }
}

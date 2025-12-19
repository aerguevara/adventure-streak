import Foundation
import UserNotifications
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

class NotificationService {
    static let shared = NotificationService()
    private let userDefaults = UserDefaults.standard
    private let cachedTokenKey = "fcm_cached_token"
    
    func requestPermissions(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permissions granted")
            } else if let error = error {
                print("Notification permissions error: \(error)")
            }
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }
    
    // NEW: Added for multiplayer conquest feature
    func notifyTerritoryAtRisk(cellId: String) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Territory at Risk!"
        content.body = "Your territory \(cellId) is about to expire. Go for a run to defend it!"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "risk_\(cellId)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // NEW: Added for multiplayer conquest feature
    func notifyTerritoryLost(cellId: String) {
        let content = UNMutableNotificationContent()
        content.title = "❌ Territory Lost"
        content.body = "You lost zone \(cellId). Reclaim it within 24h for a bonus!"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "lost_\(cellId)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleExpirationWarning(daysRemaining: Int) {
        // Stub for MVP
        // In a real app, we would schedule a local notification for when the nearest territory expires
    }
    
    // Cache local para cuando el token llega antes del login
    func cacheFCMToken(_ token: String) {
        userDefaults.set(token, forKey: cachedTokenKey)
    }
    
    private var cachedToken: String? {
        userDefaults.string(forKey: cachedTokenKey)
    }
    
    /// Se llama desde el delegate de Messaging cuando llega un token nuevo.
    func handleNewFCMToken(_ token: String, userId: String?) {
        cacheFCMToken(token)
        guard let userId else { return }
        uploadActiveToken(token, for: userId)
    }
    
    /// Sube el token cacheado (o lo solicita) cuando ya tenemos userId.
    func syncCachedFCMToken(for userId: String) {
        if let token = cachedToken {
            uploadActiveToken(token, for: userId)
            return
        }
        
        #if canImport(FirebaseMessaging)
        Messaging.messaging().token { [weak self] token, error in
            guard let self = self, let token = token, error == nil else { return }
            self.cacheFCMToken(token)
            self.uploadActiveToken(token, for: userId)
        }
        #endif
    }
    
    /// Limpia el token activo de este dispositivo del usuario (para sign-out o cambio de cuenta).
    func removeActiveToken(for userId: String) {
        guard let token = cachedToken else { return }
        UserRepository.shared.removeFCMToken(userId: userId, token: token)
    }
    
    /// Re-genera y sube un nuevo token FCM cuando el backend marca `needsTokenRefresh` o no hay tokens.
    func refreshFCMTokenIfNeeded(for userId: String) {
        #if canImport(FirebaseFirestore)
        let userRef = Firestore.firestore().collection("users").document(userId)
        
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
                    guard let self = self, let token = token, error == nil else { return }
                    self.cacheFCMToken(token)
                    self.uploadActiveToken(token, for: userId)
                    userRef.updateData([
                        "needsTokenRefresh": false,
                        "needsTokenRefreshAt": FieldValue.delete()
                    ])
                }
            }
            #endif
        }
        #endif
    }
    
    private func uploadActiveToken(_ token: String, for userId: String) {
        UserRepository.shared.updateFCMToken(userId: userId, token: token)
    }
}

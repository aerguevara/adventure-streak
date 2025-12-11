import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    
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
}

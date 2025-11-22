import Foundation
import WatchConnectivity

class WatchSyncService: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchSyncService()
    
    @Published var receivedActivity: ActivitySession?
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("WCSession activated: \(activationState.rawValue)")
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        // Handle receiving activity data from Watch
        DispatchQueue.main.async {
            if let activityData = userInfo["activitySession"] as? Data {
                do {
                    let activity = try JSONDecoder().decode(ActivitySession.self, from: activityData)
                    self.receivedActivity = activity
                } catch {
                    print("Error decoding activity from watch: \(error)")
                }
            }
        }
    }
}

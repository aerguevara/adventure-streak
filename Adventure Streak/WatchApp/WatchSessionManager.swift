import Foundation
import WatchConnectivity
import HealthKit

#if os(watchOS)
class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()
    
    @Published var isRunning = false
    @Published var distance: Double = 0
    @Published var duration: TimeInterval = 0
    
    private var session: WCSession?
    private var timer: Timer?
    private var startTime: Date?
    private var currentActivityType: ActivityType = .run
    
    // Mock route for MVP since we don't have full CoreLocation setup on Watch in this snippet
    private var mockRoute: [RoutePoint] = []
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    func startSession(type: ActivityType) {
        isRunning = true
        startTime = Date()
        distance = 0
        duration = 0
        currentActivityType = type
        mockRoute = []
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startTime else { return }
            self.duration = Date().timeIntervalSince(start)
            // Simulate distance
            self.distance += 1.5 // 1.5 meters per second
        }
    }
    
    func stopSession() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        
        guard let start = startTime else { return }
        let end = Date()
        
        // Create session object
        // Note: In a real app, we would share the Model file between targets.
        // Assuming ActivitySession is available here.
        let activity = ActivitySession(
            startDate: start,
            endDate: end,
            activityType: currentActivityType,
            distanceMeters: distance,
            durationSeconds: duration,
            route: mockRoute // Empty for now in MVP watch side
        )
        
        sendActivityToPhone(activity)
    }
    
    private func sendActivityToPhone(_ activity: ActivitySession) {
        guard let session = session, session.isReachable else { return }
        
        do {
            let data = try JSONEncoder().encode(activity)
            session.transferUserInfo(["activitySession": data])
        } catch {
            print("Error encoding activity: \(error)")
        }
    }
    
    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}
    #endif
}
#endif

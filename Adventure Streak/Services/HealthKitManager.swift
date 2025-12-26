import Foundation
import HealthKit
import CoreLocation
import UserNotifications
import UIKit
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Abstract workout representation to support both HealthKit and Simulated data
protocol WorkoutProtocol: Sendable {
    var uuid: UUID { get }
    var startDate: Date { get }
    var endDate: Date { get }
    var duration: TimeInterval { get }
    var workoutActivityType: HKWorkoutActivityType { get }
    var totalDistanceMeters: Double? { get }
    var metadata: [String : Any]? { get }
    var sourceBundleIdentifier: String { get }
    var sourceName: String { get }
}

/// Provider interface to allow mocking HealthKit data
protocol HealthKitProvider: Sendable {
    func fetchWorkouts(completion: @escaping ([WorkoutProtocol]?, Error?) -> Void)
    func fetchRoute(for workout: WorkoutProtocol, completion: @escaping (RouteFetchResult) -> Void)
}

extension HKWorkout: WorkoutProtocol {
    var totalDistanceMeters: Double? {
        return self.totalDistance?.doubleValue(for: .meter())
    }
    var sourceBundleIdentifier: String {
        return self.sourceRevision.source.bundleIdentifier
    }
    var sourceName: String {
        return self.sourceRevision.source.name
    }
}

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    @Published var isSimulationMode = false
    
    // Providers
    private let realProvider = RealHealthKitProvider()
    private var mockProvider: MockHealthKitProvider?
    
    var provider: HealthKitProvider {
        if isSimulationMode {
            if mockProvider == nil { mockProvider = MockHealthKitProvider() }
            return mockProvider!
        }
        return realProvider
    }
    
    private let workoutAnchorKey = "hk_workout_anchor"
    private let notifiedWorkoutsKey = "hk_notified_workouts"
    private let userDefaults = UserDefaults.standard
    
    func requestPermissions(completion: @escaping (Bool, Error?) -> Void) {
        print("HK requestPermissions — solicitando permisos")
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "com.adventurestreak", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit not available"]))
            return
        }

        let workoutType = HKObjectType.workoutType()
        let currentStatus = healthStore.authorizationStatus(for: workoutType)
        if currentStatus == .sharingAuthorized {
            print("HK requestPermissions — ya autorizado (status: \(currentStatus.rawValue)), continuando sin prompt")
            self.isAuthorized = true
            completion(true, nil)
            return
        } else {
            print("HK requestPermissions — estado actual: \(currentStatus.rawValue), solicitando autorización...")
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]
        
        healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
            if let error {
                print("HK requestPermissions — error: \(error.localizedDescription)")
            } else {
                print("HK requestPermissions — success:\(success)")
            }
            DispatchQueue.main.async {
                self.isAuthorized = success
                completion(success, error)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self else { return }
            if self.isAuthorized == false {
                print("HK requestPermissions — sin respuesta tras 5s, revisa permisos en Ajustes > Salud > Apps > Adventure Streak")
            }
        }
    }
    
    func startBackgroundObservers() {
        requestPermissions { success, error in
            guard success else {
                if let error { print("HK permisos rechazados: \(error)") }
                return
            }
            self.enableBackgroundDelivery()
            self.registerWorkoutObserver()
        }
    }
    
    private func enableBackgroundDelivery() {
        healthStore.enableBackgroundDelivery(for: .workoutType(), frequency: .immediate) { success, error in
            if let error {
                print("❌ enableBackgroundDelivery error: \(error)")
            } else {
                print("✅ Background delivery activada para workouts: \(success)")
            }
        }
    }
    
    private func registerWorkoutObserver() {
        let query = HKObserverQuery(sampleType: .workoutType(), predicate: nil) { [weak self] _, completion, error in
            guard let self else {
                completion()
                return
            }
            if let error {
                print("❌ HKObserverQuery error: \(error)")
                completion()
                return
            }
            
            self.handleWorkoutUpdates {
                completion()
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchWorkouts(completion: @escaping ([WorkoutProtocol]?, Error?) -> Void) {
        provider.fetchWorkouts(completion: completion)
    }
    
    func fetchRoute(for workout: WorkoutProtocol, completion: @escaping (RouteFetchResult) -> Void) {
        provider.fetchRoute(for: workout, completion: completion)
    }

    // MARK: - Anchored query para detectar nuevos entrenos
    private func handleWorkoutUpdates(completion: @escaping () -> Void) {
        let anchor = loadAnchor()
        let query = HKAnchoredObjectQuery(type: .workoutType(), predicate: nil, anchor: anchor, limit: HKObjectQueryNoLimit) { [weak self] _, samplesOrNil, _, newAnchor, error in
            guard let self else {
                completion()
                return
            }
            
            if let error {
                print("❌ HKAnchoredObjectQuery error: \(error)")
                completion()
                return
            }
            
            let workouts = (samplesOrNil as? [HKWorkout]) ?? []
            if let newAnchor { self.saveAnchor(newAnchor) }
            
            guard !workouts.isEmpty else {
                completion()
                return
            }
            
            self.notifyNewWorkouts(workouts as [WorkoutProtocol])
            completion()
        }
        
        healthStore.execute(query)
    }
    
    private func notifyNewWorkouts(_ workouts: [WorkoutProtocol]) {
        let notified = Set(userDefaults.stringArray(forKey: notifiedWorkoutsKey) ?? [])
        var newNotified = notified
        
        for workout in workouts {
            let id = workout.uuid.uuidString
            if newNotified.contains(id) { continue }
            newNotified.insert(id)
            
            let hoursSinceEnd = Date().timeIntervalSince(workout.endDate) / 3600
            if hoursSinceEnd > 24 {
                continue
            }
            
            let content = UNMutableNotificationContent()
            content.title = "Nuevo entreno detectado"
            let distance = workout.totalDistanceMeters ?? 0
            let km = distance / 1000
            let formattedDistance = km > 0 ? String(format: "%.1f km", km) : ""
            content.body = formattedDistance.isEmpty
                ? "🔥 ¡Nuevo entreno detectado! Entra para conquistar territorios y subir de nivel."
                : "🔥 ¡Has recorrido \(formattedDistance)! Entra ahora para reclamar tus territorios y XP."
            content.sound = .default
            
            let request = UNNotificationRequest(identifier: "workout_\(id)", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
        
        userDefaults.set(Array(newNotified), forKey: notifiedWorkoutsKey)
    }
    
    private func loadAnchor() -> HKQueryAnchor? {
        guard let data = userDefaults.data(forKey: workoutAnchorKey) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }
    
    private func saveAnchor(_ anchor: HKQueryAnchor) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
            userDefaults.set(data, forKey: workoutAnchorKey)
        }
    }

    
    // Public wrapper for simulation
    func triggerNotificationCheck(for workouts: [WorkoutProtocol]) {
        self.notifyNewWorkouts(workouts)
    }
    
    // Simulate background fetch with delay
    func simulateBackgroundFetch(delay: TimeInterval = 10.0) {
        print("🕒 [Simulation] Starting background task simulation...")
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            var backgroundTask: UIBackgroundTaskIdentifier = .invalid
            backgroundTask = UIApplication.shared.beginBackgroundTask {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
            
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            print("🚀 [Simulation] Firing delayed fetch...")
            
            // Force Simulation Mode for this debug trigger
            #if DEBUG
            if !self.isSimulationMode {
                print("⚠️ [Simulation] Auto-enabling Simulation Mode due to trigger")
                self.isSimulationMode = true
            }
            #endif

            self.provider.fetchWorkouts { [weak self] workouts, error in
                guard let self = self, let workouts = workouts else {
                    UIApplication.shared.endBackgroundTask(backgroundTask)
                    backgroundTask = .invalid
                    return
                }
                
                // 1. Notify (Simulates 'HKObserverQuery' detecting new data)
                self.notifyNewWorkouts(workouts as [WorkoutProtocol])
                
                // 2. End task
                Task { @MainActor in
                    UIApplication.shared.endBackgroundTask(backgroundTask)
                    backgroundTask = .invalid
                }
            }
        }
    }
}

// MARK: - Real Implementation
final class RealHealthKitProvider: HealthKitProvider {
    private let healthStore = HKHealthStore()

    func fetchWorkouts(completion: @escaping ([WorkoutProtocol]?, Error?) -> Void) {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: nil, limit: 100, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let workouts = samples as? [HKWorkout], error == nil else {
                completion(nil, error)
                return
            }
            completion(workouts, nil)
        }
        healthStore.execute(query)
    }

    func fetchRoute(for workout: WorkoutProtocol, completion: @escaping (RouteFetchResult) -> Void) {
        guard let hkWorkout = workout as? HKWorkout else {
            completion(.error(NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HKWorkout object"])))
            return
        }
        
        let runningObjectQuery = HKQuery.predicateForObjects(from: hkWorkout)
        let routeQuery = HKAnchoredObjectQuery(
            type: HKSeriesType.workoutRoute(),
            predicate: runningObjectQuery,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { (_, samples, _, _, error) in

            if let error {
                completion(.error(error))
                return
            }

            guard let routes = samples as? [HKWorkoutRoute], !routes.isEmpty else {
                completion(.emptySeries)
                return
            }

            let group = DispatchGroup()
            let lockQueue = DispatchQueue(label: "com.adventurestreak.routecollector")
            var allLocations: [CLLocation] = []
            var firstError: Error?

            for route in routes {
                group.enter()
                let query = HKWorkoutRouteQuery(route: route) { (_, locationsOrNil, done, errorOrNil) in
                    if let errorOrNil {
                        lockQueue.sync { if firstError == nil { firstError = errorOrNil } }
                    }
                    if let locations = locationsOrNil {
                        lockQueue.sync { allLocations.append(contentsOf: locations) }
                    }
                    if done || errorOrNil != nil {
                        group.leave()
                    }
                }
                HKHealthStore().execute(query)
            }

            group.notify(queue: .main) {
                if let error = firstError {
                    completion(.error(error))
                    return
                }
                let routePoints = allLocations.map { RoutePoint(location: $0) }
                if routePoints.isEmpty {
                    completion(.emptySeries)
                } else {
                    completion(.success(routePoints))
                }
            }
        }
        HKHealthStore().execute(routeQuery)
    }
}

// MARK: - Mock Implementation
final class MockHealthKitProvider: HealthKitProvider {
    struct MockWorkout: WorkoutProtocol, @unchecked Sendable {
        var uuid: UUID
        var startDate: Date
        var endDate: Date
        var duration: TimeInterval
        var workoutActivityType: HKWorkoutActivityType
        var totalDistanceMeters: Double?
        var metadata: [String : Any]?
        var sourceBundleIdentifier: String
        var sourceName: String
        
        // Custom field for mock routes
        var mockRoute: [RoutePoint]?
    }

    func fetchWorkouts(completion: @escaping ([WorkoutProtocol]?, Error?) -> Void) {
        #if canImport(FirebaseFirestore)
        print("🧪 [MockProvider] Fetching from Firestore collection 'debug_mock_workouts'...")
        Firestore.shared.collection("debug_mock_workouts").getDocuments { snapshot, error in
            if let error = error {
                print("❌ [MockProvider] Error: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            let mocks = snapshot?.documents.compactMap { doc -> MockWorkout? in
                let data = doc.data()
                guard let idString = data["id"] as? String,
                      let uuid = UUID(uuidString: idString),
                      let start = (data["startDate"] as? Timestamp)?.dateValue(),
                      let end = (data["endDate"] as? Timestamp)?.dateValue() else {
                    print("⚠️ [MockProvider] Skipping invalid doc: \(doc.data())")
                    return nil
                }
                
                let typeRaw = (data["type"] as? UInt) ?? HKWorkoutActivityType.running.rawValue
                
                // Parse route if present
                var routePoints: [RoutePoint]? = nil
                if let routeData = data["route"] as? [[String: Any]] {
                    routePoints = routeData.compactMap { p -> RoutePoint? in
                        guard let lat = p["latitude"] as? Double,
                              let lon = p["longitude"] as? Double else { return nil }
                        
                        let timestamp = (p["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                        let altitude = p["altitude"] as? Double ?? 0
                        
                        return RoutePoint(latitude: lat, longitude: lon, timestamp: timestamp, altitude: altitude)
                    }
                }
                
                return MockWorkout(
                    uuid: uuid,
                    startDate: start,
                    endDate: end,
                    duration: end.timeIntervalSince(start),
                    workoutActivityType: HKWorkoutActivityType(rawValue: typeRaw) ?? .running,
                    totalDistanceMeters: data["distanceMeters"] as? Double,
                    metadata: data["metadata"] as? [String: Any],
                    sourceBundleIdentifier: (data["sourceBundleIdentifier"] as? String) ?? "com.apple.Health",
                    sourceName: (data["sourceName"] as? String) ?? "Mock Health",
                    mockRoute: routePoints
                )
            }
            print("✅ [MockProvider] Found \(mocks?.count ?? 0) mock workouts")
            completion(mocks, nil)
        }
        #else
        completion([], nil)
        #endif
    }

    func fetchRoute(for workout: WorkoutProtocol, completion: @escaping (RouteFetchResult) -> Void) {
        if let mock = workout as? MockWorkout, let points = mock.mockRoute {
            completion(.success(points))
        } else {
            completion(.emptySeries)
        }
    }
}

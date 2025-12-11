import Foundation
import HealthKit
import CoreLocation
import UserNotifications

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    
    private let workoutAnchorKey = "hk_workout_anchor"
    private let notifiedWorkoutsKey = "hk_notified_workouts"
    private let userDefaults = UserDefaults.standard
    
    func requestPermissions(completion: @escaping (Bool, Error?) -> Void) {
        print("HK requestPermissions — solicitando permisos")
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "com.adventurestreak", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit not available"]))
            return
        }

        // Si ya está autorizado para workouts, evitar pedir de nuevo y continuar
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

        // Watchdog: si en 5s no recibimos callback, avisa en consola
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self else { return }
            if self.isAuthorized == false {
                print("HK requestPermissions — sin respuesta tras 5s, revisa permisos en Ajustes > Salud > Apps > Adventure Streak")
            }
        }
    }
    
    // MARK: - Background delivery
    func startBackgroundObservers() {
        // Asegura permisos de HealthKit
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
    
    func fetchWorkouts(completion: @escaping ([HKWorkout]?, Error?) -> Void) {
        // We want all workouts (indoor y outdoor), so we pass nil as predicate and filter later
        let predicate: NSPredicate? = nil
        // Nota: ya no filtramos a solo actividades outdoor, la clasificación se hace en el ViewModel.
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        print("HK fetchWorkouts — lanzando consulta a HealthKit...")
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 100, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let workouts = samples as? [HKWorkout], error == nil else {
                if let error { print("HK fetchWorkouts — error: \(error.localizedDescription)") }
                completion(nil, error)
                return
            }
            
            print("HK fetchWorkouts — recibidos \(workouts.count) workouts")
            completion(workouts, nil)
        }
        
        healthStore.execute(query)
    }
    
    func fetchRoute(for workout: HKWorkout, completion: @escaping ([RoutePoint]?, Error?) -> Void) {
        let runningObjectQuery = HKQuery.predicateForObjects(from: workout)
        let routeQuery = HKAnchoredObjectQuery(type: HKSeriesType.workoutRoute(), predicate: runningObjectQuery, anchor: nil, limit: HKObjectQueryNoLimit) { (query, samples, deletedObjects, newAnchor, error) in
            
            guard let routes = samples as? [HKWorkoutRoute], let route = routes.first else {
                completion(nil, error)
                return
            }
            
            var allLocations: [CLLocation] = []
            
            let query = HKWorkoutRouteQuery(route: route) { (query, locationsOrNil, done, errorOrNil) in
                if let error = errorOrNil {
                    completion(nil, error)
                    return
                }
                
                if let locations = locationsOrNil {
                    allLocations.append(contentsOf: locations)
                }
                
                if done {
                    let routePoints = allLocations.map { RoutePoint(location: $0) }
                    completion(routePoints, nil)
                }
            }
            
            self.healthStore.execute(query)
        }
        
        healthStore.execute(routeQuery)
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
            
            notifyNewWorkouts(workouts)
            completion()
        }
        
        healthStore.execute(query)
    }
    
    private func notifyNewWorkouts(_ workouts: [HKWorkout]) {
        let notified = Set(userDefaults.stringArray(forKey: notifiedWorkoutsKey) ?? [])
        var newNotified = notified
        
        for workout in workouts {
            let id = workout.uuid.uuidString
            if newNotified.contains(id) { continue }
            newNotified.insert(id)
            
            let content = UNMutableNotificationContent()
            content.title = "Nuevo entreno detectado"
            let distance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
            let km = distance / 1000
            let formattedDistance = km > 0 ? String(format: "%.1f km", km) : ""
            content.body = formattedDistance.isEmpty
                ? "Abre Adventure Streak para procesarlo y ganar XP."
                : "Entreno de \(formattedDistance). Abre Adventure Streak para procesarlo y ganar XP."
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
}

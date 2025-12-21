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
    
    func fetchRoute(for workout: HKWorkout, completion: @escaping (RouteFetchResult) -> Void) {
        let runningObjectQuery = HKQuery.predicateForObjects(from: workout)
        let routeQuery = HKAnchoredObjectQuery(
            type: HKSeriesType.workoutRoute(),
            predicate: runningObjectQuery,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { (_, samples, _, _, error) in

            if let error {
                let bundle = workout.sourceRevision.source.bundleIdentifier
                print("HK fetchRoute — error for \(workout.uuid): \(error.localizedDescription) source:\(bundle) type:\(workout.workoutActivityType.rawValue)")
                completion(.error(error))
                return
            }

            guard let routes = samples as? [HKWorkoutRoute], !routes.isEmpty else {
                let bundle = workout.sourceRevision.source.bundleIdentifier
                print("HK fetchRoute — empty series for \(workout.uuid) source:\(bundle) type:\(workout.workoutActivityType.rawValue)")
                completion(.emptySeries)
                return
            }

            // Unir todas las series asociadas al workout (algunos entrenos vienen segmentados)
            let group = DispatchGroup()
            let lockQueue = DispatchQueue(label: "com.adventurestreak.routecollector")
            var allLocations: [CLLocation] = []
            var firstError: Error?

            for route in routes {
                group.enter()
                let query = HKWorkoutRouteQuery(route: route) { (_, locationsOrNil, done, errorOrNil) in
                    if let errorOrNil {
                        print("HK fetchRoute — route segment error for \(workout.uuid): \(errorOrNil.localizedDescription)")
                        lockQueue.sync {
                            if firstError == nil { firstError = errorOrNil }
                        }
                    }

                    if let locations = locationsOrNil {
                        lockQueue.sync { allLocations.append(contentsOf: locations) }
                    }

                    // Algunos errores no marcan `done`; evitamos deadlocks dejando el grupo en ambos casos
                    if done {
                        group.leave()
                    } else if errorOrNil != nil {
                        group.leave()
                    }
                }

                self.healthStore.execute(query)
            }

            group.notify(queue: .main) {
                if let error = firstError {
                    print("HK fetchRoute — final error for \(workout.uuid): \(error.localizedDescription) points:\(allLocations.count)")
                    completion(.error(error))
                    return
                }

                let routePoints = allLocations.map { RoutePoint(location: $0) }
                let bundle = workout.sourceRevision.source.bundleIdentifier
                print("HK fetchRoute — completed \(workout.uuid) points:\(routePoints.count) source:\(bundle) type:\(workout.workoutActivityType.rawValue)")
                if routePoints.isEmpty {
                    completion(.emptySeries)
                } else {
                    completion(.success(routePoints))
                }
            }
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
            
            // Suppress notifications for historic workouts (> 24 hours old)
            // This prevents spam during initial import.
            let hoursSinceEnd = Date().timeIntervalSince(workout.endDate) / 3600
            if hoursSinceEnd > 24 {
                continue
            }
            
            let content = UNMutableNotificationContent()
            content.title = "Nuevo entreno detectado"
            let distance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
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
}

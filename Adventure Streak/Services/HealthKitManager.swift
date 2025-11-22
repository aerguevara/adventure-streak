import Foundation
import HealthKit
import CoreLocation

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    
    func requestPermissions(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "com.adventurestreak", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit not available"]))
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]
        
        healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
                completion(success, error)
            }
        }
    }
    
    func fetchOutdoorWorkouts(completion: @escaping ([HKWorkout]?, Error?) -> Void) {
        // We want all workouts, so we pass nil as predicate and filter locally
        let predicate: NSPredicate? = nil
        // Filter for outdoor activities if needed, but for now we get all and filter locally or let user choose
        // Ideally we filter by .running, .walking, .cycling
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 50, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let workouts = samples as? [HKWorkout], error == nil else {
                completion(nil, error)
                return
            }
            
            // Filter for outdoor types relevant to us
            let relevantWorkouts = workouts.filter { workout in
                switch workout.workoutActivityType {
                case .running, .walking, .cycling, .hiking:
                    return true
                default:
                    return false
                }
            }
            
            completion(relevantWorkouts, nil)
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
}

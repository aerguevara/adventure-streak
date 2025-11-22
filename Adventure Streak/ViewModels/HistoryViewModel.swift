import Foundation

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var activities: [ActivitySession] = []
    
    private let activityStore: ActivityStore
    private let territoryService: TerritoryService
    
    @Published var isImporting = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    init(activityStore: ActivityStore, territoryService: TerritoryService) {
        self.activityStore = activityStore
        self.territoryService = territoryService
        loadActivities()
    }
    
    func loadActivities() {
        self.activities = activityStore.fetchAllActivities()
    }
    
    func importFromHealthKit() {
        isImporting = true
        print("Starting HealthKit import...")
        
        // Request permissions first in case they weren't granted in Onboarding
        HealthKitManager.shared.requestPermissions { [weak self] success, error in
            guard let self = self else { return }
            
            if !success {
                DispatchQueue.main.async {
                    self.isImporting = false
                    self.alertMessage = "HealthKit authorization failed. Please check Settings."
                    self.showAlert = true
                }
                return
            }
            
            HealthKitManager.shared.fetchOutdoorWorkouts { [weak self] workouts, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.isImporting = false
                    self.alertMessage = "Error fetching workouts: \(error.localizedDescription)"
                    self.showAlert = true
                }
                return
            }
            
            guard let workouts = workouts, !workouts.isEmpty else {
                DispatchQueue.main.async {
                    self.isImporting = false
                    self.alertMessage = "No outdoor workouts found in HealthKit."
                    self.showAlert = true
                }
                return
            }
            
            print("Found \(workouts.count) workouts. Processing...")
            let group = DispatchGroup()
            var importedCount = 0
            
            for workout in workouts {
                // Check if already exists to avoid duplicates (simple check by date/id)
                if self.activityStore.activities.contains(where: { $0.startDate == workout.startDate }) {
                    continue
                }
                
                group.enter()
                HealthKitManager.shared.fetchRoute(for: workout) { routePoints, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("Error fetching route for workout: \(error)")
                        return
                    }
                    
                    guard let points = routePoints, !points.isEmpty else {
                        print("No route points for workout at \(workout.startDate)")
                        return
                    }
                    
                    let type: ActivityType
                    switch workout.workoutActivityType {
                    case .running: type = .run
                    case .walking: type = .walk
                    case .cycling: type = .bike
                    default: type = .otherOutdoor
                    }
                    
                    let session = ActivitySession(
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        activityType: type,
                        distanceMeters: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                        durationSeconds: workout.duration,
                        route: points
                    )
                    
                    DispatchQueue.main.async {
                        self.activityStore.saveActivity(session)
                        _ = self.territoryService.processActivity(session)
                        importedCount += 1
                    }
                }
            }
            
            group.notify(queue: .main) {
                self.isImporting = false
                self.loadActivities()
                self.alertMessage = "Imported \(importedCount) new activities."
                self.showAlert = true
            }
        }
        }
    }
}

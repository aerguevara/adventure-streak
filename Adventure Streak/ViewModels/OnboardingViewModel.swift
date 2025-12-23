import Foundation
import SwiftUI

enum PermissionStep: Int, CaseIterable {
    case intro
    case health
    case location
    case notifications
    case discovery
    case done
}

@MainActor
class OnboardingViewModel: ObservableObject {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @Published var currentStep: PermissionStep = .intro
    @Published var discoveredActivities: [ActivitySession] = []
    @Published var isImporting: Bool = false
    
    private let locationService: LocationService
    private let notificationService: NotificationService
    
    init(locationService: LocationService) {
        self.locationService = locationService
        self.notificationService = NotificationService.shared
        
        // Predeterminar si debemos saltar a discovery si ya tenemos permisos
        checkInitialStep()
    }
    
    private func checkInitialStep() {
        // En un caso real, chequearíamos si ya tenemos permisos de salud/location
        // Para este onboarding guiado, empezamos en intro.
    }
    
    func requestHealth() {
        HealthKitManager.shared.requestPermissions { success, error in
            if !success {
                print("HealthKit permission failed: \(String(describing: error))")
            }
            DispatchQueue.main.async {
                self.advance()
            }
        }
    }
    
    func requestLocation() {
        locationService.requestPermission()
        advance()
    }
    
    func requestNotifications() {
        notificationService.requestPermissions { _ in
            self.advance()
        }
    }
    
    func advance() {
        let nextRaw = currentStep.rawValue + 1
        if let next = PermissionStep(rawValue: nextRaw) {
            currentStep = next
            if next == .discovery {
                startDiscovery()
            }
        } else {
            currentStep = .done
        }
    }
    
    func startDiscovery() {
        Task {
            await GameConfigService.shared.loadConfigIfNeeded()
            let config = GameConfigService.shared.config
            let limit = config.onboardingImportLimit
            let cutoffDate = GameConfigService.shared.cutoffDate()
            
            HealthKitManager.shared.fetchWorkouts { [weak self] workouts, error in
                guard let self = self, let workouts = workouts else { return }
                
                // Sort by date descending (most recent first)
                let sortedWorkouts = workouts
                    .filter { $0.startDate >= cutoffDate }
                    .sorted(by: { $0.startDate > $1.startDate })
                
                Task {
                    var sessions: [ActivitySession] = []
                    
                    for workout in sortedWorkouts {
                        if sessions.count >= limit { break }
                        
                        // Fetch route points asynchronously
                        let points: [RoutePoint] = await withCheckedContinuation { continuation in
                            HealthKitManager.shared.fetchRoute(for: workout) { result in
                                switch result {
                                case .success(let pts):
                                    continuation.resume(returning: pts)
                                default:
                                    continuation.resume(returning: [])
                                }
                            }
                        }
                        
                        // Filter strictly for activities with GPS route
                        if !points.isEmpty {
                            let session = ActivitySession(
                                id: workout.uuid,
                                startDate: workout.startDate,
                                endDate: workout.endDate,
                                activityType: workout.activityType,
                                distanceMeters: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                                durationSeconds: workout.duration,
                                workoutName: workout.workoutName,
                                route: points
                            )
                            sessions.append(session)
                        }
                    }
                    
                    await MainActor.run {
                        self.discoveredActivities = sessions
                        if self.discoveredActivities.isEmpty {
                            self.advance()
                        }
                    }
                }
            }
        }
    }
    
    func importActivities() {
        guard !discoveredActivities.isEmpty else {
            advance()
            return
        }
        
        isImporting = true
        Task {
            let userId = AuthenticationService.shared.userId ?? "unknown_user"
            await ActivityRepository.shared.saveActivities(discoveredActivities, userId: userId)
            isImporting = false
            advance()
        }
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
    
    func finish() {
        completeOnboarding()
    }
}

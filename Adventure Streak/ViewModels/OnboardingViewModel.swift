import Foundation
import SwiftUI

class OnboardingViewModel: ObservableObject {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    
    private let locationService: LocationService
    private let notificationService: NotificationService
    
    init(locationService: LocationService) {
        self.locationService = locationService
        self.notificationService = NotificationService.shared
    }
    
    func requestPermissions() {
        locationService.requestPermission()
        notificationService.requestPermissions()
        HealthKitManager.shared.requestPermissions { success, error in
            if !success {
                print("HealthKit permission failed: \(String(describing: error))")
            }
        }
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}

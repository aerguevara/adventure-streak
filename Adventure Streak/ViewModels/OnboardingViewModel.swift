import Foundation
import SwiftUI

enum PermissionStep: Int, CaseIterable {
    case intro
    case health
    case location
    case notifications
    case done
}

@MainActor
class OnboardingViewModel: ObservableObject {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @Published var currentStep: PermissionStep = .intro
    
    private let locationService: LocationService
    private let notificationService: NotificationService
    
    init(locationService: LocationService) {
        self.locationService = locationService
        self.notificationService = NotificationService.shared
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
        } else {
            currentStep = .done
        }
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
    
    func finish() {
        completeOnboarding()
    }
}

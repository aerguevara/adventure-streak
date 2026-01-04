import Foundation
import SwiftUI
import HealthKit

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
    @AppStorage("onboardingCompletionDate") var onboardingCompletionDate: Double = 0
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
            let cutoffDate = GameConfigService.shared.cutoffDate()
            
            let sessions = await ActivitySyncService.shared.findNewWorkouts(from: cutoffDate)
            
            await MainActor.run {
                self.discoveredActivities = sessions
                if self.discoveredActivities.isEmpty {
                    self.advance()
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
            await ActivitySyncService.shared.processSessions(discoveredActivities) { processed, total in
                print("[Onboarding] Importing: \(processed)/\(total)")
            }
            
            await MainActor.run {
                self.isImporting = false
                self.advance()
            }
        }
    }
    
    func completeOnboarding() {
        // Only set the date if it doesn't exist (preserving the first onboarding discovery anchor)
        if onboardingCompletionDate == 0 {
            // READ CONFIGURATION
            let daysToImport = GameConfigService.shared.config.initialImportDays
            
            // CALCULATE ANCHOR (Start of "The User's Story")
            let anchorDate = Calendar.current.date(
                byAdding: .day,
                value: -daysToImport,
                to: Date()
            ) ?? Date()
            
            onboardingCompletionDate = anchorDate.timeIntervalSince1970
            print("[OnboardingViewModel] First onboarding completed. Configured initial import: \(daysToImport) days. Anchor set to: \(anchorDate)")
        }
        hasCompletedOnboarding = true
    }
    
    func finish() {
        completeOnboarding()
    }
    
    // MARK: - Helpers
    // Unified logic moved to ActivitySyncService.shared
}

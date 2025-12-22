import SwiftUI
import BackgroundTasks

struct ContentView: View {
    @EnvironmentObject private var configService: GameConfigService
    @StateObject private var authService = AuthenticationService.shared
    @Environment(\.scenePhase) private var scenePhase
    private let activityStore: ActivityStore
    private let locService: LocationService
    
    // ViewModels
    @StateObject private var onboardingViewModel: OnboardingViewModel
    @StateObject private var mapViewModel: MapViewModel
    @StateObject private var workoutsViewModel: WorkoutsViewModel
    @StateObject private var profileViewModel: ProfileViewModel
    
    init() {
        // Initialize services
        let locService = LocationService()
        let actStore = ActivityStore.shared
        let terrStore = TerritoryStore.shared
        self.activityStore = actStore
        self.locService = locService
        
        // Correct way to initialize StateObject with dependencies
        _onboardingViewModel = StateObject(wrappedValue: OnboardingViewModel(locationService: locService))
        _mapViewModel = StateObject(wrappedValue: MapViewModel(locationService: locService, territoryStore: terrStore, activityStore: actStore, configService: GameConfigService.shared))
        
        let terrService = TerritoryService(territoryStore: terrStore)
        _workoutsViewModel = StateObject(wrappedValue: WorkoutsViewModel(activityStore: actStore, territoryService: terrService, configService: GameConfigService.shared))
        
        _profileViewModel = StateObject(wrappedValue: ProfileViewModel(activityStore: actStore, territoryStore: terrStore, configService: GameConfigService.shared))
    }
    
    var body: some View {
        ZStack {
            Group {
                if !configService.isLoaded {
                    VStack(spacing: 12) {
                        ProgressView("Cargando configuración...")
                            .progressViewStyle(.circular)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else if !authService.isAuthenticated {
                    PremiumLoginView()
                } else if !onboardingViewModel.hasCompletedOnboarding {
                    OnboardingView(viewModel: onboardingViewModel)
                } else {
                    MainTabView(
                        mapViewModel: mapViewModel,
                        workoutsViewModel: workoutsViewModel,
                        profileViewModel: profileViewModel,
                        activityStore: mapViewModel.activityStore,
                        territoryStore: mapViewModel.territoryStore
                    )
                }
            }
            
            // Modal detallado para primera carga cuando no hay datos locales
            if configService.isLoaded,
               authService.isAuthenticated,
               onboardingViewModel.hasCompletedOnboarding,
               activityStore.activities.isEmpty,
               (workoutsViewModel.isLoading || authService.isSyncingData) {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Cargando tus datos iniciales...")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Estamos preparando tus actividades y territorio desde la nube.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(radius: 10)
                .padding(.horizontal, 24)
            }
            
        }
        .task {
            await configService.loadConfigIfNeeded()
            // Arranca observadores solo si el onboarding ya terminó
            if onboardingViewModel.hasCompletedOnboarding {
                startBackgroundServices()
            }
        }
        .onChange(of: onboardingViewModel.hasCompletedOnboarding) { _, completed in
            if completed {
                startBackgroundServices()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                locService.stopMonitoring()
                locService.stopTracking()
            default:
                break
            }
        }
    }
    
    private func startBackgroundServices() {
        HealthKitManager.shared.startBackgroundObservers()
        BackgroundTaskService.shared.scheduleRefresh()
        Task {
            NotificationService.shared.requestPermissions()
            NotificationService.shared.startObserving()
        }
    }
}

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var configService: GameConfigService
    @StateObject private var authService = AuthenticationService.shared
    
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
                    LoginView()
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
            
            if authService.isSyncingData {
                Color.black.opacity(0.25).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Sincronizando datos...")
                        .font(.callout)
                        .foregroundColor(.primary)
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(radius: 10)
            }
        }
        .task {
            await configService.loadConfigIfNeeded()
        }
    }
}

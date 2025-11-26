import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthenticationService.shared
    
    // ViewModels
    @StateObject private var onboardingViewModel: OnboardingViewModel
    @StateObject private var mapViewModel: MapViewModel
    @StateObject private var workoutsViewModel: WorkoutsViewModel
    @StateObject private var profileViewModel: ProfileViewModel
    
    init() {
        // Initialize services
        let locService = LocationService()
        let actStore = ActivityStore()
        let terrStore = TerritoryStore()
        
        // Correct way to initialize StateObject with dependencies
        _onboardingViewModel = StateObject(wrappedValue: OnboardingViewModel(locationService: locService))
        _mapViewModel = StateObject(wrappedValue: MapViewModel(locationService: locService, territoryStore: terrStore, activityStore: actStore))
        
        let terrService = TerritoryService(territoryStore: terrStore)
        _workoutsViewModel = StateObject(wrappedValue: WorkoutsViewModel(activityStore: actStore, territoryService: terrService))
        
        _profileViewModel = StateObject(wrappedValue: ProfileViewModel(activityStore: actStore, territoryStore: terrStore))
    }
    
    var body: some View {
        Group {
            if !authService.isAuthenticated {
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
    }
}

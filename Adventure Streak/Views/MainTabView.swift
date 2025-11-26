import SwiftUI

struct MainTabView: View {
    @StateObject var mapViewModel: MapViewModel
    @StateObject var workoutsViewModel: WorkoutsViewModel
    @StateObject var profileViewModel: ProfileViewModel
    
    // Dependencies for Feed
    let activityStore: ActivityStore
    let territoryStore: TerritoryStore
    
    var body: some View {
        TabView {
            MapView(viewModel: mapViewModel)
                .ignoresSafeArea(edges: .top)
                .tabItem {
                    Label("Map", systemImage: "map")
                }
            
            WorkoutsView(viewModel: workoutsViewModel)
                .tabItem {
                    Label("Entrenos", systemImage: "clock.arrow.circlepath")
                }
            
            // NEW: Added for multiplayer conquest feature
            NavigationView {
                ActivityFeedView(viewModel: FeedViewModel(activityStore: activityStore, territoryStore: territoryStore))
            }
            .tabItem {
                Label("Feed", systemImage: "person.3.fill")
            }
            
            ProfileView(viewModel: profileViewModel)
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
    }
}

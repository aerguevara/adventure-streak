import SwiftUI

struct MainTabView: View {
    @StateObject var mapViewModel: MapViewModel
    @StateObject var workoutsViewModel: WorkoutsViewModel
    @StateObject var profileViewModel: ProfileViewModel
    @StateObject var badgesViewModel = BadgesViewModel()
    
    // Dependencies for Feed
    let activityStore: ActivityStore
    let territoryStore: TerritoryStore
    
    var body: some View {
        TabView {
            ZStack(alignment: .bottomTrailing) {
                MapView(viewModel: mapViewModel)
                    .ignoresSafeArea(edges: .top)
                
                // Location Button
                Button(action: {
                    mapViewModel.centerOnUserLocation()
                }) {
                    Image(systemName: "location.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .padding(12)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 24)
            }
            .tabItem {
                Label("Map", systemImage: "map")
            }
            
            WorkoutsView(viewModel: workoutsViewModel, profileViewModel: profileViewModel, badgesViewModel: badgesViewModel)
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

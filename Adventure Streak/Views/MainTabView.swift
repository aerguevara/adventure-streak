import SwiftUI

struct MainTabView: View {
    @StateObject var mapViewModel: MapViewModel
    @StateObject var historyViewModel: HistoryViewModel
    @StateObject var profileViewModel: ProfileViewModel
    
    var body: some View {
        TabView {
            MapView(viewModel: mapViewModel)
                .tabItem {
                    Label("Map", systemImage: "map")
                }
            
            HistoryView(viewModel: historyViewModel)
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
            
            // NEW: Added for multiplayer conquest feature
            NavigationView {
                ActivityFeedView()
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

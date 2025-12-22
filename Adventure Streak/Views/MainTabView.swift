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
            WorkoutsView(viewModel: workoutsViewModel, profileViewModel: profileViewModel, badgesViewModel: badgesViewModel)
                .tabItem {
                    Label("Progreso", systemImage: "chart.bar.fill")
                }
            
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    MapView(viewModel: mapViewModel)
                        .ignoresSafeArea(edges: .top)
                    
                    if let owner = mapViewModel.selectedTerritoryOwner,
                       let territoryId = mapViewModel.selectedTerritoryId {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                if let data = mapViewModel.selectedTerritoryOwnerAvatarData,
                                   let image = UIImage(data: data) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 48, height: 48)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .foregroundStyle(.primary)
                                        .frame(width: 48, height: 48)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(owner)
                                        .font(.headline)
                                    Text("Territorio \(territoryId)")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                Label("\(mapViewModel.selectedTerritoryOwnerXP ?? 0) XP", systemImage: "star.fill")
                                    .font(.footnote)
                                    .foregroundColor(.primary)
                                
                                let territoriesLabel = mapViewModel.selectedTerritoryOwnerTerritories.map { "\($0) territorios" } ?? "Territorios desconocidos"
                                Label(territoriesLabel, systemImage: "map")
                                    .font(.footnote)
                                    .foregroundColor(.primary)
                            }
                            
                            Button(action: {
                                mapViewModel.selectTerritory(id: nil, ownerName: nil, ownerUserId: nil)
                            }) {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Cerrar")
                                }
                                .font(.caption)
                            }
                            .padding(.top, 4)
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(14)
                        .shadow(radius: 6)
                        .padding()
                    }
                }
                
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
                Label("Mapa", systemImage: "map")
            }
            
            // NEW: Added for multiplayer conquest feature
            SocialFeedView()
            .tabItem {
                Label("Social", systemImage: "person.2.fill")
            }
            
            NavigationView {
                RankingView()
            }
            .tabItem {
                Label("Ranking", systemImage: "trophy.fill")
            }
            

        }
    }
}

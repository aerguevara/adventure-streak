import SwiftUI
import MapKit
import UIKit

@available(iOS 17.0, *)
struct MapView17: View {
    @StateObject var viewModel: MapViewModel
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    
    var body: some View {
        ZStack {
            MapReader { proxy in
                Map(position: $position) {
                    UserAnnotation()
                    
                    ForEach(viewModel.conqueredTerritories) { cell in
                        MapPolygon(coordinates: TerritoryGrid.polygon(for: cell))
                            .foregroundStyle(Color.green.opacity(0.4))
                            .stroke(Color.green, lineWidth: 1)
                        
                        if position.region?.span.latitudeDelta ?? 0 < 0.05 {
                            Annotation("", coordinate: cell.centerCoordinate) {
                                let auth = AuthenticationService.shared
                                let userId = cell.ownerUserId ?? auth.userId ?? ""
                                let icon = viewModel.userIcons[userId] ?? "🚩"
                                Text(icon)
                                    .font(.system(size: 22))
                                    .shadow(color: .black, radius: 2, x: 0, y: 1)
                                    .id("\(userId)_\(icon)") // Force re-render when icon changes
                            }
                        }
                    }
                    
                    ForEach(viewModel.otherTerritories) { territory in
                        MapPolygon(coordinates: territory.boundary.map { $0.coordinate })
                            .foregroundStyle(Color.orange.opacity(0.4))
                            .stroke(Color.orange, lineWidth: 1)
                        
                        if position.region?.span.latitudeDelta ?? 0 < 0.05 {
                            Annotation("", coordinate: territory.centerCoordinate) {
                                let icon = viewModel.userIcons[territory.userId] ?? "🚩"
                                Text(icon)
                                    .font(.system(size: 22))
                                    .shadow(color: .black, radius: 2, x: 0, y: 1)
                                    .id("\(territory.userId)_\(icon)") // Force re-render when icon changes
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .onMapCameraChange { context in
                    DispatchQueue.main.async {
                        viewModel.updateVisibleRegion(context.region)
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let point = value.location
                            if let coord = proxy.convert(point, from: .local) {
                                selectOwner(at: coord)
                            }
                        }
                )
            }
            
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Territories: \(viewModel.conqueredTerritories.count)")
                            .font(.caption)
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                if let owner = viewModel.selectedTerritoryOwner {
                    TerritoryOwnerCard(
                        ownerName: owner,
                        territoryId: viewModel.selectedTerritoryId ?? "",
                        avatarData: viewModel.selectedTerritoryOwnerAvatarData,
                        ownerIcon: viewModel.selectedTerritoryOwnerIcon,
                        xp: viewModel.selectedTerritoryOwnerXP,
                        territories: viewModel.selectedTerritoryOwnerTerritories,
                        firstConqueredAt: viewModel.selectedTerritoryFirstConqueredAt,
                        defenseCount: viewModel.selectedTerritoryDefenseCount,
                        onClose: {
                            withAnimation(.spring()) {
                                viewModel.selectTerritory(id: nil, ownerName: nil, ownerUserId: nil)
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 20)
                }
                
                if viewModel.isTracking {
                    trackingOverlay
                } else {
                    playButton
                }
            }
        }
    }
    
    private var trackingOverlay: some View {
        VStack {
            Text("Duration: \(formatDuration(viewModel.currentActivityDuration))")
            Text("Distance: \(String(format: "%.2f km", viewModel.currentActivityDistance / 1000))")
            
            Button(action: {
                viewModel.stopActivity(type: .walk)
            }) {
                Text("Stop Activity")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(30)
            }
        }
        .padding()
        .background(Color.white.opacity(0.9))
        .cornerRadius(15)
        .padding(.bottom)
    }
    
    private var playButton: some View {
        Button(action: {
            viewModel.startActivity(type: .walk)
        }) {
            Image(systemName: "play.fill")
                .font(.title)
                .foregroundColor(.white)
                .padding(20)
                .background(Color.green)
                .clipShape(Circle())
                .shadow(radius: 5)
        }
        .padding(.bottom, 20)
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00"
    }
    
    private func selectOwner(at coordinate: CLLocationCoordinate2D) {
        if let cell = viewModel.conqueredTerritories.first(where: { cell in
            let poly = TerritoryGrid.polygon(for: cell)
            guard let minLat = poly.map(\.latitude).min(),
                  let maxLat = poly.map(\.latitude).max(),
                  let minLon = poly.map(\.longitude).min(),
                  let maxLon = poly.map(\.longitude).max() else { return false }
            return coordinate.latitude >= minLat && coordinate.latitude <= maxLat &&
                   coordinate.longitude >= minLon && coordinate.longitude <= maxLon
        }) {
            let auth = AuthenticationService.shared
            let ownerId = cell.ownerUserId ?? auth.userId
            let displayName = cell.ownerDisplayName
                ?? (ownerId == auth.userId ? auth.resolvedUserName() : cell.ownerUserId)
                ?? "Sin dueño"
            viewModel.selectTerritory(id: cell.id, ownerName: displayName, ownerUserId: ownerId)
            return
        }
        
        if let rival = viewModel.otherTerritories.first(where: { territory in
            guard let id = territory.id else { return false }
            let dummyCell = TerritoryGrid.getCell(for: CLLocationCoordinate2D(latitude: territory.centerLatitude, longitude: territory.centerLongitude))
            return id == dummyCell.id
        }) {
            viewModel.selectTerritory(id: rival.id, ownerName: nil, ownerUserId: rival.userId)
            return
        }
    }
}

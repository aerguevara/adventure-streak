import SwiftUI
import MapKit

@available(iOS 17.0, *)
struct MapView17: View {
    @StateObject var viewModel: MapViewModel
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedOwnerName: String?
    
    var body: some View {
        ZStack {
            MapReader { proxy in
                Map(position: $position) {
                    UserAnnotation()
                    
                    ForEach(viewModel.conqueredTerritories) { cell in
                        MapPolygon(coordinates: TerritoryGrid.polygon(for: cell))
                            .foregroundStyle(Color.green.opacity(0.4))
                            .stroke(Color.green, lineWidth: 1)
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .onMapCameraChange { context in
                    viewModel.updateVisibleRegion(context.region)
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
                
                if let owner = selectedOwnerName {
                    VStack(spacing: 6) {
                        Text("Dueño del territorio")
                            .font(.footnote)
                            .foregroundColor(.primary)
                        Text(owner)
                            .font(.headline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                    }
                    .padding(.bottom, 12)
                }
                
                if viewModel.isTracking {
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
                } else {
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
            }
        }
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00"
    }
    
    private func selectOwner(at coordinate: CLLocationCoordinate2D) {
        // Check local cells (axis-aligned square, bounding box is enough)
        if let cell = viewModel.conqueredTerritories.first(where: { cell in
            let poly = TerritoryGrid.polygon(for: cell)
            guard let minLat = poly.map(\.latitude).min(),
                  let maxLat = poly.map(\.latitude).max(),
                  let minLon = poly.map(\.longitude).min(),
                  let maxLon = poly.map(\.longitude).max() else { return false }
            return coordinate.latitude >= minLat && coordinate.latitude <= maxLat &&
                   coordinate.longitude >= minLon && coordinate.longitude <= maxLon
        }) {
            selectedOwnerName = cell.ownerDisplayName ?? cell.ownerUserId ?? "Sin dueño"
            return
        }
        
        // Rivals: match by polygon id
        if let rival = viewModel.otherTerritories.first(where: { territory in
            guard let id = territory.id else { return false }
            let dummyCell = TerritoryGrid.getCell(for: CLLocationCoordinate2D(latitude: territory.centerLatitude, longitude: territory.centerLongitude))
            return id == dummyCell.id
        }) {
            selectedOwnerName = rival.userId
            return
        }
        
        selectedOwnerName = nil
    }
}

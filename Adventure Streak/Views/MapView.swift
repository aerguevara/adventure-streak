import SwiftUI
import MapKit

struct MapView: View {
    @StateObject var viewModel: MapViewModel
    
    var body: some View {
        ZStack {
            Map(position: $viewModel.position) {
                UserAnnotation()
                
                // NEW: Multiplayer - Rival Territories (Orange Boxes)
                ForEach(viewModel.otherTerritories) { territory in
                    let polygonCoords = territory.boundary.map { $0.coordinate }
                    
                    if polygonCoords.count >= 3 {
                        MapPolygon(coordinates: polygonCoords)
                            .stroke(Color.orange, lineWidth: 1)
                            .foregroundStyle(Color.orange.opacity(0.3))
                    }
                }
                
                // Local User Territories (Green Boxes)
                ForEach(viewModel.conqueredTerritories) { cell in
                    let polygonCoords = cell.boundary.map { $0.coordinate }
                    
                    // Validate polygon (must have at least 3 points)
                    if polygonCoords.count >= 3 {
                        MapPolygon(coordinates: polygonCoords)
                            .stroke(Color.green, lineWidth: 1)
                            .foregroundStyle(Color.green.opacity(0.5))
                    }
                }
                
                // Activity Routes (Restored as requested)
                ForEach(viewModel.activities) { activity in
                    if !activity.route.isEmpty {
                        MapPolyline(coordinates: activity.route.map { $0.coordinate })
                            .stroke(color(for: activity), lineWidth: 4)
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
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
                
                // Manual tracking UI removed as requested. Activities are imported from Fitness.
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
    
    func color(for activity: ActivitySession) -> Color {
        // Generate a consistent color based on the activity ID
        let hash = activity.id.hashValue
        let colors: [Color] = [.red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown]
        let index = abs(hash) % colors.count
        return colors[index]
    }
}

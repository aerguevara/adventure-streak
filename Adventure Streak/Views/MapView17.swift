import SwiftUI
import MapKit

@available(iOS 17.0, *)
struct MapView17: View {
    @StateObject var viewModel: MapViewModel
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    
    var body: some View {
        ZStack {
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
}

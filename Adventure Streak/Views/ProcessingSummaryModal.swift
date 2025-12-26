
import SwiftUI
import MapKit

struct ProcessingSummaryModal: View {
    let summary: GlobalImportSummary
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Spacer()
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        Text("Resumen de Actividad")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        // Rarity Badge
                        if summary.highestRarity != "Común" {
                            Text(summary.highestRarity.uppercased())
                                .font(.caption)
                                .fontWeight(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(rarityColor(summary.highestRarity))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                        }
                    }
                    
                    // Mini Map
                    if !summary.territoryPolygons.isEmpty {
                        MiniMapSummaryView(routes: summary.routeCoordinates, territories: summary.territoryPolygons)
                            .frame(height: 200)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    
                    // Main Stats HGrid (Compact)
                    HStack(spacing: 12) {
                        ExpandedStatBox(title: "XP Ganado", value: "\(summary.totalXP)", icon: "star.fill", color: .yellow)
                        ExpandedStatBox(title: "Territorios", value: "+\(summary.totalNewTerritories)", icon: "flag.fill", color: .green)
                    }
                    .padding(.horizontal)
                    
                    // Missions
                    if !summary.completedMissions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Misiones Completadas")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ForEach(summary.completedMissions, id: \.name) { mission in
                                HStack {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(Color(hex: "FACC15")) // Gold
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading) {
                                        Text(mission.name)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        Text(mission.description)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Stolen Stats
                    if summary.totalStolen > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "flag.slash.fill")
                                    .foregroundColor(.red)
                                Text("Territorios Robados: \(summary.totalStolen)")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            
                            if !summary.stolenVictims.isEmpty {
                                Text("Víctimas:")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                ForEach(Array(summary.stolenVictims), id: \.self) { victim in
                                    HStack {
                                        Image(systemName: "person.crop.circle")
                                        Text(victim)
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.red.opacity(0.8))
                                }
                            }
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Locations
                    if !summary.locations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Lugares Visitados")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ForEach(summary.locations, id: \.self) { loc in
                                HStack {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundColor(.blue)
                                    Text(loc)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                    
                    // Subtle Details
                    Text("Procesado: \(summary.processedCount) actividades")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.top)
                }
                .padding()
            }
        }
    }
    func rarityColor(_ rarity: String) -> Color {
        switch rarity {
        case "Épica": return Color(hex: "C084FC") // Purple
        case "Rara": return Color(hex: "4DA8FF") // Blue
        default: return .gray
        }
    }
}


struct ExpandedStatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
    }
}

struct MiniMapSummaryView: UIViewRepresentable {
    let routes: [[CLLocationCoordinate2D]]
    let territories: [[CLLocationCoordinate2D]]
    
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isScrollEnabled = false
        map.isZoomEnabled = false
        map.isUserInteractionEnabled = false
        map.overrideUserInterfaceStyle = .dark
        map.delegate = context.coordinator
        return map
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeOverlays(uiView.overlays)
        
        // Add territories first (bottom layer)
        for boundary in territories {
            let polygon = MKPolygon(coordinates: boundary, count: boundary.count)
            uiView.addOverlay(polygon)
        }
        
        // Add polylines (top layer)
        for route in routes {
            let polyline = MKPolyline(coordinates: route, count: route.count)
            uiView.addOverlay(polyline)
        }
        
        // Fit all content
        var mapRect = MKMapRect.null
        
        // Union routes
        for route in routes {
            let rect = MKPolyline(coordinates: route, count: route.count).boundingMapRect
            mapRect = mapRect.isNull ? rect : mapRect.union(rect)
        }
        
        // Union territories
        for boundary in territories {
            let rect = MKPolygon(coordinates: boundary, count: boundary.count).boundingMapRect
            mapRect = mapRect.isNull ? rect : mapRect.union(rect)
        }
        
        if !mapRect.isNull {
             uiView.setVisibleMapRect(mapRect, edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40), animated: false)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 0.98, green: 0.8, blue: 0.08, alpha: 1.0) // Gold/Yellow
                renderer.lineWidth = 4
                renderer.lineCap = .round
                return renderer
            } else if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.green.withAlphaComponent(0.3)
                renderer.strokeColor = UIColor.green.withAlphaComponent(0.8)
                renderer.lineWidth = 1
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

#if DEBUG
struct ProcessingSummaryModal_Previews: PreviewProvider {
    static var previews: some View {
        // Create mock data
        var summary = GlobalImportSummary()
        summary.processedCount = 1
        summary.totalXP = 250
        summary.totalNewTerritories = 5
        summary.stolenVictims = ["Orco Jefe"]
        summary.locations = ["Parque del Retiro", "Lago Grande"]
        summary.routeCoordinates = [[
            CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038),
            CLLocationCoordinate2D(latitude: 40.4170, longitude: -3.7035),
            CLLocationCoordinate2D(latitude: 40.4172, longitude: -3.7032),
            CLLocationCoordinate2D(latitude: 40.4175, longitude: -3.7030)
        ]]
        summary.highestRarity = "Épica"
        summary.completedMissions = [
            Mission(userId: "preview_user", category: .territorial, name: "Reconquista", description: "Has recuperado 1 territorios perdidos", rarity: .epic)
        ]
        
        return ZStack {
            // Background to better see the modal context
            Color.green.edgesIgnoringSafeArea(.all)
            
            ProcessingSummaryModal(summary: summary, isPresented: .constant(true))
        }
    }
}
#endif


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
                    
                    Text("Resumen de Actividad")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    // Mini Map
                    if !summary.routeCoordinates.isEmpty {
                        MiniMapSummaryView(routes: summary.routeCoordinates)
                            .frame(height: 200)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    
                    // Main Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        SummaryStatBox(title: "XP Ganado", value: "\(summary.totalXP)", icon: "star.fill", color: .yellow)
                        SummaryStatBox(title: "Territorios", value: "+\(summary.totalNewTerritories)", icon: "flag.fill", color: .green)
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
}

struct SummaryStatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct MiniMapSummaryView: View {
    let routes: [[CLLocationCoordinate2D]]
    
    var body: some View {
        Map(coordinateRegion: .constant(region(for: routes)), interactionModes: [])
        // Note: Standard SwiftUI Map doesn't support Polyline overlays easily in iOS 16 without new MapKit SDK or UIKit wrapper.
        // For simplicity in this step, we assume a basic map centered.
        // Ideally we would use the `MapPolyline` from MapKit or a UIKit wrapper.
        // Given constraints, I'll use a Placeholder text if MapKit integration is complex, 
        // OR better: Just show a map centered on the first route start.
        .disabled(true)
    }
    
    func region(for routes: [[CLLocationCoordinate2D]]) -> MKCoordinateRegion {
        guard let firstRoute = routes.first, let firstPoint = firstRoute.first else {
            return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 0, longitude: 0), span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1))
        }
        return MKCoordinateRegion(center: firstPoint, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
    }
}

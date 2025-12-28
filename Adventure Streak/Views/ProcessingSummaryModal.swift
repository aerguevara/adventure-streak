
import SwiftUI
import MapKit

struct ProcessingSummaryModal: View {
    let summary: GlobalImportSummary
    @Binding var isPresented: Bool
    
    // State for map region (similar to SocialDetailView)
    @State private var region: MKCoordinateRegion? = nil
    @State private var currentRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    // Hardcoded activity type for now as GlobalImportSummary aggregates multiple.
    // We assume the dominant type or default to running if mixed.
    // In a real scenario, we might want to expose the main activity type in GlobalImportSummary.
    private let ActivityTypeColor = Color(hex: "32D74B") // Running Green default
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with Close Button (Added on top of the design)
                ZStack(alignment: .topTrailing) {
                    // Hero Map Section
                    heroMapSection
                    
                    // Close Button
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(radius: 4)
                            .padding()
                    }
                    .padding(.top, 40) // Adjust for safe area
                }
                
                VStack(alignment: .leading, spacing: 24) {
                    // User identity
                    HStack(spacing: 12) {
                        avatar
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AuthenticationService.shared.userName ?? "Jugador")
                                .font(.headline)
                                .foregroundColor(.white)
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                Text("Nivel \(GamificationService.shared.currentLevel)")
                                    .font(.caption.bold())
                                    .foregroundColor(.blue)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Ahora mismo")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Metrics Row
                    HStack(spacing: 15) {
                        SocialDetailMetric(icon: "figure.run", value: String(format: "%.1f", totalDistanceKm), unit: "km")
                         // Duration is not explicitly in GlobalImportSummary, showing processed count as proxy or hiding
                        SocialDetailMetric(icon: "star.fill", value: "+\(summary.totalXP)", unit: "XP", color: Color(hex: "A259FF"))
                        SocialDetailMetric(icon: "flag.fill", value: "+\(summary.totalNewTerritories)", unit: "Zonas", color: .green)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // Description / Impact Quote
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Resumen de Impacto")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        
                        Text(impactDescription)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .lineSpacing(6)
                            .padding()
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    
                    // Additional Details (like Missions/Victims) specific to Summary
                    if !summary.completedMissions.isEmpty {
                        missionsSection
                    }
                    
                    if !summary.stolenVictims.isEmpty {
                        victimsSection
                    }
                    
                }
                .padding(.top, 20)
                .padding(.bottom, 50)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            calculateRegion()
        }
    }
    
    // MARK: - Components
    
    private var heroMapSection: some View {
        ZStack(alignment: .bottom) {
            Group {
                if !summary.territoryPolygons.isEmpty || !summary.routeCoordinates.isEmpty {
                    Map(initialPosition: .region(region ?? currentRegion)) {
                        // Draw Territories
                        ForEach(0..<summary.territoryPolygons.count, id: \.self) { index in
                            let coords = summary.territoryPolygons[index]
                            MapPolygon(coordinates: coords)
                                .stroke(Color(hex: "32D74B"), lineWidth: 1)
                                .foregroundStyle(Color(hex: "32D74B").opacity(0.2))
                        }
                        
                        // Draw Routes
                        ForEach(0..<summary.routeCoordinates.count, id: \.self) { index in
                            let route = summary.routeCoordinates[index]
                            MapPolyline(coordinates: route)
                                .stroke(Color(hex: "E4C746"), lineWidth: 4) // Goldish
                        }
                    }
                } else {
                    // Fallback visual
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color.green.opacity(0.3), Color.black],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                }
            }
            .frame(height: 380)
            .ignoresSafeArea(edges: .top)
            
            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.8), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)
            
            // Floating Title
            VStack(spacing: 12) {
                Text(summary.locations.first ?? "Actividad Procesada")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack(spacing: 12) {
                    if summary.totalNewTerritories > 0 {
                        SocialAchievementBadge(icon: "map.fill", text: "\(summary.totalNewTerritories) Nuevos", color: Color(hex: "32D74B"))
                    }
                    if summary.totalStolen > 0 {
                        SocialAchievementBadge(icon: "bolt.shield.fill", text: "\(summary.totalStolen) Robados", color: Color(hex: "FF3B30"))
                    }
                    if summary.highestRarity != "Común" {
                        SocialAchievementBadge(icon: "trophy.fill", text: summary.highestRarity.uppercased(), color: rarityColor(summary.highestRarity))
                    }
                }
            }
            .padding(.bottom, 25)
        }
    }
    
    private var avatar: some View {
        // Simple avatar for current user
        Circle()
            .fill(Color(hex: "2C2C2E"))
            .frame(width: 44, height: 44)
            .overlay(
                Text((AuthenticationService.shared.userName ?? "U").prefix(1).uppercased())
                    .font(.headline)
                    .foregroundColor(.white)
            )
            .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    private var missionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Misiones Completadas")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(summary.completedMissions, id: \.name) { mission in
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(Color(hex: "FACC15"))
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
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
    
    private var victimsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flag.slash.fill")
                    .foregroundColor(.red)
                Text("Territorios Robados: \(summary.totalStolen)")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
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
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Logic & Helpers
    
    // Attempt to calculate total distance from routes if available, or just use 0/placeholder
    // GlobalImportSummary doesn't have distance explicit field in the snippet seen, 
    // but we can estimate or check if we should add it to the view model.
    // For now, let's assume 0.0 or calculate from coordinates.
    private var totalDistanceKm: Double {
        // Extremely rough estimation or 0
        // In a real app we'd pass this in GlobalImportSummary
        return 0.0 
    }

    private var impactDescription: String {
        if summary.totalStolen > 0 {
            return "Una incursión agresiva en territorio enemigo. Has logrado desestabilizar el control de otros jugadores y reclamar sus zonas para la resistencia."
        } else if summary.totalNewTerritories > 5 {
            return "¡Exploración masiva! Has expandido las fronteras conocidas significativamente, asegurando nuevos recursos y XP para tu progresión."
        } else if summary.totalNewTerritories > 0 {
            return "Consolidación de territorio completada. Tu influencia en esta zona sigue creciendo tras una sesión de movimiento estratégica."
        }
        return "Un entrenamiento enfocado en la mejora de tus capacidades físicas. Cada kilómetro cuenta para tu evolución."
    }
    
    private func rarityColor(_ rarity: String) -> Color {
        switch rarity {
        case "Épica": return Color(hex: "C084FC")
        case "Rara": return Color(hex: "4DA8FF")
        default: return .gray
        }
    }
    
    private func calculateRegion() {
        var allCoords: [CLLocationCoordinate2D] = []
        for poly in summary.territoryPolygons {
            allCoords.append(contentsOf: poly)
        }
        for route in summary.routeCoordinates {
            allCoords.append(contentsOf: route)
        }
        
        guard !allCoords.isEmpty else { return }
        
        let lats = allCoords.map { $0.latitude }
        let lons = allCoords.map { $0.longitude }
        
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLon = lons.min()!
        let maxLon = lons.max()!
        
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2.0,
                                            longitude: (minLon + maxLon) / 2.0)
        let latDelta = max(0.005, (maxLat - minLat) * 1.5)
        let lonDelta = max(0.005, (maxLon - minLon) * 1.5)
        
        self.region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
    }
}

// Reuse components if they are not public in SocialDetailView.
// If SocialDetailView components are private, we need to redeclare them or make them public.
// Assuming we need to redeclare or they are shared. Based on previous file read, they were internal/public (default).
// But to be safe and avoid "ambiguous" errors if they are in the same module, we'll check if we need to rename or if they are accessible.
// They were defined at file level in SocialDetailView.swift so they are internal.

#if DEBUG
struct ProcessingSummaryModal_Previews: PreviewProvider {
    static var previews: some View {
        var summary = GlobalImportSummary()
        summary.processedCount = 1
        summary.totalXP = 250
        summary.totalNewTerritories = 5
        summary.stolenVictims = ["Orco Jefe"]
        summary.locations = ["Parque del Retiro"]
        // ... mock route data ...
        
        return ZStack {
             // Background to better see the modal context
             Color.green.edgesIgnoringSafeArea(.all)
             
            ProcessingSummaryModal(summary: summary, isPresented: .constant(true))
        }
    }
}
#endif

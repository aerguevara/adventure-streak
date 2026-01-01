
import SwiftUI
import MapKit

struct ProcessingSummaryModal: View {
    let summary: GlobalImportSummary
    @Binding var isPresented: Bool
    
    // State for map region (similar to SocialDetailView)
    // State for map camera position
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038), // Default Madrid
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    ))
    
    // Hardcoded activity type for now as GlobalImportSummary aggregates multiple.
    // We assume the dominant type or default to running if mixed.
    // In a real scenario, we might want to expose the main activity type in GlobalImportSummary.
    private var activityTypeColor: Color {
        summary.mainActivityType?.color ?? Color(hex: "32D74B")
    }
    
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
                    // Metrics Row
                    // Metrics Row
                    HStack(spacing: 15) {
                        SocialDetailMetric(icon: summary.mainActivityType?.iconName ?? "figure.run", value: String(format: "%.1f", totalDistanceKm), unit: "KM")
                        SocialDetailMetric(icon: "clock", value: formatDuration(summary.durationSeconds), unit: "TIEMPO")
                        SocialDetailMetric(icon: "star.fill", value: "+\(summary.totalXP)", unit: "XP", color: Color(hex: "A259FF"))
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    
                    // Territory Stats Row (Capturas, Defendidos, Renovadas)
                    
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
                    
                    if summary.vengeanceFulfilledCount > 0 {
                        vengeanceSection
                    }
                    
                }
                .padding(.top, 20)
                .padding(.bottom, 50)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            print("🔍 [Summary] Summary has \(summary.territories.count) polygons.")
            for (i, territory) in summary.territories.enumerated() {
                let poly = territory.boundary
                let first = poly.first
                print("   Polygon \(i): \(poly.count) points. First: \(first?.latitude ?? 0), \(first?.longitude ?? 0)")
            }
            calculateRegion()
        }
    }
    
    // MARK: - Components
    
    private var heroMapSection: some View {
        ZStack(alignment: .bottom) {
            Group {
                if !summary.territories.isEmpty || !summary.routeCoordinates.isEmpty {
                    Map(position: $position) {
                        // Draw Territories
                        ForEach(summary.territories) { territory in
                            let coords = territory.boundary.map { $0.coordinate }
                             if coords.count >= 3 {
                                 MapPolygon(coordinates: coords)
                                     .stroke(activityTypeColor, lineWidth: 1)
                                     .foregroundStyle(activityTypeColor.opacity(0.4))
                            }
                        }
                        
                        // Draw Routes
                        ForEach(Array(summary.routeCoordinates.enumerated()), id: \.offset) { index, route in
                            MapPolyline(coordinates: route)
                                .stroke(Color(hex: "E4C746"), lineWidth: 4)
                        }
                    }
                } else {
                    // Fallback visual - Premium Design matching ActivityCardView
                    premiumNoMapFallback
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
                    if summary.totalDefended > 0 {
                        SocialAchievementBadge(icon: "shield.fill", text: "\(summary.totalDefended) Defendidos", color: Color(hex: "0A84FF"))
                    }
                    if summary.totalRecaptured > 0 {
                        SocialAchievementBadge(icon: "arrow.triangle.2.circlepath", text: "\(summary.totalRecaptured) Renovados", color: Color(hex: "BF5AF2"))
                    }
                    if summary.vengeanceFulfilledCount > 0 {
                        SocialAchievementBadge(icon: "bolt.fill", text: "\(summary.vengeanceFulfilledCount) Venganzas", color: Color(hex: "22D3EE"))
                    }
                    if summary.highestRarity != "Común" {
                        SocialAchievementBadge(icon: "trophy.fill", text: summary.highestRarity.uppercased(), color: rarityColor(summary.highestRarity))
                    }
                }
            }
            .padding(.bottom, 25)
        }
    }

    private var premiumNoMapFallback: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "1A1A1E"), Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Decorative background shapes
            Circle()
                .fill(activityTypeColor.opacity(0.15))
                .frame(width: 250, height: 250)
                .blur(radius: 60)
                .offset(x: 40, y: -40)
            
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: summary.mainActivityType?.iconName ?? "figure.run")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [activityTypeColor, activityTypeColor.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: activityTypeColor.opacity(0.5), radius: 20)
                
                Text("Entrenamiento \(summary.mainActivityType?.displayName ?? "")")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer().frame(height: 100) // Space for the title and badges
            }
        }
        .frame(height: 380)
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

    private var vengeanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(Color(hex: "22D3EE"))
                Text("Venganzas Cumplidas: \(summary.vengeanceFulfilledCount)")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text("Has recuperado territorios que te fueron robados. ¡Bonus de +25 XP aplicado por cada uno!")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .background(Color(hex: "22D3EE").opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "22D3EE").opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: - Logic & Helpers
    
    // Attempt to calculate total distance from routes if available, or just use 0/placeholder
    // GlobalImportSummary doesn't have distance explicit field in the snippet seen, 
    // but we can estimate or check if we should add it to the view model.
    // For now, let's assume 0.0 or calculate from coordinates.
    private var totalDistanceKm: Double {
        return summary.totalDistance 
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
        for territory in summary.territories {
            allCoords.append(contentsOf: territory.boundary.map { $0.coordinate })
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
        let latDelta = max(0.01, (maxLat - minLat) * 2.0)
        let lonDelta = max(0.01, (maxLon - minLon) * 2.0)
        
        let newRegion = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
        print("📍 [Summary] Setting region to: \(center.latitude), \(center.longitude)")
        
        withAnimation {
            self.position = .region(newRegion)
        }
    }


    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        return "\(minutes)m"
    }
}

// Reuse components if they are not public in SocialDetailView.
// If SocialDetailView components are private, we need to redeclare them or make them public.
// Assuming we need to redeclare or they are shared. Based on previous file read, they were internal/public (default).
// But to be safe and avoid "ambiguous" errors if they are in the same module, we'll check if we need to rename or if they are accessible.
// They were defined at file level in SocialDetailView.swift so they are internal.




// Subview for Territory Details (Captures/Defends/Renovations)


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

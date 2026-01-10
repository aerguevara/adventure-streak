import SwiftUI
import MapKit

struct SocialPostDetailView: View {
    let post: SocialPost
    @State private var territoryCells: [TerritoryCell] = []
    @State private var isLoadingTerritories = false
    @State private var region: MKCoordinateRegion? = nil
    
    // Initial standard region for empty state
    @State private var currentRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero Map Section
                ZStack(alignment: .bottom) {
                    Group {
                        if isLoadingTerritories {
                            Rectangle()
                                .fill(Color.white.opacity(0.05))
                                .overlay(ProgressView().tint(.white))
                        } else if !territoryCells.isEmpty {
                            Map(initialPosition: .region(region ?? currentRegion)) {
                                ForEach(territoryCells) { cell in
                                    let coords = cell.boundary.map { $0.coordinate }
                                    if coords.count >= 3 {
                                        MapPolygon(coordinates: coords)
                                            .stroke(Color(hex: "32D74B"), lineWidth: 1)
                                            .foregroundStyle(Color(hex: "32D74B").opacity(0.2))
                                    } else {
                                        Marker("", coordinate: cell.centerCoordinate)
                                            .tint(Color(hex: "32D74B"))
                                    }
                                }
                            }
                            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
                        } else {
                            // Fallback for No Map
                            Rectangle()
                                .fill(LinearGradient(
                                    colors: [post.activityData.activityType.color.opacity(0.3), Color.black],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .overlay(
                                    Image(systemName: post.activityData.activityType.iconName)
                                        .font(.system(size: 80))
                                        .foregroundColor(post.activityData.activityType.color)
                                        .blur(radius: 20)
                                        .opacity(0.5)
                                        .overlay(
                                            Image(systemName: post.activityData.activityType.iconName)
                                                .font(.system(size: 80))
                                                .foregroundColor(.white)
                                        )
                                )
                        }
                    }
                    .frame(height: 380)
                    .ignoresSafeArea(edges: .top)
                    
                    // Gradient overlay for readability
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8), .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 180)
                    
                    // Floating Achievement Info
                    VStack(spacing: 12) {
                        Text(post.activityData.locationLabel ?? (post.hasTerritoryImpact ? "Sector Explorado" : post.activityData.activityType.displayName))
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        if post.hasTerritoryImpact {
                            HStack(spacing: 12) {
                                if post.activityData.newZonesCount > 0 {
                                    SocialAchievementBadge(icon: "map.fill", text: "\(post.activityData.newZonesCount) Nuevos", color: Color(hex: "32D74B"))
                                }
                                if post.activityData.stolenZonesCount > 0 {
                                    SocialAchievementBadge(icon: "bolt.shield.fill", text: "\(post.activityData.stolenZonesCount) Robados", color: Color(hex: "FF3B30"))
                                }
                                if post.activityData.recapturedZonesCount > 0 {
                                    SocialAchievementBadge(icon: "arrow.counterclockwise", text: "\(post.activityData.recapturedZonesCount) Recup.", color: Color(hex: "FF9F0A"))
                                }
                                if post.activityData.defendedZonesCount > 0 {
                                    SocialAchievementBadge(icon: "shield.fill", text: "\(post.activityData.defendedZonesCount) Def.", color: Color(hex: "4C6FFF"))
                                }
                            }
                        } else {
                            HStack(spacing: 8) {
                                SocialAchievementBadge(icon: post.activityData.activityType.iconName, 
                                                       text: "Entrenamiento de \(post.activityData.activityType.displayName)", 
                                                       color: post.activityData.activityType.color)
                                
                                if post.activityData.activityType.isOutdoor {
                                    SocialAchievementBadge(icon: "map", text: "Sin Impacto Territorial", color: .secondary)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 25)
                }
                
                VStack(alignment: .leading, spacing: 24) {
                    // User identity
                    HStack(spacing: 12) {
                        avatar
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.user.displayName)
                                .font(.headline)
                                .foregroundColor(.white)
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                Text("Nivel \(post.user.level)")
                                    .font(.caption.bold())
                                    .foregroundColor(.blue)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(timeAgo(from: post.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatAbsoluteDate(post.date))
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                    }
                    .padding(.horizontal)
                    
                    // Metrics Row
                    HStack(spacing: 15) {
                        SocialDetailMetric(icon: "figure.run", value: String(format: "%.1f", post.activityData.distanceKm), unit: "km")
                        SocialDetailMetric(icon: "clock", value: formatDuration(post.activityData.durationSeconds), unit: "")
                        SocialDetailMetric(icon: "star.fill", value: "+\(post.activityData.xpEarned)", unit: "XP", color: Color(hex: "A259FF"))
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
                    
                    // Missions Section
                    if !missionNames.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Misiones Completadas")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            
                            let columns = [GridItem(.adaptive(minimum: 120), spacing: 10, alignment: .leading)]
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                                ForEach(missionNames, id: \.self) { mission in
                                    Text(mission)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white.opacity(0.9))
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.08))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                                )
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 50)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await loadTerritories() }
    }
    
    private var impactDescription: String {
        if post.hasTerritoryImpact {
            if post.activityData.stolenZonesCount > 0 {
                return "Una incursión agresiva en territorio enemigo. Has logrado desestabilizar el control de otros jugadores y reclamar sus zonas para la resistencia."
            } else if post.activityData.newZonesCount > 5 {
                return "¡Exploración masiva! Has expandido las fronteras conocidas significativamente, asegurando nuevos recursos y XP para tu progresión."
            } else if post.activityData.defendedZonesCount > 0 {
                return "Defensa impecable. Has patrullado tus dominios y reforzado tu soberanía frente a posibles incursiones rivales."
            }
            return "Consolidación de territorio completada. Tu influencia en esta zona sigue creciendo tras una sesión de movimiento estratégica."
        }
        return "Un entrenamiento enfocado en la mejora de tus capacidades físicas. Cada kilómetro cuenta para tu evolución y preparación para la próxima gran conquista."
    }

    // MARK: Helpers
    private func loadTerritories() async {
        guard let activityId = post.activityId else { return }
        isLoadingTerritories = true
        let cells = await ActivityRepository.shared.fetchTerritoriesForActivity(activityId: activityId)
        await MainActor.run {
            territoryCells = cells
            if let newRegion = calculateRegion(for: cells) {
                region = newRegion
            }
            isLoadingTerritories = false
        }
    }
    
    private func calculateRegion(for cells: [TerritoryCell]) -> MKCoordinateRegion? {
        guard let first = cells.first else { return nil }
        let lats = cells.map { $0.centerLatitude }
        let lons = cells.map { $0.centerLongitude }
        let minLat = lats.min() ?? first.centerLatitude
        let maxLat = lats.max() ?? first.centerLatitude
        let minLon = lons.min() ?? first.centerLongitude
        let maxLon = lons.max() ?? first.centerLongitude
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2.0,
                                            longitude: (minLon + maxLon) / 2.0)
        let latDelta = max(0.01, (maxLat - minLat) * 2.0)
        let lonDelta = max(0.01, (maxLon - minLon) * 2.0)
        let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        return MKCoordinateRegion(center: center, span: span)
    }

    private var avatar: some View {
        Group {
            if let data = post.user.avatarData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let avatarURL = post.user.avatarURL {
                AsyncImage(url: avatarURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
            } else {
                Circle()
                    .fill(Color(hex: "2C2C2E"))
                    .overlay(
                        Text(post.user.displayName.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func formatAbsoluteDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }

    private var missionNames: [String] {
        guard let subtitle = post.eventSubtitle else { return [] }
        let cleaned = subtitle
            .replacingOccurrences(of: "Misiones:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Misiones", with: "", options: .caseInsensitive)
        let separators: CharacterSet = ["·", "•", ","]
        let tokens = cleaned
            .components(separatedBy: separators)
            .flatMap { $0.components(separatedBy: "·") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return tokens
            .filter { !$0.isEmpty }
            .filter { token in
                let lower = token.lowercased()
                if lower.contains("nuevas: 0") || lower.contains("defendidas: 0") || lower.contains("recapturadas: 0") {
                    return false
                }
                return !lower.contains("territorio") && !lower.contains("zona") && !lower.contains("conquist")
            }
    }
}

// MARK: - Reusable Hero Components
struct SocialAchievementBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .black))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
    }
}

struct SocialDetailMetric: View {
    let icon: String
    let value: String
    let unit: String
    var color: Color = .white
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color.opacity(0.7))
            
            VStack(spacing: 0) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
            }
            .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

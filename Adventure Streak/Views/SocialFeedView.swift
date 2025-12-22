import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import MapKit

struct SocialFeedView: View {
    @StateObject var viewModel = SocialViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if viewModel.posts.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(viewModel.displayPosts) { post in
                                NavigationLink {
                                    SocialPostDetailView(post: post)
                                } label: {
                                    ActivityCardView(
                                        activity: post,
                                        reactionState: viewModel.reactionState(for: post),
                                        onReaction: { viewModel.react(to: post, with: $0) }
                                    )
                                    .glowPulse(isActive: isMostRecent(post), color: .orange)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationTitle("Actividad Social")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // Check if it's the top post AND recent (<1 hour)
    func isMostRecent(_ post: SocialPost) -> Bool {
        guard let firstPost = viewModel.displayPosts.first else { return false }
        guard post.id == firstPost.id else { return false }
        
        // 1 Hour window
        return Date().timeIntervalSince(post.date) < 3600
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
            .font(.system(size: 50))
            .foregroundColor(.gray)
            Text("No hay actividad reciente")
            .font(.headline)
            .foregroundColor(.white)
            Text("Sigue a otros aventureros para ver su progreso aquí.")
            .font(.subheadline)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
        }
    }
}

struct SocialPostCard: View {
    let post: SocialPost
    let reactionState: ActivityReactionState
    let onReaction: (ReactionType) -> Void

    @State private var pendingReaction: ReactionType? = nil

    private var title: String {
        let placeName = post.activityData.locationLabel ?? translateActivityType(post.activityData.activityType.rawValue)
        let xpString = "+\(post.activityData.xpEarned) XP"
        
        if post.activityData.defendedZonesCount > 0 {
            return "Defensa completada en \(placeName) · \(xpString)"
        } else if post.activityData.recapturedZonesCount > 0 {
            return "Reconquista completada en \(placeName) · \(xpString)"
        } else if post.activityData.newZonesCount > 0 {
            return "Conquista completada en \(placeName) · \(xpString)"
        } else {
            // Actividad normal
            // Si tenemos nombre de lugar, usamos "Actividad en Lugar"
            // Si solo es el tipo (placeName == Correr), se queda como estaba
            if post.activityData.locationLabel != nil {
               return "\(translateActivityType(post.activityData.activityType.rawValue)) en \(placeName) · \(xpString)"
            } else {
               return "\(placeName) · \(xpString)"
            }
        }
    }
    
    // Helper to translate activity type
    private func translateActivityType(_ raw: String) -> String {
        switch raw.lowercased() {
        case "run", "running": return "Correr"
        case "walk", "walking": return "Caminar"
        case "bike", "cycling": return "Ciclismo"
        case "hike", "hiking": return "Senderismo"
        case "workout": return "Entrenamiento"
        case "yoga": return "Yoga"
        case "pilates": return "Pilates"
        case "hiit": return "HIIT"
        default: return raw.capitalized
        }
    }

    private var userReaction: ReactionType? {
        reactionState.currentUserReaction ?? pendingReaction
    }

    var body: some View {
        let style = impactStyle

        VStack(alignment: .leading, spacing: style.verticalSpacing) {
            if let banner = style.banner {
                impactBanner(for: banner)
            }

            header
                .padding(.top, style.headerTopPadding)

            metricsSection

            zonesBadge

            reactionsRow
        }
        .padding(.vertical, style.verticalPadding)
        .padding(.horizontal, 14)
        .background(style.background)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(style.borderColor, lineWidth: style.borderWidth)
                .shadow(color: style.glowColor, radius: style.glowRadius)
        )
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.35), radius: 12, y: 8)
        .padding(.horizontal, 12)
        .onChangeCompat(of: reactionState.currentUserReaction) {
            pendingReaction = nil
        }
    }

    private func impactBanner(for banner: ImpactBanner) -> some View {
        HStack(spacing: 10) {
            Text(banner.icon)
                .font(.headline)
            Text(banner.title)
                .font(.subheadline.bold())
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(banner.background.opacity(0.25))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(banner.background.opacity(0.6), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(post.user.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    levelBadge
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                    if let subtitle = post.eventSubtitle, post.impactLevel == .high {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(2)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(timeAgo(from: post.date))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text(formatAbsoluteDate(post.date))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    private var metricsSection: some View {
        HStack(spacing: 12) {
            metric(icon: "figure.run", label: "Distancia", value: String(format: "%.1f km", post.activityData.distanceKm))
            metric(icon: "clock", label: "Tiempo", value: formatDuration(post.activityData.durationSeconds))
            metric(icon: "star.fill", label: "XP", value: "+\(post.activityData.xpEarned)", valueColor: Color(hex: "A259FF"))
        }
        .padding(10)
        .background(Color(hex: "2C2C2E").opacity(0.6))
        .cornerRadius(12)
    }

    private var zonesBadge: some View {
        Group {
            if post.activityData.newZonesCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.white)
                    Text("+\(post.activityData.newZonesCount) zonas conquistadas")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color(hex: "32D74B").opacity(0.85))
                .cornerRadius(10)
            }
        }
    }

    private var reactionsRow: some View {
        HStack(spacing: 10) {
            ForEach(ReactionType.allCases, id: \.self) { reaction in
                reactionButton(for: reaction)
            }
            Spacer()
        }
        .padding(.top, 2)
    }

    private func reactionButton(for reaction: ReactionType) -> some View {
        let isSelected = userReaction == reaction
        // Allow changing reaction, disable only if processing or no activityId
        let disabled = post.activityId == nil
        let count = reactionCount(for: reaction)

        return Button {
            guard !disabled else { return }
            // If selecting the same one, maybe toggle off? (For now, just return or re-apply)
            if userReaction == reaction { return } 
            handleReaction(reaction)
        } label: {
            HStack(spacing: 6) {
                Text(reaction.emoji)
                    .font(.headline)
                Text("\(count)")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(height: 34)
            .padding(.horizontal, 10)
            .background(buttonBackground(isSelected: isSelected))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(buttonStroke(isSelected: isSelected), lineWidth: 1)
            )
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func handleReaction(_ reaction: ReactionType) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            pendingReaction = reaction
        }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        onReaction(reaction)
    }

    private func buttonBackground(isSelected: Bool) -> Color {
        isSelected ? Color(hex: "4C6FFF").opacity(0.35) : Color.white.opacity(0.08)
    }

    private func buttonStroke(isSelected: Bool) -> Color {
        isSelected ? Color(hex: "4C6FFF") : Color.white.opacity(0.12)
    }

    private func reactionCount(for reaction: ReactionType) -> Int {
        var base: Int
        switch reaction {
        case .fire: base = reactionState.fireCount
        case .trophy: base = reactionState.trophyCount
        case .devil: base = reactionState.devilCount
        }

        if pendingReaction == reaction && reactionState.currentUserReaction == nil {
            base += 1
        }
        return base
    }

    private var avatar: some View {
        Group {
            if let data = post.user.avatarData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let avatarURL = post.user.avatarURL {
                AsyncImage(url: avatarURL) { image in
                    image.resizable()
                } placeholder: {
                    Circle().fill(Color(hex: "2C2C2E"))
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
    }

    private var levelBadge: some View {
        Text("Lv \(post.user.level)")
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: "4C6FFF").opacity(0.8))
            .cornerRadius(8)
    }

    private func metric(icon: String, label: String, value: String, valueColor: Color = .white) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(valueColor)
            }
        }
        .frame(maxWidth: .infinity)
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

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatAbsoluteDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var impactStyle: ImpactStyle {
        switch post.impactLevel {
        case .high:
            return ImpactStyle(
                background: Color(hex: "18181C"),
                borderColor: Color(hex: "4C6FFF").opacity(0.8),
                borderWidth: 1.2,
                glowColor: Color(hex: "4C6FFF").opacity(0.35),
                glowRadius: 10,
                verticalPadding: 16,
                verticalSpacing: 12,
                headerTopPadding: 4,
                banner: impactBannerContent
            )
        case .medium:
            return ImpactStyle(
                background: Color(hex: "18181C"),
                borderColor: Color.white.opacity(0.06),
                borderWidth: 1,
                glowColor: Color.clear,
                glowRadius: 0,
                verticalPadding: 14,
                verticalSpacing: 10,
                headerTopPadding: 2,
                banner: nil
            )
        case .low:
            return ImpactStyle(
                background: Color(hex: "0F0F10"),
                borderColor: Color.white.opacity(0.04),
                borderWidth: 1,
                glowColor: Color.clear,
                glowRadius: 0,
                verticalPadding: 10,
                verticalSpacing: 8,
                headerTopPadding: 0,
                banner: nil
            )
        }
    }

    private var impactBannerContent: ImpactBanner? {
        if post.hasTerritoryImpact {
            if post.activityData.recapturedZonesCount > 0 || post.activityData.defendedZonesCount > 0 {
                return ImpactBanner(icon: "🔥", title: "Defensa de territorio completada", background: Color(hex: "FF9F0A"))
            }
            return ImpactBanner(icon: "🗺", title: "Nueva zona conquistada", background: Color(hex: "32D74B"))
        }
        if post.eventType == .distanceRecord {
            return ImpactBanner(icon: "🏆", title: "Récord personal", background: Color(hex: "FFD60A"))
        }
        if let title = post.eventTitle, !title.isEmpty {
            return ImpactBanner(icon: "🏆", title: title, background: Color(hex: "4C6FFF"))
        }
        if post.hasSignificantXP {
            return ImpactBanner(icon: "🔥", title: "Impacto alto en XP", background: Color(hex: "4C6FFF"))
        }
        return nil
    }
}

private extension View {
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, action: @escaping () -> Void) -> some View {
        if #available(iOS 17, *) {
            onChange(of: value) { _, _ in action() }
        } else {
            onChange(of: value) { _ in action() }
        }
    }
}

private struct ImpactStyle {
    let background: Color
    let borderColor: Color
    let borderWidth: CGFloat
    let glowColor: Color
    let glowRadius: CGFloat
    let verticalPadding: CGFloat
    let verticalSpacing: CGFloat
    let headerTopPadding: CGFloat
    let banner: ImpactBanner?
}

private struct ImpactBanner {
    let icon: String
    let title: String
    let background: Color
}

struct SocialPostDetailView: View {
    let post: SocialPost
    @State private var territoryCells: [TerritoryCell] = []
    @State private var isLoadingTerritories = false
    @State private var region: MKCoordinateRegion? = nil
    
    private var detailTitle: String {
        let typeName = post.activityData.locationLabel ?? post.activityData.activityType.rawValue.capitalized
        return "\(typeName) completada · +\(post.activityData.xpEarned) XP"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                metricsCard
                territoryCard
                miniMap
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Detalle de actividad")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadTerritories() }
    }
    
    // MARK: Sections
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(post.user.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    levelBadge
                }
                Text(detailTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeAgo(from: post.date))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text(formatAbsoluteDate(post.date))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(14)
        .background(Color(hex: "18181C"))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.3), radius: 10, y: 6)
    }
    
    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Métricas")
                .font(.headline)
                .foregroundColor(.white)
            HStack(spacing: 12) {
                metric(icon: "figure.run", label: "Distancia", value: String(format: "%.1f km", post.activityData.distanceKm))
                metric(icon: "clock", label: "Tiempo", value: formatDuration(post.activityData.durationSeconds))
                metric(icon: "star.fill", label: "XP", value: "+\(post.activityData.xpEarned)", valueColor: Color(hex: "A259FF"))
            }
        }
        .padding(14)
        .background(Color(hex: "18181C"))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.3), radius: 10, y: 6)
    }
    
    private var territoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Territorios")
                .font(.headline)
                .foregroundColor(.white)
            HStack(spacing: 10) {
                territoryBadge(color: "32D74B", title: "Nuevas", value: post.activityData.newZonesCount)
                territoryBadge(color: "4C6FFF", title: "Defendidas", value: post.activityData.defendedZonesCount)
                territoryBadge(color: "FF9F0A", title: "Recapturadas", value: post.activityData.recapturedZonesCount)
            }
            if post.activityData.newZonesCount == 0 && post.activityData.defendedZonesCount == 0 && post.activityData.recapturedZonesCount == 0 {
                Text("Sin cambios en territorios en esta sesión.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(14)
        .background(Color(hex: "18181C"))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.3), radius: 10, y: 6)
    }
    
    private var miniMap: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Minimapa de territorios")
                .font(.headline)
                .foregroundColor(.white)
            if isLoadingTerritories {
                HStack {
                    ProgressView().progressViewStyle(.circular)
                    Text("Cargando territorios...")
                        .foregroundColor(.white)
                        .font(.subheadline)
                }
                .padding(.vertical, 10)
            } else if territoryCells.isEmpty {
                Text("Sin territorios asociados a esta actividad.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            } else if let displayedRegion = region {
                Map(initialPosition: .region(displayedRegion)) {
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
                .frame(height: 200)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            } else {
                Text("No se pudo cargar la región del mapa.")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.subheadline)
            }
        }
        .padding(14)
        .background(Color(hex: "18181C"))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.3), radius: 10, y: 6)
    }
    
    // MARK: Helpers
    private func loadTerritories() async {
        guard let activityId = post.activityId else { return }
        isLoadingTerritories = true
        let cells = await ActivityRepository.shared.fetchTerritoriesForActivity(activityId: activityId)
        await MainActor.run {
            territoryCells = cells
            region = region(for: cells)
            isLoadingTerritories = false
        }
    }
    
    private func region(for cells: [TerritoryCell]) -> MKCoordinateRegion? {
        guard let first = cells.first else { return nil }
        let lats = cells.map { $0.centerLatitude }
        let lons = cells.map { $0.centerLongitude }
        let minLat = lats.min() ?? first.centerLatitude
        let maxLat = lats.max() ?? first.centerLatitude
        let minLon = lons.min() ?? first.centerLongitude
        let maxLon = lons.max() ?? first.centerLongitude
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2.0,
                                            longitude: (minLon + maxLon) / 2.0)
        let latDelta = max(0.01, (maxLat - minLat) * 1.8)
        let lonDelta = max(0.01, (maxLon - minLon) * 1.8)
        let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        return MKCoordinateRegion(center: center, span: span)
    }
    
    private func metric(icon: String, label: String, value: String, valueColor: Color = .white) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(valueColor)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func territoryBadge(color: String, title: String, value: Int) -> some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.headline.bold())
                .foregroundColor(.white)
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(hex: color).opacity(0.25))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: color).opacity(0.6), lineWidth: 1)
        )
        .cornerRadius(12)
    }
    
    private var avatar: some View {
        Group {
            if let data = post.user.avatarData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let avatarURL = post.user.avatarURL {
                AsyncImage(url: avatarURL) { image in
                    image.resizable()
                } placeholder: {
                    Circle().fill(Color(hex: "2C2C2E"))
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
        .frame(width: 50, height: 50)
        .clipShape(Circle())
    }
    
    private var levelBadge: some View {
        Text("Lv \(post.user.level)")
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: "4C6FFF").opacity(0.8))
            .cornerRadius(8)
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func formatAbsoluteDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
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
}

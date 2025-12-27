import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ActivityCardView: View {
    let activity: SocialPost
    let reactionState: ActivityReactionState
    let onReaction: (ReactionType) -> Void

    @State private var pendingReaction: ReactionType? = nil
    @State private var territoryCells: [TerritoryCell] = []
    @State private var isLoadingTerritories = false

    private var mergedReactionState: ActivityReactionState {
        var state = reactionState

        if state.swordCount == 0 && state.shieldCount == 0 && state.fireCount == 0 {
            state.swordCount = activity.activityData.swordCount
            state.shieldCount = activity.activityData.shieldCount
            state.fireCount = activity.activityData.fireCount
        }

        if state.currentUserReaction == nil {
            state.currentUserReaction = activity.activityData.currentUserReaction
        }

        return state
    }

    private var narrativeTitle: String {
        let userName = activity.user.displayName
        let location = activity.activityData.locationLabel ?? "una nueva zona"
        let isOutdoor = activity.activityData.activityType.isOutdoor
        
        if activity.activityData.recapturedZonesCount > 0 {
            return "¡\(userName) ha recuperado \(location)!"
        }
        if activity.activityData.stolenZonesCount > 0 {
            return "¡\(userName) ha robado territorios en \(location)!"
        }
        if activity.activityData.newZonesCount > 0 {
            return "¡\(userName) ha descubierto \(location)!"
        }
        if activity.activityData.defendedZonesCount > 0 {
            return "¡\(userName) ha defendido su territorio en \(location)!"
        }
        
        // Default activity
        let activityVerb = translateActivityVerb(activity.activityData.activityType)
        if isOutdoor {
            return "¡\(userName) ha salido a \(activityVerb) por \(location)!"
        } else {
            return "¡\(userName) ha completado un entrenamiento de \(activityVerb)!"
        }
    }

    private func translateActivityVerb(_ type: ActivityType) -> String {
        switch type {
        case .run: return "correr"
        case .walk: return "caminar"
        case .bike: return "rodar"
        case .hike: return "explorar"
        case .indoor: return "Interior"
        case .otherOutdoor: return "entrenar al aire libre"
        }
    }

    private var style: ActivityCardStyle {
        switch activity.impactLevel {
        case .high:
            return ActivityCardStyle(
                background: Color(hex: "18181C"),
                borderColor: Color(hex: "E0AA3E").opacity(0.7),
                borderWidth: 1.2,
                verticalPadding: 14,
                verticalSpacing: 10,
                fadedBackground: Color(hex: "E0AA3E").opacity(0.12)
            )
        case .medium:
            return ActivityCardStyle(
                background: Color(hex: "18181C"),
                borderColor: Color.white.opacity(0.06),
                borderWidth: 1,
                verticalPadding: 12,
                verticalSpacing: 8,
                fadedBackground: Color.white.opacity(0.06)
            )
        case .low:
            return ActivityCardStyle(
                background: Color(hex: "0F0F10"),
                borderColor: Color.white.opacity(0.04),
                borderWidth: 1,
                verticalPadding: 8,
                verticalSpacing: 6,
                fadedBackground: Color.white.opacity(0.03)
            )
        }
    }

    var body: some View {
        let currentStyle = style

        VStack(alignment: .leading, spacing: currentStyle.verticalSpacing) {
            userActivityHeader

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(narrativeTitle)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.trailing, 4)
                    
                    if !missionNames.isEmpty {
                        MissionChipsView(missions: missionNames)
                    }
                }
                
                Spacer()
                
                if hasTerritoryImpact {
                    miniMapThumbnail
                }
            }
            .padding(.vertical, 4)

            metricsSection

            ReactionBarView(
                state: mergedReactionState,
                pendingReaction: pendingReaction,
                isEnabled: activity.activityId != nil,
                onReaction: handleReaction
            )
        }
        .padding(.vertical, currentStyle.verticalPadding)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(currentStyle.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(currentStyle.borderColor, lineWidth: currentStyle.borderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.3), radius: 10, y: 6)
        .padding(.horizontal, 12)
        .task {
            if hasTerritoryImpact && territoryCells.isEmpty {
                await loadTerritories()
            }
        }
    }

    private var miniMapThumbnail: some View {
        ZStack {
            if isLoadingTerritories {
                ProgressView().scaleEffect(0.6)
            } else if !territoryCells.isEmpty {
                TerritoryMinimapView(territories: territoryCells)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
        }
        .frame(width: 80, height: 80)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }

    private func loadTerritories() async {
        guard let activityId = activity.activityId else { return }
        isLoadingTerritories = true
        let cells = await ActivityRepository.shared.fetchTerritoriesForActivity(activityId: activityId)
        await MainActor.run {
            self.territoryCells = cells
            self.isLoadingTerritories = false
        }
    }

    private var userActivityHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            avatar

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(activity.user.displayName)
                        .font(.headline.weight(.bold))
                        .foregroundColor(.primary)
                    levelBadge
                }

                Text(activity.activityData.activityType.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary.opacity(0.8))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(timeAgo(from: activity.date))
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary.opacity(0.6))
                Text(formatAbsoluteDate(activity.date))
                    .font(.caption2)
                    .foregroundColor(.primary.opacity(0.4))
            }
        }
    }

    private var metricsSection: some View {
        HStack(spacing: 8) {
            compactMetric(icon: "figure.run", value: String(format: "%.1f km", activity.activityData.distanceKm))
            compactMetric(icon: "clock", value: formatDuration(activity.activityData.durationSeconds))
            compactMetric(icon: "star.fill", value: "+\(activity.activityData.xpEarned) XP", color: Color(hex: "A259FF"))
            
            Spacer()
            
            if activity.activityData.newZonesCount > 0 {
                Text("+\(activity.activityData.newZonesCount) zonas")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "32D74B").opacity(0.8))
                    .cornerRadius(4)
            }
            if activity.activityData.stolenZonesCount > 0 {
                Text("+\(activity.activityData.stolenZonesCount) robos")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(4)
            }
        }
        .padding(.top, 4)
    }

    private func compactMetric(icon: String, value: String, color: Color = .white.opacity(0.7)) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(value)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }

    private var territoryImpactSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Impacto territorial")
                .font(.caption.weight(.bold))
                .foregroundColor(.primary.opacity(0.65))
            HStack(spacing: 8) {
                if activity.activityData.newZonesCount > 0 {
                    badge(text: "+\(activity.activityData.newZonesCount) zona\(activity.activityData.newZonesCount == 1 ? "" : "s") conquistada\(activity.activityData.newZonesCount == 1 ? "" : "s")", color: "32D74B")
                }
                if activity.activityData.recapturedZonesCount > 0 {
                    badge(text: "\(activity.activityData.recapturedZonesCount) zona\(activity.activityData.recapturedZonesCount == 1 ? "" : "s") recuperada\(activity.activityData.recapturedZonesCount == 1 ? "" : "s")", color: "FF9F0A")
                }
                if activity.activityData.stolenZonesCount > 0 {
                    badge(text: "\(activity.activityData.stolenZonesCount) zona\(activity.activityData.stolenZonesCount == 1 ? "" : "s") robada\(activity.activityData.stolenZonesCount == 1 ? "" : "s")", color: "FF3B30")
                }
                if activity.activityData.defendedZonesCount > 0 {
                    badge(text: "\(activity.activityData.defendedZonesCount) defensa\(activity.activityData.defendedZonesCount == 1 ? "" : "s") completada\(activity.activityData.defendedZonesCount == 1 ? "" : "s")", color: "4C6FFF")
                }
            }
        }
    }

    private func badge(text: String, color: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color(hex: color).opacity(0.9))
            .cornerRadius(10)
    }

    private func metric(icon: String, label: String, value: String, valueColor: Color = .white) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.primary.opacity(0.6))
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(valueColor)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var missionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Misiones")
                .font(.caption.weight(.bold))
                .foregroundColor(.primary.opacity(0.65))
            MissionChipsView(missions: missionNames)
        }
    }

    private var avatar: some View {
        Group {
            if let data = activity.user.avatarData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let avatarURL = activity.user.avatarURL {
                AsyncImage(url: avatarURL) { image in
                    image.resizable()
                } placeholder: {
                    Circle().fill(Color(hex: "2C2C2E"))
                }
            } else {
                Circle()
                    .fill(Color(hex: "2C2C2E"))
                    .overlay(
                        Text(activity.user.displayName.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    private var levelBadge: some View {
        Text("Lv \(activity.user.level)")
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: "4C6FFF").opacity(0.8))
            .cornerRadius(8)
    }


    private func handleReaction(_ reaction: ReactionType) {
        guard activity.activityId != nil else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            pendingReaction = reaction
        }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        onReaction(reaction)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            pendingReaction = nil
        }
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

    private var missionNames: [String] {
        guard let subtitle = activity.eventSubtitle else { return [] }
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
                // Data Hygiene: No renderizar si el valor es 0
                if lower.contains("nuevas: 0") || lower.contains("defendidas: 0") || lower.contains("recapturadas: 0") {
                    return false
                }
                return !lower.contains("territorio") && !lower.contains("zona") && !lower.contains("conquist")
            }
    }


    private var hasTerritoryImpact: Bool {
        activity.activityData.newZonesCount > 0 || activity.activityData.defendedZonesCount > 0 || activity.activityData.recapturedZonesCount > 0 || activity.activityData.stolenZonesCount > 0
    }



}

private struct MissionChipsView: View {
    let missions: [String]

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 72), spacing: 8, alignment: .leading)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(missions, id: \.self) { mission in
                Text(mission)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.primary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.primary.opacity(0.08))
                    .cornerRadius(10)
            }
        }
    }
}

struct ReactionBarView: View {
    let state: ActivityReactionState
    let pendingReaction: ReactionType?
    let isEnabled: Bool
    let onReaction: (ReactionType) -> Void

    private func count(for reaction: ReactionType) -> Int {
        var base: Int
        switch reaction {
        case .sword: base = state.swordCount
        case .shield: base = state.shieldCount
        case .fire: base = state.fireCount
        }

        if pendingReaction == reaction && state.currentUserReaction == nil {
            base += 1
        }
        return base
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ReactionType.allCases, id: \.self) { reaction in
                reactionButton(for: reaction)
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    private func reactionButton(for reaction: ReactionType) -> some View {
        let activeReaction = pendingReaction ?? state.currentUserReaction
        let isSelected = activeReaction == reaction
        let total = count(for: reaction)

        return Button {
            guard isEnabled else { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                onReaction(reaction)
            }
        } label: {
            HStack(spacing: 4) {
                Text(reaction.emoji)
                    .font(isSelected ? .headline.weight(.bold) : .subheadline)
                if total > 0 {
                    Text("\(total)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.primary.opacity(0.8))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, isSelected ? 12 : 10)
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: "4C6FFF").opacity(0.2) : Color.primary.opacity(0.06))
            )
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color(hex: "4C6FFF") : Color.primary.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct ActivityCardStyle {
    let background: Color
    let borderColor: Color
    let borderWidth: CGFloat
    let verticalPadding: CGFloat
    let verticalSpacing: CGFloat
    let fadedBackground: Color
}

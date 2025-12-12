import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ActivityCardView: View {
    let activity: SocialPost
    let reactionState: ActivityReactionState
    let onReaction: (ReactionType) -> Void

    @State private var pendingReaction: ReactionType? = nil

    private var mergedReactionState: ActivityReactionState {
        var state = reactionState

        if state.fireCount == 0 && state.trophyCount == 0 && state.devilCount == 0 {
            state.fireCount = activity.activityData.fireCount
            state.trophyCount = activity.activityData.trophyCount
            state.devilCount = activity.activityData.devilCount
        }

        if state.currentUserReaction == nil {
            state.currentUserReaction = activity.activityData.currentUserReaction
        }

        return state
    }

    private var highImpactTitle: String {
        if activity.activityData.recapturedZonesCount > 0 {
            return "Territorio recapturado"
        }
        if activity.activityData.newZonesCount > 0 {
            return "Zona conquistada"
        }
        if activity.activityData.defendedZonesCount > 0 {
            return "Defensa completada"
        }
        if activity.eventType == .distanceRecord {
            return "Récord personal"
        }
        if activity.hasSignificantXP {
            return "Impacto alto en XP"
        }
        return activity.eventTitle ?? "Actividad destacada"
    }

    private var style: ActivityCardStyle {
        switch activity.impactLevel {
        case .high:
            return ActivityCardStyle(
                background: Color(hex: "18181C"),
                borderColor: Color(hex: "E0AA3E").opacity(0.7),
                borderWidth: 1.2,
                verticalPadding: 18,
                verticalSpacing: 12,
                headerPadding: 6,
                bannerBackground: LinearGradient(
                    colors: [Color(hex: "F2C94C"), Color(hex: "E29500")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                fadedBackground: Color(hex: "E0AA3E").opacity(0.12)
            )
        case .medium:
            return ActivityCardStyle(
                background: Color(hex: "18181C"),
                borderColor: Color.white.opacity(0.06),
                borderWidth: 1,
                verticalPadding: 14,
                verticalSpacing: 10,
                headerPadding: 2,
                bannerBackground: LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                fadedBackground: Color.white.opacity(0.06)
            )
        case .low:
            return ActivityCardStyle(
                background: Color(hex: "0F0F10"),
                borderColor: Color.white.opacity(0.04),
                borderWidth: 1,
                verticalPadding: 10,
                verticalSpacing: 8,
                headerPadding: 0,
                bannerBackground: LinearGradient(
                    colors: [Color.clear, Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                fadedBackground: Color.white.opacity(0.03)
            )
        }
    }

    var body: some View {
        let currentStyle = style

        VStack(alignment: .leading, spacing: currentStyle.verticalSpacing) {
            if showImpactHeader {
                impactHeader(style: currentStyle)
            }

            userActivityHeader
                .padding(.top, currentStyle.headerPadding)

            if !missionNames.isEmpty {
                missionSection
            }

            metricsSection

            if hasTerritoryImpact {
                territoryImpactSection
            }

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
    }

    private var userActivityHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            avatar

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(activity.user.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    levelBadge
                }

                Text("\(activity.activityData.activityType.displayName) · +\(activity.activityData.xpEarned) XP")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(timeAgo(from: activity.date))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text(formatAbsoluteDate(activity.date))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    private var metricsSection: some View {
        Group {
            switch activity.impactLevel {
            case .high, .medium:
                HStack(spacing: 12) {
                    metric(icon: "figure.run", label: "Distancia", value: String(format: "%.1f km", activity.activityData.distanceKm))
                    metric(icon: "clock", label: "Tiempo", value: formatDuration(activity.activityData.durationSeconds))
                    metric(icon: "star.fill", label: "XP", value: "+\(activity.activityData.xpEarned)", valueColor: Color(hex: "A259FF"))
                }
                .padding(10)
                .background(style.fadedBackground)
                .cornerRadius(12)
                if let impactLine = territoryImpactLine {
                    Text(impactLine)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.65))
                        .padding(.horizontal, 2)
                }
            case .low:
                HStack(spacing: 8) {
                    Image(systemName: "figure.run")
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(activity.activityData.activityType.displayName) · \(formatDuration(activity.activityData.durationSeconds))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                    Spacer()
                    Text("+\(activity.activityData.xpEarned) XP")
                        .font(.caption.bold())
                        .foregroundColor(Color(hex: "A259FF"))
                }
                .padding(10)
                .background(style.fadedBackground)
                .cornerRadius(10)
                if let impactLine = territoryImpactLine {
                    Text(impactLine)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.65))
                        .padding(.horizontal, 2)
                }
            }
        }
    }

    private var territoryImpactSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Impacto territorial")
                .font(.caption)
                .foregroundColor(.white.opacity(0.65))
            HStack(spacing: 8) {
                if activity.activityData.newZonesCount > 0 {
                    badge(text: "+\(activity.activityData.newZonesCount) zona\(activity.activityData.newZonesCount == 1 ? "" : "s") conquistada\(activity.activityData.newZonesCount == 1 ? "" : "s")", color: "32D74B")
                }
                if activity.activityData.recapturedZonesCount > 0 {
                    badge(text: "\(activity.activityData.recapturedZonesCount) zona\(activity.activityData.recapturedZonesCount == 1 ? "" : "s") recapturada\(activity.activityData.recapturedZonesCount == 1 ? "" : "s")", color: "FF9F0A")
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
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(valueColor)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var missionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Misiones")
                .font(.caption)
                .foregroundColor(.white.opacity(0.65))
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
        .frame(width: 44, height: 44)
        .clipShape(Circle())
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

    private func impactHeader(style: ActivityCardStyle) -> some View {
        HStack(spacing: 10) {
            Text("🏅")
                .font(.headline)
            VStack(alignment: .leading, spacing: 2) {
                Text(highImpactTitle)
                    .font(.subheadline.bold())
                    .foregroundColor(.black)
                if let subtitle = impactSubtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.black.opacity(0.75))
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(style.bannerBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
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
        formatter.unitsStyle = .abbreviated
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
                return !lower.contains("territorio") && !lower.contains("zona") && !lower.contains("conquist")
            }
    }

    private var showImpactHeader: Bool {
        hasTerritoryImpact || activity.impactLevel == .high
    }

    private var hasTerritoryImpact: Bool {
        activity.activityData.newZonesCount > 0 || activity.activityData.defendedZonesCount > 0 || activity.activityData.recapturedZonesCount > 0
    }

    private var impactSubtitle: String? {
        let recaptured = activity.activityData.recapturedZonesCount
        let newZones = activity.activityData.newZonesCount
        let defended = activity.activityData.defendedZonesCount

        var parts: [String] = []
        if recaptured > 0 {
            parts.append("Has recuperado \(recaptured) zona\(recaptured == 1 ? "" : "s")")
        }
        if newZones > 0 {
            parts.append("y has conquistado \(newZones) nueva\(newZones == 1 ? "" : "s")")
        }
        if defended > 0 {
            let defendedWord = defended == 1 ? "vez" : "veces"
            parts.append("defendiste \(defended) \(defendedWord)")
        }

        let sentence = parts.joined(separator: " ")
        if !sentence.isEmpty { return sentence }
        // Avoid bringing back long "Misiones" text into the header if already parsed for chips
        if missionNames.isEmpty {
            return activity.eventSubtitle
        }
        return nil
    }

    private var territoryImpactLine: String? {
        guard hasTerritoryImpact else { return nil }
        if activity.activityData.recapturedZonesCount > 0 {
            return "Esta actividad contribuyó a la reconquista de \(activity.activityData.recapturedZonesCount) zona\(activity.activityData.recapturedZonesCount == 1 ? "" : "s")."
        }
        if activity.activityData.newZonesCount > 0 {
            return "Esta actividad ayudó a conquistar \(activity.activityData.newZonesCount) zona\(activity.activityData.newZonesCount == 1 ? "" : "s")."
        }
        if activity.activityData.defendedZonesCount > 0 {
            return "Esta actividad fortaleció \(activity.activityData.defendedZonesCount) defensa\(activity.activityData.defendedZonesCount == 1 ? "" : "s")."
        }
        return nil
    }
}

private struct MissionChipsView: View {
    let missions: [String]

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 96), spacing: 6, alignment: .leading)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(missions, id: \.self) { mission in
                Text(mission)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        case .fire: base = state.fireCount
        case .trophy: base = state.trophyCount
        case .devil: base = state.devilCount
        }

        if pendingReaction == reaction && state.currentUserReaction == nil {
            base += 1
        }
        return base
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ReactionType.allCases, id: \.self) { reaction in
                reactionButton(for: reaction)
            }
            Spacer()
        }
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
            HStack(spacing: 6) {
                Text(reaction.emoji)
                    .font(isSelected ? .headline.bold() : .subheadline)
                if total > 0 {
                    Text("\(total)")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, isSelected ? 12 : 10)
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: "4C6FFF").opacity(0.25) : Color.white.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color(hex: "4C6FFF") : Color.white.opacity(0.12), lineWidth: 1)
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
    let headerPadding: CGFloat
    let bannerBackground: LinearGradient
    let fadedBackground: Color
}

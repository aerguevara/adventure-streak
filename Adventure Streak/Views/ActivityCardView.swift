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
    @State private var isLoadingTerritories: Bool

    init(activity: SocialPost, reactionState: ActivityReactionState, onReaction: @escaping (ReactionType) -> Void) {
        self.activity = activity
        self.reactionState = reactionState
        self.onReaction = onReaction
        
        // Predetermine loading state based on territory impact
        let hasImpact = activity.activityData.newZonesCount > 0 || 
                         activity.activityData.defendedZonesCount > 0 || 
                         activity.activityData.recapturedZonesCount > 0 || 
                         activity.activityData.stolenZonesCount > 0
        self._isLoadingTerritories = State(initialValue: hasImpact)
    }

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

    private var refinedTitle: String {
        let location = activity.activityData.locationLabel ?? "una nueva zona"
        if activity.activityData.recapturedZonesCount > 0 { return "Zona Recuperada" }
        if activity.activityData.stolenZonesCount > 0 { return "Territorios Capturados" }
        if activity.activityData.newZonesCount > 0 { return "¡Nuevo Descubrimiento!" }
        if activity.activityData.defendedZonesCount > 0 { return "Defensa Exitosa" }
        return activity.activityData.activityType.displayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                avatar(size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(activity.user.displayName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        levelBadge
                    }
                    Text(activity.activityData.locationLabel ?? "Explorando")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(timeAgo(from: activity.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Large Square Map - The Highlight
            ZStack {
                if isLoadingTerritories {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 200)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                        )
                        .padding(.horizontal, 8)
                } else if !territoryCells.isEmpty {
                    TerritoryMinimapView(territories: territoryCells)
                        .aspectRatio(1.2, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 8)
                        .transition(.opacity)
                } else if !hasTerritoryImpact {
                    // Fallback for no maps - Premium Design
                    premiumNoMapFallback
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isLoadingTerritories)
            .animation(.easeInOut(duration: 0.3), value: territoryCells.isEmpty)
            
            VStack(alignment: .leading, spacing: 12) {
                // Title & Missions
                VStack(alignment: .leading, spacing: 6) {
                    Text(refinedTitle)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "32D74B"))
                    
                    if !missionNames.isEmpty {
                        MissionChipsView(missions: missionNames)
                    }
                }
                
                // Detailed Metrics Section
                HStack(spacing: 0) {
                    ProposalMetricSmall(icon: "figure.run", value: String(format: "%.1f km", activity.activityData.distanceKm))
                    Spacer()
                    ProposalMetricSmall(icon: "clock", value: formatDuration(activity.activityData.durationSeconds))
                    Spacer()
                    ProposalMetricSmall(icon: "star.fill", value: "+\(activity.activityData.xpEarned) XP", color: Color(hex: "A259FF"))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)

                // Reactions Bar
                ReactionBarView(
                    state: mergedReactionState,
                    pendingReaction: pendingReaction,
                    isEnabled: activity.activityId != nil,
                    onReaction: handleReaction
                )
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .padding(.horizontal, 12)
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        .task {
            if hasTerritoryImpact && territoryCells.isEmpty {
                await loadTerritories()
            }
        }
    }

    private var premiumNoMapFallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "1A1A1E"), Color(hex: "0A0A0B")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Decorative background shapes
            Circle()
                .fill(activity.activityData.activityType.color.opacity(0.15))
                .frame(width: 150, height: 150)
                .blur(radius: 40)
                .offset(x: 40, y: -20)
            
            VStack(spacing: 12) {
                Image(systemName: activity.activityData.activityType.iconName)
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [activity.activityData.activityType.color, activity.activityData.activityType.color.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: activity.activityData.activityType.color.opacity(0.5), radius: 15)
                
                Text("Entrenamiento de \(activity.activityData.activityType.displayName)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: 200)
        .padding(.horizontal, 8)
    }

    private func avatar(size: CGFloat) -> some View {
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
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private var levelBadge: some View {
        Text("LVL \(activity.user.level)")
            .font(.system(size: 10, weight: .black))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: "4C6FFF"))
            .clipShape(Capsule())
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

// Reusing Metric Component from proposals for consistency
struct ProposalMetricSmall: View {
    let icon: String
    let value: String
    var color: Color = .white
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11))
                .foregroundColor(color.opacity(0.8))
            Text(value).font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
        }
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
                    .foregroundColor(.primary.opacity(0.9))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.05))
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
                    .fill(isSelected ? Color(hex: "4C6FFF").opacity(0.2) : Color.white.opacity(0.05))
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color(hex: "4C6FFF") : Color.white.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

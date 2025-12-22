import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct NextGoalSuggestion: Identifiable {
    let id = UUID()
    let activityType: ActivityType
    let distanceKm: Double
    let durationMinutes: Double
    let xp: Int
    
    var activityLabel: String {
        let distanceText = String(format: "%.1f km", distanceKm)
        if activityType == .indoor {
            return "\(activityType.displayName) (\(distanceText))"
        }
        return "\(activityType.displayName) al aire libre (\(distanceText))"
    }
    
    var detailLabel: String {
        let durationText: String = durationMinutes >= 1
            ? "\(Int(durationMinutes.rounded())) min"
            : "Sesión corta"
        return "Tiempo estimado: \(durationText)"
    }
}

struct NextGoalContext {
    let current: RankingEntry
    let target: RankingEntry
}

struct RankingView: View {
    @StateObject var viewModel = RankingViewModel()
    @State private var showSearch = false
    @State private var showNextGoalSheet = false
    @State private var nextGoalSuggestions: [NextGoalSuggestion] = []
    @State private var nextGoalXPNeeded: Int = 0
    @State private var nextGoalTargetName: String = ""
    @State private var isLoadingSuggestions = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Header
                headerView
                
                // 2. Content
                ScrollView {
                    VStack(spacing: 24) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.top, 40)
                        } else if let error = viewModel.errorMessage {
                            errorView(message: error)
                        } else if !viewModel.hasEntries {
                            emptyStateView
                        } else {
                            // Podium
                            PodiumView(entries: Array(viewModel.entries.prefix(3))) { entry in
                                if !entry.isCurrentUser {
                                    viewModel.selectUser(userId: entry.userId)
                                }
                            }
                                .padding(.top, 10)
                            
                            if let goal = nextGoalInfo, goal.current.position <= 3 {
                                NextGoalCardView(
                                    xpUser: goal.current.weeklyXP,
                                    xpTarget: goal.target.weeklyXP,
                                    targetName: goal.target.displayName
                                ) {
                                    handleNextGoalTap(goal: goal)
                                }
                                .padding(.horizontal)
                            }
                            
                            // List
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.entries.dropFirst(3)) { entry in
                                    RankingCard(entry: entry) {
                                        viewModel.toggleFollow(for: entry)
                                    } onCardTapped: {
                                        if !entry.isCurrentUser {
                                            viewModel.selectUser(userId: entry.userId)
                                        }
                                    }
                                    
                                    if let goal = nextGoalInfo, goal.current.userId == entry.userId {
                                        NextGoalCardView(
                                            xpUser: goal.current.weeklyXP,
                                            xpTarget: goal.target.weeklyXP,
                                            targetName: goal.target.displayName
                                        ) {
                                            handleNextGoalTap(goal: goal)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    }
                }
                .refreshable {
                    viewModel.fetchRanking()
                }
            }
        }
        .sheet(isPresented: $showSearch) {
            UserSearchView()
        }
        .sheet(isPresented: $showNextGoalSheet) {
            NextGoalSuggestionsSheet(
                xpNeeded: nextGoalXPNeeded,
                targetName: nextGoalTargetName,
                suggestions: nextGoalSuggestions,
                isLoading: isLoadingSuggestions
            ) {
                isLoadingSuggestions = true
                nextGoalSuggestions = []
                Task { await loadSuggestions(for: nextGoalXPNeeded) }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $viewModel.showProfileSheet) {
            if let user = viewModel.selectedUser {
                UserProfileView(user: user)
            }
        }
        .onAppear {
            viewModel.fetchRanking()
        }
    }
    
    private var nextGoalInfo: NextGoalContext? {
        guard let currentIndex = viewModel.entries.firstIndex(where: { $0.isCurrentUser }),
              currentIndex > 0 else { return nil }
        let current = viewModel.entries[currentIndex]
        let target = viewModel.entries[currentIndex - 1]
        guard target.weeklyXP > current.weeklyXP else { return nil }
        return NextGoalContext(current: current, target: target)
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Text("Ranking Semanal")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .overlay(
                    HStack {
                        Spacer()
                        Button(action: {
                            showSearch = true
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .padding(8)
                        }
                    }
                )
            
            Picker("Alcance", selection: $viewModel.selectedScope) {
                Text("Esta Semana").tag(RankingScope.weekly)
                Text("Global").tag(RankingScope.global)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .onAppear {
                UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(red: 0.3, green: 0.4, blue: 1.0, alpha: 1.0)
                UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
                UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.lightGray], for: .normal)
            }
        }
        .padding(.bottom, 16)
        .background(Color.black)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.number")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("Aún no hay suficientes datos")
                .font(.headline)
                .foregroundColor(.white)
            Text("¡Sé el primero en aparecer en la clasificación!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 40)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("Algo salió mal")
                .font(.headline)
                .foregroundColor(.white)
            Button("Reintentar") {
                viewModel.fetchRanking()
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 40)
    }
    
    private func handleNextGoalTap(goal: NextGoalContext) {
        let delta = goal.current.xpDelta(to: goal.target)
        guard delta > 0 else { return }
        
        nextGoalXPNeeded = delta
        nextGoalTargetName = goal.target.displayName
        isLoadingSuggestions = true
        nextGoalSuggestions = []
        
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        
        showNextGoalSheet = true
        
        Task {
            await loadSuggestions(for: delta)
        }
    }
    
    private func loadSuggestions(for missingXP: Int) async {
        guard missingXP > 0 else {
            await MainActor.run { isLoadingSuggestions = false }
            return
        }
        guard let userId = AuthenticationService.shared.userId else {
            await MainActor.run { isLoadingSuggestions = false }
            return
        }
        
        do {
            let context = try await GamificationRepository.shared.buildXPContext(for: userId)
            let suggestions = try await NextGoalSuggestionBuilder.suggestions(for: missingXP, context: context)
            await MainActor.run {
                self.nextGoalSuggestions = suggestions
                self.isLoadingSuggestions = false
            }
        } catch {
            await MainActor.run {
                self.nextGoalSuggestions = []
                self.isLoadingSuggestions = false
            }
            print("Error loading XP suggestions: \(error)")
        }
    }
}

struct PodiumView: View {
    let entries: [RankingEntry]
    var onEntryTapped: ((RankingEntry) -> Void)?
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            // 2nd Place
            if entries.indices.contains(1) {
                Button(action: { onEntryTapped?(entries[1]) }) {
                    PodiumItem(entry: entries[1], scale: 0.9)
                }
                .buttonStyle(.plain)
            }
            
            // 1st Place
            if entries.indices.contains(0) {
                Button(action: { onEntryTapped?(entries[0]) }) {
                    PodiumItem(entry: entries[0], scale: 1.1, isFirst: true)
                }
                .buttonStyle(.plain)
                .zIndex(1)
            }
            
            // 3rd Place
            if entries.indices.contains(2) {
                Button(action: { onEntryTapped?(entries[2]) }) {
                    PodiumItem(entry: entries[2], scale: 0.85)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
}

struct PodiumItem: View {
    let entry: RankingEntry
    let scale: CGFloat
    var isFirst: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Avatar & Badge
            VStack(spacing: -8) {
                // Crown for 1st
                if isFirst {
                    Image(systemName: "crown.fill")
                        .foregroundColor(Color(hex: "FFD60A"))
                        .font(.title2)
                        .zIndex(1)
                }
                
                ZStack(alignment: .top) {
                    avatarView()
                        .frame(width: 70, height: 70)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(isFirst ? Color(hex: "FFD60A") : Color.clear, lineWidth: 3)
                        )
                        .shadow(color: isFirst ? Color(hex: "FFD60A").opacity(0.5) : Color.clear, radius: 10)
                    
                    // Rank Badge
                    Circle()
                        .fill(rankColor)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("\(entry.position)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                        )
                        .offset(y: 35)
                }
            }
            
            VStack(spacing: 2) {
                Text(entry.displayName)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(entry.weeklyXP) XP")
                    .font(.caption2)
                    .foregroundColor(Color(hex: "A259FF"))
            }
        }
        .scaleEffect(scale)
    }
    
    var rankColor: Color {
        switch entry.position {
        case 1: return Color(hex: "FFD60A") // Gold
        case 2: return Color(hex: "C0C0C0") // Silver
        case 3: return Color(hex: "CD7F32") // Bronze
        default: return .gray
        }
    }
    
    @ViewBuilder
    private func avatarView() -> some View {
        if let data = entry.avatarData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let url = entry.avatarURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color(hex: "1C1C1E"))
            }
        } else {
            Circle()
                .fill(Color(hex: "1C1C1E"))
                .overlay(
                    Text(entry.displayName.prefix(1).uppercased())
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                )
        }
    }
}

struct RankingCard: View {
    let entry: RankingEntry
    var onFollowTapped: (() -> Void)?
    var onCardTapped: (() -> Void)?
    
    var body: some View {
        Button(action: { onCardTapped?() }) {
            HStack(spacing: 16) {
                // Rank
                Text("\(entry.position)")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .frame(width: 24)
                
                // Avatar
                avatarView(entry: entry)
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        if entry.isCurrentUser {
                            Text("(Tú)")
                                .font(.caption2)
                                .foregroundColor(Color(hex: "4C6FFF"))
                        }
                    }
                    
                    // XP Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 4)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color(hex: "4C6FFF"), Color(hex: "A259FF")]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * entry.xpProgress, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                
                Spacer()
                
                // Stats & Actions
                HStack(spacing: 12) {
                    // Stats & Trend
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(entry.weeklyXP)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 2) {
                            Image(systemName: trendIcon)
                            Text(trendText)
                        }
                        .font(.caption2)
                        .foregroundColor(trendColor)
                    }
                    
                    // Follow Button (Only for other users)
                    if !entry.isCurrentUser {
                        Button(action: {
                            onFollowTapped?()
                        }) {
                            Image(systemName: entry.isFollowing ? "person.badge.minus" : "person.badge.plus")
                                .font(.system(size: 14))
                                .foregroundColor(entry.isFollowing ? .gray : .white)
                                .padding(8)
                                .background(entry.isFollowing ? Color.white.opacity(0.1) : Color(hex: "4C6FFF"))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain) // Ensure follow button is still tappable separately if needed, but in SwiftUI internal buttons in a Button can be tricky.
                    }
                }
            }
            .padding(16)
            .background(Color(hex: "18181C"))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(entry.isCurrentUser ? Color(hex: "4C6FFF").opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    var trendIcon: String {
        switch entry.trend {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .neutral: return "minus"
        }
    }
    
    var trendText: String {
        switch entry.trend {
        case .up: return "Subiendo"
        case .down: return "Bajando"
        case .neutral: return "Estable"
        }
    }
    
    var trendColor: Color {
        switch entry.trend {
        case .up: return .green
        case .down: return .red
        case .neutral: return .gray
        }
    }
    
    @ViewBuilder
    private func avatarView(entry: RankingEntry) -> some View {
        if let data = entry.avatarData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
        } else if let url = entry.avatarURL {
            AsyncImage(url: url) { image in
                image.resizable()
            } placeholder: {
                Circle().fill(Color(hex: "2C2C2E"))
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color(hex: "2C2C2E"))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(entry.displayName.prefix(1).uppercased())
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
        }
    }
}

struct NextGoalCardView: View {
    let xpUser: Int
    let xpTarget: Int
    let targetName: String
    let onTap: () -> Void
    
    private var progress: Double {
        guard xpTarget > 0 else { return 0 }
        return min(Double(xpUser) / Double(xpTarget), 1.0)
    }
    
    private var missingXP: Int {
        max(xpTarget - xpUser, 0)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("⬆ Próximo objetivo")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                    
                    Text("Supera a \(targetName)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("Faltan: \(missingXP) XP")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "FFD60A"))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 6)
                                
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color(hex: "4C6FFF"), Color(hex: "A259FF")]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * progress, height: 6)
                            }
                        }
                        .frame(height: 6)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(16)
            .background(Color(hex: "1F1F24"))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

struct NextGoalSuggestionsSheet: View {
    let xpNeeded: Int
    let targetName: String
    let suggestions: [NextGoalSuggestion]
    let isLoading: Bool
    var onRetry: (() -> Void)?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Cómo ganar los \(xpNeeded) XP que te faltan")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 8)
                
                Text("Objetivo: superar a \(targetName)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                if isLoading {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Calculando con el motor de XP...")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.subheadline)
                    }
                    .padding(.top, 8)
                } else if suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No pudimos generar sugerencias ahora.")
                            .foregroundColor(.white)
                            .font(.subheadline)
                        if let onRetry {
                            Button("Reintentar") {
                                onRetry()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        Text("Conecta aquí tu motor de reglas real si ya devuelve acciones específicas.")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                } else {
                    VStack(spacing: 12) {
                        ForEach(suggestions) { suggestion in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(suggestion.activityLabel) → ~\(suggestion.xp) XP")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.white)
                                    
                                    Text(suggestion.detailLabel)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color(hex: "18181C"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}


private enum NextGoalSuggestionBuilder {
    static func suggestions(for missingXP: Int, context: XPContext) async throws -> [NextGoalSuggestion] {
        let candidates = buildCandidates(missingXP: missingXP)
        let zeroStats = TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0)
        
        var evaluated: [NextGoalSuggestion] = []
        for session in candidates {
            // Uses the real XP engine; swap this call if you have a dedicated recommendation service.
            let breakdown = try await GamificationService.shared.computeXP(for: session, territoryStats: zeroStats, context: context)
            let suggestion = NextGoalSuggestion(
                activityType: session.activityType,
                distanceKm: session.distanceMeters / 1000.0,
                durationMinutes: session.durationSeconds / 60.0,
                xp: breakdown.total
            )
            evaluated.append(suggestion)
        }
        
        let sorted = evaluated
            .filter { $0.xp > 0 }
            .sorted {
                let lhsDelta = abs($0.xp - missingXP)
                let rhsDelta = abs($1.xp - missingXP)
                if lhsDelta == rhsDelta { return $0.xp > $1.xp }
                return lhsDelta < rhsDelta
            }
        
        return Array(sorted.prefix(5))
    }
    
    private static func buildCandidates(missingXP: Int) -> [ActivitySession] {
        let now = Date()
        var sessions: [ActivitySession] = []
        let activityTypes: [ActivityType] = [.run, .walk, .bike, .indoor]
        
        for type in activityTypes {
            let baseDistance = estimatedDistance(for: type, missingXP: missingXP)
            for distance in distanceVariants(baseDistance) {
                let sanitizedDistance = sanitize(distanceKm: distance)
                let duration = max(estimatedDuration(for: type, distanceKm: sanitizedDistance), XPConfig.minDurationSeconds)
                
                let session = ActivitySession(
                    startDate: now,
                    endDate: now.addingTimeInterval(duration),
                    activityType: type,
                    distanceMeters: sanitizedDistance * 1000.0,
                    durationSeconds: duration,
                    workoutName: nil,
                    route: []
                )
                sessions.append(session)
            }
        }
        
        var unique: [String: ActivitySession] = [:]
        for session in sessions {
            let key = "\(session.activityType.rawValue)_\(String(format: "%.2f", session.distanceMeters))"
            unique[key] = session
        }
        return Array(unique.values)
    }
    
    private static func estimatedDistance(for type: ActivityType, missingXP: Int) -> Double {
        switch type {
        case .indoor:
            let minutes = max(Double(missingXP) / XPConfig.indoorXPPerMinute, XPConfig.minDurationSeconds / 60.0)
            return minutes / 8.0
        default:
            let perKm = XPConfig.baseFactorPerKm * factor(for: type)
            guard perKm > 0 else { return XPConfig.minDistanceKm }
            let raw = Double(missingXP) / perKm
            return max(raw, XPConfig.minDistanceKm)
        }
    }
    
    private static func distanceVariants(_ base: Double) -> [Double] {
        [base * 0.75, base, base * 1.15].map { max($0, XPConfig.minDistanceKm) }
    }
    
    private static func sanitize(distanceKm: Double) -> Double {
        max(XPConfig.minDistanceKm, min(distanceKm, 15.0))
    }
    
    private static func estimatedDuration(for type: ActivityType, distanceKm: Double) -> Double {
        let pace = estimatedPace(for: type)
        return distanceKm * pace
    }
    
    private static func estimatedPace(for type: ActivityType) -> Double {
        switch type {
        case .run: return 360 // 6 min/km
        case .walk: return 720 // 12 min/km
        case .bike: return 180 // 3 min/km
        case .hike: return 900
        case .otherOutdoor: return 600
        case .indoor: return 480 // Equivalent for display; indoor XP uses minutes
        }
    }
    
    private static func factor(for type: ActivityType) -> Double {
        switch type {
        case .run: return XPConfig.factorRun
        case .walk, .hike: return XPConfig.factorWalk
        case .bike: return XPConfig.factorBike
        case .otherOutdoor: return XPConfig.factorOther
        case .indoor: return XPConfig.factorIndoor
        }
    }
}

private extension RankingEntry {
    func xpDelta(to target: RankingEntry) -> Int {
        max(target.weeklyXP - weeklyXP, 0)
    }
}

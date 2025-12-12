import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RankingView: View {
    @StateObject var viewModel = RankingViewModel()
    @State private var showSearch = false
    @State private var selectedObjective: NextObjectiveInfo?
    
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
                            PodiumView(entries: Array(viewModel.entries.prefix(3)))
                                .padding(.top, 10)

                            if let topObjective = topPodiumObjective {
                                NextObjectiveCard(info: topObjective) {
                                    triggerHaptic()
                                    selectedObjective = topObjective
                                }
                                .padding(.horizontal)
                            }

                            // List
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.entries.dropFirst(3)) { entry in
                                    VStack(spacing: 10) {
                                        RankingCard(entry: entry) {
                                            viewModel.toggleFollow(for: entry)
                                        }

                                        if entry.isCurrentUser, let objective = nextObjective(for: entry) {
                                            NextObjectiveCard(info: objective) {
                                                triggerHaptic()
                                                selectedObjective = objective
                                            }
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
        .sheet(item: $selectedObjective) { info in
            NextObjectiveSheet(info: info)
                .presentationDetents([.medium])
        }
        .onAppear {
            viewModel.fetchRanking()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Text("Weekly Leaderboard")
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
            
            Picker("Scope", selection: $viewModel.selectedScope) {
                Text("This Week").tag(RankingScope.weekly)
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
            Text("Not enough data yet")
                .font(.headline)
                .foregroundColor(.white)
            Text("Be the first to claim your spot on the leaderboard!")
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
            Text("Something went wrong")
                .font(.headline)
                .foregroundColor(.white)
            Button("Retry") {
                viewModel.fetchRanking()
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 40)
    }
}

private extension RankingView {
    var topPodiumObjective: NextObjectiveInfo? {
        guard let current = viewModel.currentUserEntry else { return nil }
        guard current.position <= 3 else { return nil }
        return nextObjective(for: current)
    }

    func nextObjective(for entry: RankingEntry) -> NextObjectiveInfo? {
        guard entry.position > 1 else { return nil }
        guard let target = viewModel.entries.first(where: { $0.position == entry.position - 1 }) else { return nil }

        let gap = max(target.weeklyXP - entry.weeklyXP, 0)
        let progress = min(Double(entry.weeklyXP) / Double(max(target.weeklyXP, 1)), 1.0)

        return NextObjectiveInfo(id: entry.id,
                                 currentEntry: entry,
                                 targetEntry: target,
                                 gapXP: gap,
                                 progress: progress)
    }

    func triggerHaptic() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}

struct PodiumView: View {
    let entries: [RankingEntry]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            // 2nd Place
            if entries.indices.contains(1) {
                PodiumItem(entry: entries[1], scale: 0.9)
            }
            
            // 1st Place
            if entries.indices.contains(0) {
                PodiumItem(entry: entries[0], scale: 1.1, isFirst: true)
                    .zIndex(1)
            }
            
            // 3rd Place
            if entries.indices.contains(2) {
                PodiumItem(entry: entries[2], scale: 0.85)
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
    
    var body: some View {
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
                        Text("(You)")
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
    
    var trendIcon: String {
        switch entry.trend {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .neutral: return "minus"
        }
    }
    
    var trendText: String {
        switch entry.trend {
        case .up: return "Rising"
        case .down: return "Falling"
        case .neutral: return "Stable"
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

struct NextObjectiveInfo: Identifiable {
    let id: UUID
    let currentEntry: RankingEntry
    let targetEntry: RankingEntry
    let gapXP: Int
    let progress: Double
}

struct NextObjectiveCard: View {
    let info: NextObjectiveInfo
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("⬆ Próximo objetivo")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Supera a \(info.targetEntry.displayName)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.gray)

                    Text("Faltan: \(info.gapXP) XP")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "A259FF"))

                    VStack(alignment: .leading, spacing: 6) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.08))

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color(hex: "4C6FFF"), Color(hex: "A259FF")]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * info.progress)
                            }
                        }
                        .frame(height: 8)

                        Text("\(Int(info.progress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(
                Color(hex: "1C1C1E")
                    .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .cornerRadius(18)
        }
        .buttonStyle(NextObjectiveButtonStyle())
    }
}

struct NextObjectiveSheet: View {
    let info: NextObjectiveInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .frame(maxWidth: .infinity)

            Text("Cómo ganar \(info.gapXP) XP esta semana")
                .font(.title3.weight(.bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 12) {
                sheetRow(text: "Run outdoor (5 km)", xp: 120)
                sheetRow(text: "Walk (30 min)", xp: 60)
                sheetRow(text: "Conquista 1 zona nueva", xp: 140)
            }

            Spacer()
        }
        .padding(20)
        .background(Color.black)
    }

    @ViewBuilder
    private func sheetRow(text: String, xp: Int) -> some View {
        HStack {
            Text(text)
                .foregroundColor(.white)
            Spacer()
            Text("~\(xp) XP")
                .foregroundColor(Color(hex: "A259FF"))
                .fontWeight(.semibold)
        }
    }
}

struct NextObjectiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

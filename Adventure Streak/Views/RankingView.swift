import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RankingView: View {
    @StateObject var viewModel = RankingViewModel()
    @State private var showSearch = false
    
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
                            
                            // List
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.entries.dropFirst(3)) { entry in
                                    RankingCard(entry: entry) {
                                        viewModel.toggleFollow(for: entry)
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
                    Circle()
                        .fill(Color(hex: "1C1C1E"))
                        .frame(width: 70, height: 70)
                        .overlay(
                            Text(entry.displayName.prefix(1).uppercased())
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                        )
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

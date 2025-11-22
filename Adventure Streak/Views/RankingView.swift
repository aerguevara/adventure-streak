import SwiftUI

struct RankingView: View {
    @StateObject var viewModel = RankingViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Header / Summary
            headerView
            
            // 2. Scope Selector (Optional for MVP)
            scopeSelector
            
            // 3. Content
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    errorView(message: error)
                } else if !viewModel.hasEntries {
                    emptyStateView
                } else {
                    rankingList
                }
            }
            
            // 4. Current User Footer (Sticky)
            if let currentUser = viewModel.currentUserEntry {
                Divider()
                RankingRowView(entry: currentUser)
                    .background(Color(UIColor.secondarySystemBackground))
            }
        }
        .navigationTitle("Weekly Ranking")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            viewModel.fetchRanking()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 4) {
            Text("Weekly Leaderboard")
                .font(.headline)
            Text("Period: Last 7 days")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
    }
    
    private var scopeSelector: some View {
        Picker("Scope", selection: $viewModel.selectedScope) {
            Text("This Week").tag(RankingScope.weekly)
            Text("Global").tag(RankingScope.global)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .padding(.bottom, 8)
        .disabled(true) // Disabled for MVP as requested
    }
    
    private var rankingList: some View {
        List {
            ForEach(viewModel.entries) { entry in
                RankingRowView(entry: entry)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.number")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("Not enough data yet")
                .font(.headline)
            Text("Be the first to claim your spot on the leaderboard!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("Something went wrong")
                .font(.headline)
            Button("Retry") {
                viewModel.fetchRanking()
            }
            .buttonStyle(.bordered)
        }
    }
}

struct RankingRowView: View {
    let entry: RankingEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Position
            ZStack {
                if entry.position <= 3 {
                    Circle()
                        .fill(medalColor(for: entry.position))
                        .frame(width: 32, height: 32)
                    
                    Text("\(entry.position)")
                        .font(.headline)
                        .foregroundColor(.white)
                } else {
                    Text("\(entry.position)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(width: 32)
                }
            }
            
            // User Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.displayName)
                        .font(.body)
                        .fontWeight(entry.isCurrentUser ? .bold : .regular)
                    
                    if entry.isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Text("Level \(entry.level)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // XP
            Text("\(entry.weeklyXP) XP")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding()
        .background(entry.isCurrentUser ? Color.blue.opacity(0.05) : Color.clear)
    }
    
    private func medalColor(for position: Int) -> Color {
        switch position {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .brown
        default: return .clear
        }
    }
}

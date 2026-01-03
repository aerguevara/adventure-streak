import SwiftUI

struct BadgesView: View {
    @StateObject var viewModel = BadgesViewModel()
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Summary
                summaryView
                
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if viewModel.badges.isEmpty {
                    emptyStateView
                } else {
                    // 2. Badges Grid
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(viewModel.badges) { badge in
                            ThreeDBadgeView(badge: badge, size: 140)
                                .onTapGesture {
                                    viewModel.onBadgeSelected(badge)
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Medallas y Logros")
        .background(Color(UIColor.systemGroupedBackground))
        .sheet(item: $viewModel.selectedBadge) { badge in
            BadgeDetailModal(badge: badge)
        }
        .refreshable {
            viewModel.fetchBadges()
        }
    }
    
    private var summaryView: some View {
        VStack(spacing: 8) {
            Text("Tus Logros")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("\(viewModel.unlockedCount) / \(viewModel.totalCount)")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Medallas Desbloqueadas")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("Aún no tienes medallas")
                .font(.headline)
            Text("¡Empieza a explorar para desbloquear tus primeros logros!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 40)
    }
}

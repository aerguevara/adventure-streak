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
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.badges) { badge in
                            BadgeCard(badge: badge)
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
        .navigationTitle("Badges & Achievements")
        .background(Color(UIColor.systemGroupedBackground))
        .sheet(item: $viewModel.selectedBadge) { badge in
            BadgeDetailView(badge: badge)
        }
        .refreshable {
            viewModel.fetchBadges()
        }
    }
    
    private var summaryView: some View {
        VStack(spacing: 8) {
            Text("Your Achievements")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("\(viewModel.unlockedCount) / \(viewModel.totalCount)")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Badges Unlocked")
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
            Text("No badges yet")
                .font(.headline)
            Text("Start exploring to unlock your first achievements!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 40)
    }
}

struct BadgeCard: View {
    let badge: Badge
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(badge.isUnlocked ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: badge.iconSystemName)
                    .font(.system(size: 24))
                    .foregroundColor(badge.isUnlocked ? .blue : .gray)
            }
            
            VStack(spacing: 4) {
                Text(badge.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(badge.isUnlocked ? .primary : .secondary)
                
                if badge.isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .opacity(badge.isUnlocked ? 1.0 : 0.7)
        .saturation(badge.isUnlocked ? 1.0 : 0.0)
    }
}

struct BadgeDetailView: View {
    let badge: Badge
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Large Icon
                ZStack {
                    Circle()
                        .fill(badge.isUnlocked ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: badge.iconSystemName)
                        .font(.system(size: 50))
                        .foregroundColor(badge.isUnlocked ? .blue : .gray)
                }
                .padding(.top, 40)
                
                VStack(spacing: 8) {
                    Text(badge.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if badge.isUnlocked {
                        Text("UNLOCKED")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                    } else {
                        Text("LOCKED")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.gray)
                            .cornerRadius(8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.headline)
                        Text(badge.longDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How to unlock")
                            .font(.headline)
                        Text(badge.shortDescription) // Using short description as the condition
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

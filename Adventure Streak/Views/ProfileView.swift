import SwiftUI

struct ProfileView: View {
    @StateObject var viewModel: ProfileViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Header
                    headerView
                    
                    // 2. Gamification Summary Card
                    gamificationCard
                    
                    // 3. Stats Section
                    statsSection
                    
                    // 4. Buttons Section
                    buttonsSection
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.signOut()
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
            }
            .refreshable {
                viewModel.fetchProfileData()
            }
            .onAppear {
                viewModel.fetchProfileData()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 100, height: 100)
                .overlay(
                    Text(viewModel.userDisplayName.prefix(1).uppercased())
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.primary)
                )
                .shadow(radius: 4)
            
            // Name
            Text(viewModel.userDisplayName)
                .font(.title2)
                .fontWeight(.bold)
        }
    }
    
    private var gamificationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Level \(viewModel.level)")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("XP: \(viewModel.totalXP)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Streak
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("Streak: \(viewModel.streakWeeks) wks")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)
            }
            
            // Progress Bar
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(width: geometry.size.width, height: 8)
                            .opacity(0.3)
                            .foregroundColor(.white)
                        
                        Rectangle()
                            .frame(width: min(CGFloat(viewModel.xpProgress) * geometry.size.width, geometry.size.width), height: 8)
                            .foregroundColor(.orange)
                    }
                    .cornerRadius(4)
                }
                .frame(height: 8)
                
                Text("Next Level at: \(viewModel.nextLevelXP) XP")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var statsSection: some View {
        HStack(spacing: 0) {
            statItem(value: "\(viewModel.territoriesCount)", label: "Zones")
            Divider()
            statItem(value: "\(viewModel.activitiesCount)", label: "Activities")
            Divider()
            statItem(value: "\(viewModel.totalCellsConquered)", label: "Cells Owned")
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var buttonsSection: some View {
        VStack(spacing: 12) {
            menuButton(title: "Badges & Achievements", icon: "rosette", destination: AnyView(BadgesView()))
            menuButton(title: "Weekly Ranking", icon: "list.number", destination: AnyView(RankingView()))
            menuButton(title: "Activity Feed", icon: "newspaper", destination: AnyView(ActivityFeedView()))
            menuButton(title: "Settings", icon: "gearshape", destination: AnyView(Text("Settings Coming Soon")))
        }
    }
    
    private func menuButton(title: String, icon: String, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .frame(width: 30)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
}

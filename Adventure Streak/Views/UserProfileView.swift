import SwiftUI

struct UserProfileView: View {
    let user: User
    @Environment(\.dismiss) var dismiss
    @StateObject private var socialService = SocialService.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header: Avatar & Level
                        VStack(spacing: 16) {
                            ZStack(alignment: .bottomTrailing) {
                                avatarView
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(LinearGradient(
                                                colors: [Color(hex: "4C6FFF"), Color(hex: "A259FF")],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ), lineWidth: 4)
                                    )
                                
                                // Prestige Badge
                                if let prestige = user.prestige, prestige > 0 {
                                    Image(systemName: "star.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, .orange)
                                        .font(.system(size: 32))
                                        .offset(x: 4, y: 4)
                                }
                            }
                            
                            VStack(spacing: 4) {
                                Text(user.displayName ?? "Adventurer")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 8) {
                                    Label("Level \(user.level)", systemImage: "bolt.fill")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color(hex: "A259FF"))
                                    
                                    if let streak = user.currentStreakWeeks, streak > 0 {
                                        Label("\(streak) week streak", systemImage: "flame.fill")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                        .padding(.top, 20)
                        
                        // Action Buttons
                        if let currentUserId = AuthenticationService.shared.userId, user.id != currentUserId {
                            followButton
                        }
                        
                        // Stats Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            StatCard(title: "Total XP", value: "\(user.xp)", icon: "sparkles", color: .purple)
                            StatCard(title: "Territories", value: "\(user.totalCellsOwned ?? 0)", icon: "map.fill", color: .blue)
                            StatCard(title: "This Week", value: String(format: "%.1f km", user.currentWeekDistanceKm ?? 0), icon: "figure.run", color: .green)
                            StatCard(title: "Best Week", value: String(format: "%.1f km", user.bestWeeklyDistanceKm ?? 0), icon: "trophy.fill", color: .yellow)
                        }
                        .padding(.horizontal)
                        
                        // Recent Impact (Optional)
                        if let recent = user.recentTerritories, recent > 0 {
                            HStack {
                                Image(systemName: "clock.arrow.2.circlepath")
                                    .foregroundColor(.gray)
                                Text("\(recent) territories claimed recently")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray.opacity(0.5))
                            .font(.title3)
                    }
                }
            }
        }
    }
    
    private var avatarView: some View {
        Group {
            if let avatarURLString = user.avatarURL, let url = URL(string: avatarURLString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color(hex: "1C1C1E"))
                }
            } else {
                Circle()
                    .fill(Color(hex: "1C1C1E"))
                    .overlay(
                        Text((user.displayName ?? "A").prefix(1).uppercased())
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.gray)
                    )
            }
        }
    }
    
    private var followButton: some View {
        let isFollowing = socialService.isFollowing(userId: user.id ?? "")
        
        return Button(action: {
            if isFollowing {
                socialService.unfollowUser(userId: user.id ?? "")
            } else {
                socialService.followUser(userId: user.id ?? "", displayName: user.displayName ?? "User")
            }
        }) {
            HStack {
                Image(systemName: isFollowing ? "person.badge.minus" : "person.badge.plus")
                Text(isFollowing ? "Unfollow" : "Follow")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isFollowing ? Color.white.opacity(0.1) : Color(hex: "4C6FFF"))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(hex: "18181C"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

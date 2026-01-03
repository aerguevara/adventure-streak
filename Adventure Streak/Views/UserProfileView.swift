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
                                
                                // Map Icon Badge
                                if let icon = user.mapIcon {
                                    Text(icon)
                                        .font(.system(size: 32))
                                        .padding(8)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                        .offset(x: 40, y: 40)
                                        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
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
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ], spacing: 8) {
                            StatCard(title: "Nuevos", value: "\(user.totalConqueredTerritories ?? 0)", icon: "flag.fill", color: Color(hex: "32D74B"))
                            StatCard(title: "Defendidos", value: "\(user.totalDefendedTerritories ?? 0)", icon: "shield.fill", color: Color(hex: "4C6FFF"))
                            StatCard(title: "Robados", value: "\(user.totalStolenTerritories ?? 0)", icon: "flag.slash.fill", color: Color(hex: "FF3B30"))
                            StatCard(title: "Recup.", value: "\(user.totalRecapturedTerritories ?? 0)", icon: "arrow.counterclockwise", color: Color(hex: "FF9F0A"))
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
                        
                        // Badges Section
                        if let badges = user.badges, !badges.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Insignias")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                
                                LazyVGrid(columns: [
                                    GridItem(.adaptive(minimum: 60), spacing: 12)
                                ], spacing: 12) {
                                    ForEach(badges, id: \.self) { badgeId in
                                        let def = BadgeSystem.getDefinition(for: badgeId)
                                        
                                        VStack(spacing: 4) {
                                            Text(def.icon)
                                                .font(.system(size: 32))
                                                .padding(10)
                                                .background(def.color.opacity(0.15))
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle().stroke(def.color.opacity(0.3), lineWidth: 1)
                                                )
                                            
                                            Text(def.name)
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .foregroundColor(.gray)
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                                .frame(height: 24)
                                        }
                                        .frame(height: 80)
                                    }
                                }
                                .padding(.horizontal)
                            }
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
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold)) // Smaller icon
                .foregroundColor(color)
                .padding(6)
                .background(color.opacity(0.15))
                .clipShape(Circle())
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded)) // Compact value
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 10)) // Tiny title
                .fontWeight(.medium)
                .foregroundColor(.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "18181C"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

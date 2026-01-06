import SwiftUI

struct UserProfileView: View {
    let user: User
    @Environment(\.dismiss) var dismiss
    @StateObject private var socialService = SocialService.shared
    @StateObject private var comparisonViewModel: RivalryViewModel
    
    init(user: User) {
        self.user = user
        _comparisonViewModel = StateObject(wrappedValue: RivalryViewModel(targetUserId: user.id ?? ""))
    }
    
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
                                        Label("\(streak) sem racha", systemImage: "flame.fill")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.orange)
                                    }
                                    
                                    if let totalDist = user.totalDistanceKm, totalDist > 0 {
                                        Label("\(String(format: "%.1f", totalDist)) GPS", systemImage: "map.fill")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.cyan)
                                    }
                                    
                                    if let manualDist = user.totalDistanceNoGpsKm, manualDist > 0 {
                                        Label("\(String(format: "%.1f", manualDist)) Manual", systemImage: "gauge.with.needle")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                if let joinedAt = user.joinedAt {
                                    Text("Aventurero desde \(joinedAt, style: .date)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.gray.opacity(0.8))
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .padding(.top, 20)
                        
                        // Action Buttons
                        if let currentUserId = AuthenticationService.shared.userId, user.id != currentUserId {
                            followButton
                        }
                        
                        // Competitive Duel / Ranking Snapshot
                        VStack(spacing: 16) {
                            if let rivalry = comparisonViewModel.rivalry {
                                duelCard(rivalry: rivalry)
                            }
                            
                            if let rank = comparisonViewModel.targetRanking {
                                rankSnapshot(entry: rank)
                            }
                        }
                        .padding(.horizontal)
                        
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
                        
                        // NEW: Intensity Comparison
                        if let viewerRank = comparisonViewModel.viewerRanking, let targetRank = comparisonViewModel.targetRanking {
                            intensityComparison(viewer: viewerRank, target: targetRank)
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
    
    @ViewBuilder
    private func duelCard(rivalry: RivalryRelationship) -> some View {
        VStack(spacing: 12) {
            HStack {
                Label("DUELO PERSONAL", systemImage: "bolt.shield.fill")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.orange)
                Spacer()
                Text("HISTORIAL")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(rivalry.userScore)")
                        .font(.title2)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    Text("Tú")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 8) {
                    Image(systemName: "swords")
                        .font(.title3)
                        .foregroundColor(.orange.opacity(0.8))
                    
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                        .overlay(
                            GeometryReader { geo in
                                let total = Double(rivalry.userScore + rivalry.rivalScore)
                                let progress = total > 0 ? Double(rivalry.userScore) / total : 0.5
                                Capsule()
                                    .fill(LinearGradient(colors: [.blue, .red], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * CGFloat(progress))
                            }
                        )
                }
                .frame(width: 80)
                
                VStack(spacing: 4) {
                    Text("\(rivalry.rivalScore)")
                        .font(.title2)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    Text(user.displayName?.prefix(8) ?? "Él")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(hex: "1C1C1E"))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.2), lineWidth: 1))
    }
    
    @ViewBuilder
    private func rankSnapshot(entry: RankingEntry) -> some View {
        HStack {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text("#\(entry.position)")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.purple)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Ranking Semanal")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                Text("\(entry.weeklyXP) XP acumulados")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Image(systemName: "chart.bar.fill")
                .foregroundColor(.purple.opacity(0.5))
        }
        .padding()
        .background(Color(hex: "18181C"))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
    
    @ViewBuilder
    private func intensityComparison(viewer: RankingEntry, target: RankingEntry) -> some View {
        let maxXP = Double(max(viewer.weeklyXP, target.weeklyXP, 1000))
        let maxDist = max(viewer.weeklyDistance, target.weeklyDistance, 10.0)
        
        VStack(alignment: .leading, spacing: 20) {
            // Section 1: Total Experience Trajectory
            VStack(alignment: .leading, spacing: 10) {
                Text("Trayectoria de Experiencia")
                    .font(.headline)
                    .foregroundColor(.white)
                
                intensityRow(label: "Tú", value: "\(viewer.weeklyXP) XP", ratio: Double(viewer.weeklyXP) / maxXP, color: .blue)
                intensityRow(label: target.displayName, value: "\(target.weeklyXP) XP", ratio: Double(target.weeklyXP) / maxXP, color: .purple)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Section 2: Actual Weekly Intensity (Distance)
            VStack(alignment: .leading, spacing: 10) {
                Text("Intensidad Semanal")
                    .font(.headline)
                    .foregroundColor(.white)
                
                intensityRow(label: "Tú", value: String(format: "%.1f km", viewer.weeklyDistance), ratio: viewer.weeklyDistance / maxDist, color: .cyan)
                intensityRow(label: target.displayName, value: String(format: "%.1f km", target.weeklyDistance), ratio: target.weeklyDistance / maxDist, color: .green)
            }
        }
        .padding()
        .background(Color(hex: "18181C"))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }

    private func intensityRow(label: String, value: String, ratio: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(value)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.white)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: geo.size.width * CGFloat(min(ratio, 1.0)), height: 8)
                }
            }
            .frame(height: 8)
        }
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

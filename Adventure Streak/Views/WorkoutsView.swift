import SwiftUI

struct WorkoutsView: View {
    @ObservedObject var viewModel: WorkoutsViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    @ObservedObject var badgesViewModel: BadgesViewModel
    
    @State private var showProfileDetail = false
    @State private var showMissionGuide = false
    
    // Init with dependency injection
    init(viewModel: WorkoutsViewModel, profileViewModel: ProfileViewModel, badgesViewModel: BadgesViewModel) {
        self.viewModel = viewModel
        self.profileViewModel = profileViewModel
        self.badgesViewModel = badgesViewModel
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(hex: "000000") // Pure black as requested
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // A) Header
                        headerSection
                        
                        // B) Main Progress Card
                        progressCard
                        
                        // C) Territory Summary
                        territorySummary
                        
                        // D) Achievements
                        achievementsSection
                        
                        // E) Feed
                        feedSection
                        
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .refreshable {
                    await viewModel.refresh()
                    profileViewModel.fetchProfileData()
                    badgesViewModel.fetchBadges()
                }
                
                // Modal de carga para primera sincronización (sin datos remotos aún)
                if viewModel.isLoading && viewModel.workouts.isEmpty {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.4)
                        Text("Cargando tus datos iniciales...")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Estamos preparando tus actividades y territorio desde la nube.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(24)
                    .background(Color(hex: "1C1C1E"))
                    .cornerRadius(16)
                    .shadow(radius: 10)
                    .padding(.horizontal, 24)
                }
            }
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $showMissionGuide) {
                    MissionGuideView()
                }
                .fullScreenCover(isPresented: $showProfileDetail) {
                    NavigationStack {
                        ProfileDetailView(
                            profileViewModel: profileViewModel,
                            relationsViewModel: SocialRelationsViewModel()
                        )
                    }
                }
                .onAppear {
                    Task {
                        await viewModel.refresh()
                        profileViewModel.fetchProfileData()
                        badgesViewModel.fetchBadges()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - A) Header
    var headerSection: some View {
        HStack(spacing: 16) {
            // Avatar
            Button {
                showProfileDetail = true
            } label: {
                ZStack {
                    Circle()
                        .stroke(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                        .frame(width: 56, height: 56)
                    
                    if let url = profileViewModel.avatarURL {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .resizable()
                            .padding(12)
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 50, height: 50)
                            .background(Color(hex: "1C1C1E"))
                            .clipShape(Circle())
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(profileViewModel.userDisplayName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(profileViewModel.userTitle) // Dynamic Title
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundColor(Color(hex: "A259FF")) // Purple accent
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(hex: "A259FF").opacity(0.15))
                    .cornerRadius(6)
            }
            
            Spacer()
            
            Button {
                showMissionGuide = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                    Text("Misiones")
                }
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "1C1C1E"))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - B) Main Progress Card
    var progressCard: some View {
        VStack(spacing: 20) {
            // Level & Streak Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LEVEL \(profileViewModel.level)")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(1)
                    
                    Text("\(profileViewModel.totalXP) XP")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Streak Badge
                HStack(spacing: 6) {
                    Text("🔥")
                        .font(.title3)
                    Text("\(profileViewModel.streakWeeks) weeks")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(hex: "FF453A").opacity(0.15))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "FF453A").opacity(0.3), lineWidth: 1)
                )
            }
            
            // Progress Bar
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Track
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 12)
                        
                        // Fill
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "4C6FFF"), Color(hex: "A259FF")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, min(geometry.size.width * CGFloat(profileViewModel.xpProgress), geometry.size.width)), height: 12)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: profileViewModel.xpProgress)
                    }
                }
                .frame(height: 12)
                
                HStack {
                    Text("Current Progress")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(profileViewModel.xpProgress * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(24)
        .background(Color(hex: "18181C"))
        .cornerRadius(24)
        .padding(.horizontal)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - C) Territory Summary
    var territorySummary: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "32D74B").opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "map.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: "32D74B"))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Territory Control")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(profileViewModel.totalCellsConquered)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("zones")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 4)
                }
            }
            
            Spacer()
            
            // Stats
            HStack(spacing: 16) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("+\(profileViewModel.territoriesCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("This Week")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Divider()
                    .frame(height: 30)
                    .background(Color.white.opacity(0.1))
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("12%") // Placeholder for % control if not available
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Map")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(20)
        .background(Color(hex: "18181C"))
        .cornerRadius(24)
        .padding(.horizontal)
    }
    
    // MARK: - D) Achievements
    var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Achievements")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                NavigationLink(destination: BadgesView()) {
                    Text("View all")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "A259FF"))
                }
            }
            .padding(.horizontal)
            
            if badgesViewModel.badges.isEmpty {
                Text("No achievements yet. Keep exploring!")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(badgesViewModel.badges.prefix(3)) { badge in
                            AchievementCard(badge: badge)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - E) Feed
    var feedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity Feed")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            if viewModel.isLoading && viewModel.workouts.isEmpty {
                EmptyView() // El modal global de carga ya cubre este estado
            } else if viewModel.workouts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "figure.run")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No activities yet")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 20) {
                    ForEach(viewModel.workouts) { workout in
                        GamifiedWorkoutCard(workout: workout)
                            .padding(.horizontal)
                    }
                }
            }
        }
    }
}

struct AchievementCard: View {
    let badge: Badge
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: badge.iconSystemName)
                .font(.title)
                .foregroundColor(badge.isUnlocked ? Color(hex: "FFD60A") : .gray)
                .frame(width: 50, height: 50)
                .background(Color.white.opacity(0.05))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(badge.isUnlocked ? Color(hex: "FFD60A").opacity(0.5) : Color.clear, lineWidth: 1)
                )
            
            VStack(spacing: 4) {
                Text(badge.name)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(badge.category.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundColor(categoryColor)
            }
        }
        .padding(12)
        .frame(width: 110)
        .background(Color(hex: "18181C"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    var categoryColor: Color {
        switch badge.category {
        case .territory: return .green
        case .streak: return .orange
        case .distance: return .blue
        case .activity: return .purple
        case .misc: return .gray
        }
    }
}

struct SecondaryButton: View {
    let icon: String
    let title: String
    
    var body: some View {
        Button(action: {}) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(hex: "18181C"))
            .cornerRadius(16)
        }
    }
}

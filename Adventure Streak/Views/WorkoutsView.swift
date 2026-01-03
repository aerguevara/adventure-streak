import SwiftUI

struct WorkoutsView: View {
    @ObservedObject var viewModel: WorkoutsViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    @ObservedObject var badgesViewModel: BadgesViewModel
    @StateObject private var notificationService = NotificationService.shared
    
    @State private var showProfileDetail = false
    @State private var showNotifications = false
    @State private var showImportAlert = false
    @State private var scrollOffset: CGFloat = 0
    var onShowOnMap: (String) -> Void
    
    // Init with dependency injection
    init(viewModel: WorkoutsViewModel, profileViewModel: ProfileViewModel, badgesViewModel: BadgesViewModel, onShowOnMap: @escaping (String) -> Void) {
        self.viewModel = viewModel
        self.profileViewModel = profileViewModel
        self.badgesViewModel = badgesViewModel
        self.onShowOnMap = onShowOnMap
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Neon Parallax Background
                NeonBackgroundView(scrollOffset: scrollOffset)
                
                ScrollView {
                    VStack(spacing: 32) {
                        mainContent
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: proxy.frame(in: .named("scroll")).minY)
                        }
                    )
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = -value
                }
                .refreshable {
                    await viewModel.refresh()
                    profileViewModel.fetchProfileData()
                    badgesViewModel.fetchBadges()
                }
                
            }
                .toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $showProfileDetail) {
                    NavigationStack {
                        ProfileDetailView(
                            profileViewModel: profileViewModel,
                            workoutsViewModel: viewModel,
                            relationsViewModel: SocialRelationsViewModel()
                        )
                    }
                }
                .sheet(isPresented: $showNotifications) {
                    NotificationsView()
                }
                .sheet(isPresented: $viewModel.showProcessingSummary) {
                    if let summary = viewModel.processingSummaryData {
                        ProcessingSummaryModal(summary: summary, isPresented: $viewModel.showProcessingSummary)
                    } else {
                        ProgressView()
                    }
                }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task {
                    print("App entered foreground -> auto-refreshing workouts health data...")
                    await viewModel.refresh()
                }
            }

            .overlay(alignment: .bottom) {
                if viewModel.isImporting {
                    processingStatusBar
                }
            }
                .onAppear {
                    Task {
                        await viewModel.refresh()
                        profileViewModel.fetchProfileData()
                        badgesViewModel.fetchBadges()
                        notificationService.startObserving()
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showImportAlert = newValue != nil
        }
        .alert("No pudimos importar tu entreno", isPresented: $showImportAlert, presenting: viewModel.errorMessage) { _ in
            Button("Reintentar") {
                viewModel.retryPendingImports()
            }
            Button("Cerrar", role: .cancel) { }
        } message: { message in
            Text(message)
        }
    }
    
    var mainContent: some View {
        Group {
            topContent
            bottomContent
        }
    }

    var topContent: some View {
        Group {
            // A) Header
            headerSection
            
            // B) Main Progress Card
            progressCard
            
            // C) Vulnerability Alerts
            if !profileViewModel.vulnerableTerritories.isEmpty {
                TerritoryVulnerabilityWidget(
                    vulnerableTerritories: profileViewModel.vulnerableTerritories,
                    onShowOnMap: onShowOnMap
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // D) Territory Inventory
            territoryInventorySection
            
            // New Territory Stats Grid
            territoryStatsGrid
        }
    }

    var bottomContent: some View {
        Group {
            // Rivals Section
            if !profileViewModel.recentTheftVictims.isEmpty || !profileViewModel.recentThieves.isEmpty {
                territoryRivalsSection
            }

            // E) Achievements
            achievementsSection
            
            
            // F) Feed
            feedSection
            
            #if DEBUG
            debugSection
            #endif
        }
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
            
            // Notifications
            Button {
                showNotifications = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    
                    if notificationService.unreadCount > 0 {
                        Text("\(notificationService.unreadCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(
                                Circle()
                                    .fill(Color.red)
                                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
                            )
                            .offset(x: 4, y: -4)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
    
    // MARK: - B) Main Progress Card
    var progressCard: some View {
        VStack(spacing: 20) {
            // Level & Streak Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NIVEL \(profileViewModel.level)")
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
                    Text("\(profileViewModel.streakWeeks) semanas")
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
                    Text("Progreso Actual")
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
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .padding(.horizontal)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
    
    
    // MARK: - D) Territory Inventory
    var territoryInventorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            let allItems = profileViewModel.territoryInventory
            
            HStack {
                Text("Radar de Mantenimiento")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(allItems.count) activos")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            
            if allItems.isEmpty {
                Text("No tienes territorios activos. ¡Sal a explorar!")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(allItems) { item in
                            TerritoryInventoryCard(item: item)
                                .onTapGesture {
                                    if let cell = item.territories.first {
                                        onShowOnMap(cell.id)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - E) Achievements
    var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Logros Recientes")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                NavigationLink(destination: BadgesView()) {
                    Text("Ver todo")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "A259FF"))
                }
            }
            .padding(.horizontal)
            
            if badgesViewModel.badges.isEmpty {
                Text("Aún no tienes logros. ¡Sigue explorando!")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(badgesViewModel.badges.prefix(3)) { badge in
                            AchievementCard(badge: badge)
                                .onTapGesture {
                                    badgesViewModel.selectedBadge = badge
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .sheet(item: $badgesViewModel.selectedBadge) { badge in
            BadgeDetailModal(badge: badge)
        }
    }
    
    // MARK: - F) Feed
    var feedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Actividad Reciente")
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
                    Text("Aún no hay actividad")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 20) {
                    ForEach(viewModel.workouts) { workout in
                        GamifiedWorkoutCard(workout: workout)
                            .padding(.horizontal)
                            .glowPulse(isActive: isMostRecent(workout), color: .orange)
                    }
                }
            }
        }
    }
    
    // Helper for Glow logic
    func isMostRecent(_ workout: WorkoutItemViewData) -> Bool {
        guard let firstWorkout = viewModel.workouts.first else { return false }
        guard workout.id == firstWorkout.id else { return false }
        
        // 1 Hour window
        return Date().timeIntervalSince(workout.date) < 3600
    }
    
    // MARK: - Territory Stats Grid
    var territoryStatsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Estadísticas de Exploración")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                TerritoryStatCard(
                    title: "Nuevos",
                    value: "\(profileViewModel.totalHistoricalConquered)",
                    icon: "flag.fill",
                    color: Color(hex: "32D74B")
                )
                
                TerritoryStatCard(
                    title: "Defendidos",
                    value: "\(profileViewModel.totalDefended)",
                    icon: "shield.fill",
                    color: Color(hex: "4C6FFF")
                )
                
                TerritoryStatCard(
                    title: "Robados",
                    value: "\(profileViewModel.totalStolen)",
                    icon: "flag.slash.fill",
                    color: Color(hex: "FF3B30")
                )
                
                TerritoryStatCard(
                    title: "Recup.",
                    value: "\(profileViewModel.totalRecaptured)",
                    icon: "arrow.counterclockwise",
                    color: Color(hex: "FF9F0A")
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Rivals Section
    var territoryRivalsSection: some View {
        VStack(spacing: 24) {
            if !profileViewModel.activeRivalries.isEmpty {
                RivalsRowView(
                    title: "Rivalidades Activas",
                    rivalries: profileViewModel.activeRivalries
                )
            }
        }
        .padding(.vertical, 8)
    }

    
    #if DEBUG
    var debugSection: some View {
        Button {
            viewModel.debugSimulateActivity()
        } label: {
            HStack {
                Image(systemName: "ant.fill")
                Text("Simular Actividad (Debug)")
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.red.opacity(0.5))
            .cornerRadius(12)
        }
        .padding(.top, 20)
    }
    #endif
}

struct TerritoryStatCard: View {
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
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }
}

struct AchievementCard: View {
    let badge: Badge
    
    var body: some View {
        VStack(spacing: 12) {
            ThreeDBadgeView(badge: badge, size: 70)
                .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 5)
            
            VStack(spacing: 4) {
                Text(badge.name)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                Text(badge.category.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundColor(categoryColor)
            }
        }
        .padding(12)
        .frame(width: 120, height: 160)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }
    
    var categoryColor: Color {
        switch badge.category {
        case .aggressive: return Color(hex: "FF3B30")
        case .social: return Color(hex: "5856D6")
        case .training: return Color(hex: "32D74B")
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
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
        }
    }
}

import SwiftUI

struct WorkoutsView: View {
    @ObservedObject var viewModel: WorkoutsViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    @ObservedObject var badgesViewModel: BadgesViewModel
    @StateObject private var notificationService = NotificationService.shared
    
    @State private var showProfileDetail = false
    @State private var showNotifications = false
    @State private var showImportAlert = false
    
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
                        
                        // D) Territory Inventory
                        territoryInventorySection
                        
                        // New Territory Stats Grid
                        territoryStatsGrid
                        
                        // E) Achievements
                        achievementsSection
                        
                        // F) Feed
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
                
                // Modal de importación
                if viewModel.isImporting && viewModel.importTotal > 0 {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView(
                            value: Double(viewModel.importProcessed),
                            total: Double(viewModel.importTotal)
                        )
                        .progressViewStyle(.linear)
                        .tint(Color(hex: "4DA8FF"))
                        
                        Text("Importando entrenos: \(viewModel.importProcessed) de \(viewModel.importTotal)")
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
                .sheet(isPresented: $showProfileDetail) {
                    NavigationStack {
                        ProfileDetailView(
                            profileViewModel: profileViewModel,
                            relationsViewModel: SocialRelationsViewModel()
                        )
                    }
                }
                .sheet(isPresented: $showNotifications) {
                    NotificationsView()
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
        .background(Color(hex: "18181C"))
        .cornerRadius(24)
        .padding(.horizontal)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    
    // MARK: - D) Territory Inventory
    var territoryInventorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tus Territorios")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(profileViewModel.territoryInventory.count) activos")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            
            if profileViewModel.territoryInventory.isEmpty {
                Text("No tienes territorios activos. ¡Sal a explorar!")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(profileViewModel.territoryInventory) { item in
                            TerritoryInventoryCard(item: item)
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
                        }
                    }
                    .padding(.horizontal)
                }
            }
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
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                TerritoryStatCard(
                    title: "Zonas Descubiertas",
                    value: "\(profileViewModel.totalHistoricalConquered)",
                    icon: "flag.fill",
                    color: Color(hex: "4C6FFF")
                )
                
                TerritoryStatCard(
                    title: "Robados",
                    value: "\(profileViewModel.totalStolen)",
                    icon: "shredder.fill", // Usando un icono agresivo para robos
                    color: Color(hex: "FF453A")
                )
                
                TerritoryStatCard(
                    title: "Defendidos",
                    value: "\(profileViewModel.totalDefended)",
                    icon: "shield.fill",
                    color: Color(hex: "32D74B")
                )
                
                TerritoryStatCard(
                    title: "Total Activos",
                    value: "\(profileViewModel.totalCellsConquered)",
                    icon: "map.fill",
                    color: Color(hex: "A259FF")
                )
            }
            .padding(.horizontal)
        }
    }
}

struct TerritoryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
                .padding(6)
                .background(color.opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 10))
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "18181C"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
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

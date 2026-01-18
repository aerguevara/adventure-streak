import SwiftUI
import MapKit

struct SocialCarouselView: View {
    let posts: [SocialPost]
    
    @State private var offset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    
    var body: some View {
        if posts.isEmpty {
            EmptyStoriesView()
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Label {
                        Text("LIVE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white)
                    } icon: {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .shadow(color: .red, radius: 4)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(4)
                    
                    Text("BREAKING NEWS")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.red)
                        .tracking(2)
                    
                    Spacer()
                }
                .padding(.horizontal, 22)
                
                ZStack(alignment: .leading) {
                    // Futuristic Background Strip
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "4A0000").opacity(0.6),
                                    Color.black.opacity(0.9)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            // Scanlines effect
                            VStack(spacing: 2) {
                                ForEach(0..<15) { _ in
                                    Color.white.opacity(0.03)
                                        .frame(height: 1)
                                }
                            }
                        )
                        .overlay(
                            Rectangle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.clear, .red.opacity(0.3), .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                                .frame(height: 1),
                            alignment: .top
                        )

                    HStack(spacing: 0) {
                        contentGroup
                        contentGroup
                        contentGroup
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: offset)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 80)
                .clipped()
                .contentShape(Rectangle())
                .allowsHitTesting(false)
            }
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.4))
        }
    }
    
    private var contentGroup: some View {
        HStack(spacing: 0) {
            ForEach(posts) { post in
                CarouselCardView(post: post)
                    .background(
                        GeometryReader { itemGeo in
                            Color.clear.onAppear {
                                if contentWidth == 0 && post.id == posts.first?.id {
                                    // Logic handled by wrapping groups, but we can verify here
                                }
                            }
                        }
                    )
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.onAppear {
                    if contentWidth == 0 {
                        contentWidth = geo.size.width
                        startAnimation(totalWidth: contentWidth)
                    }
                }
            }
        )
    }
    
    private func startAnimation(totalWidth: CGFloat) {
        offset = 0
        let duration = max(12, Double(posts.count) * 2.5) // Faster, technical feel
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            offset = -totalWidth
        }
    }
}

struct CarouselCardView: View {
    let post: SocialPost
    
    var body: some View {
        HStack(spacing: 12) {
            // Separator Line (Futuristic)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .red.opacity(0.5), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1, height: 60)
            
            HStack(spacing: 10) {
                // Avatar (Smaller for the strip look)
                AvatarView(user: post.user, size: 36)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.red.opacity(0.5), lineWidth: 1))
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(post.user.displayName.uppercased())
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.white)
                    
                    Text(eventDescription(for: post))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        if let location = post.activityData.locationLabel {
                            Text(location)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        
                        Text("•")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text(timeAgo(from: post.date).uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                // Mini indicator of stats
                HStack(spacing: 6) {
                    miniStat(icon: "star.fill", value: "\(post.activityData.xpEarned)", color: Color(hex: "A259FF"))
                    if post.activityData.stolenZonesCount > 0 {
                        miniStat(icon: "bolt.shield.fill", text: "STOLEN", value: "\(post.activityData.stolenZonesCount)", color: .red)
                    } else if post.activityData.newZonesCount > 0 {
                        miniStat(icon: "map.fill", text: "NEW", value: "\(post.activityData.newZonesCount)", color: Color(hex: "32D74B"))
                    }
                }
                .padding(.leading, 8)
            }
            .padding(.vertical, 4)
        }
        .frame(height: 80)
        .padding(.trailing, 30) // More space between news items
    }

    private func miniStat(icon: String, text: String? = nil, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(color)
            
            if let text {
                Text(text)
                    .font(.system(size: 7, weight: .black))
                    .foregroundColor(color.opacity(0.8))
            }
            
            Text(value)
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(color.opacity(0.3), lineWidth: 0.5)
        )
    }


    private func eventDescription(for post: SocialPost) -> String {
        let data = post.activityData
        if post.eventType == .territoryConquered {
            return "ha conquistado un territorio"
        }
        if data.stolenZonesCount > 0 {
            return "ha robado \(data.stolenZonesCount) \(data.stolenZonesCount == 1 ? "zona" : "zonas")"
        }
        if data.newZonesCount > 0 {
            return "ha descubierto \(data.newZonesCount) \(data.newZonesCount == 1 ? "zona" : "zonas")"
        }
        if data.recapturedZonesCount > 0 {
            return "ha recuperado territorios"
        }
        return "está explorando"
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct AvatarView: View {
    let user: SocialUser
    let size: CGFloat
    
    var body: some View {
        Group {
            if let data = user.avatarData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let avatarURL = user.avatarURL {
                AsyncImage(url: avatarURL) { image in
                    image.resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle().fill(Color(hex: "2C2C2E"))
                }
            } else {
                Circle()
                    .fill(Color(hex: "2C2C2E"))
                    .overlay(
                        Text(user.displayName.prefix(1).uppercased())
                            .font(.system(size: size * 0.4, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(width: size, height: size)
    }
}

struct StoriesBarView: View {
    @ObservedObject var viewModel: SocialViewModel
    
    var body: some View {
        SocialCarouselView(posts: viewModel.carouselActivities)
    }
}

struct EmptyStoriesView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Pulsing Circle
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "FF9500").opacity(0.5), Color(hex: "FF3B30").opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 72, height: 72)
                    .scaleEffect(isAnimating ? 1.15 : 1.0)
                    .opacity(isAnimating ? 0.0 : 0.8)
                
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "safari.fill") // Compass icon
                            .font(.system(size: 28))
                            .foregroundColor(.orange)
                            .shadow(color: .orange.opacity(0.6), radius: 6)
                            .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "FF9500"), Color(hex: "FF3B30")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("SIN ACTIVIDAD")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.orange)
                    .tracking(1.5)
                
                Text("Tú marcas el paso")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Explora y sé el primero")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.leading, 4)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

struct StoryCircleView: View {
    let story: UserStory
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "FF9500"), Color(hex: "FF3B30")], // Orange to Red (Streak Theme)
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 72, height: 72)
                
                // Avatar
                Group {
                    if let data = story.user.avatarData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else if let avatarURL = story.user.avatarURL {
                        AsyncImage(url: avatarURL) { image in
                            image.resizable()
                                .scaledToFill()
                        } placeholder: {
                            Circle().fill(Color(hex: "2C2C2E"))
                        }
                    } else {
                        Circle()
                            .fill(Color(hex: "2C2C2E"))
                            .overlay(
                                Text(story.user.displayName.prefix(1).uppercased())
                                    .font(.headline)
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())
            }
            
            Text(story.user.displayName)
                .font(.caption2)
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 72)
        }
        .onTapGesture(perform: action)
    }
}

struct StoryDetailView: View {
    let story: UserStory
    let allStories: [UserStory] // List of all available user stories
    @Binding var selectedStory: UserStory? // Binding to switch users
    let isActive: Bool
    var containerDismiss: (() -> Void)? = nil // Explicit dismiss action for container
    @Environment(\.dismiss) var dismiss // Fallback
    @State private var currentIndex = 0
    @State private var progress: Double = 0.0
    @State private var territoryCells: [TerritoryCell] = []
    @State private var isLoadingTerritories = false
    @State private var isInteracting = false // Track user interaction
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if story.activities.isEmpty {
                VStack {
                    Text("No hay actividades recientes")
                        .foregroundColor(.white)
                    Text("No hay actividades recientes")
                        .foregroundColor(.white)
                    Button("Cerrar") {
                        if let action = containerDismiss { action() } else { dismiss() }
                    }
                        .padding()
                }
            } else {
                VStack {
                    // Progress Bars
                    HStack(spacing: 4) {
                        ForEach(0..<story.activities.count, id: \.self) { index in
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.3))
                                    
                                    if index == currentIndex {
                                        Capsule()
                                            .fill(Color.white)
                                            .frame(width: geo.size.width * progress)
                                    } else if index < currentIndex {
                                        Capsule()
                                            .fill(Color.white)
                                    }
                                }
                            }
                            .frame(height: 3)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // Header
                    HStack {
                        StoryAvatarSmall(user: story.user)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(story.user.displayName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            if currentIndex < story.activities.count {
                                Text(timeAgo(from: story.activities[currentIndex].date))
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            if let action = containerDismiss {
                                action()
                            } else {
                                dismiss()
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding(8)
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Content
                    if currentIndex < story.activities.count {
                        let currentPost = story.activities[currentIndex]
                        let totalTerritories = currentPost.activityData.newZonesCount +
                            currentPost.activityData.defendedZonesCount +
                            currentPost.activityData.recapturedZonesCount +
                            currentPost.activityData.stolenZonesCount
                        
                        VStack(spacing: 24) {
                            // Story text
                            VStack(spacing: 8) {
                                Text(storyTitle(for: currentPost))
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                if let subtitle = currentPost.eventSubtitle {
                                    Text(subtitle)
                                        .font(.body)
                                        .foregroundColor(.white.opacity(0.9))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                
                                if let victimLine = stolenVictimsLine(for: currentPost) {
                                    Text(victimLine)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.white.opacity(0.9))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                            }
                            
                            // Minimap (Glassmorphism card)
                            if let region = currentPost.miniMapRegion {
                                ZStack {
                                    Map(initialPosition: .region(region.coordinateRegion)) {
                                        ForEach(territoryCells) { cell in
                                            let coords = cell.boundary.map { $0.coordinate }
                                            if coords.count >= 3 {
                                                MapPolygon(coordinates: coords)
                                                    .stroke(Color(hex: "32D74B"), lineWidth: 1)
                                                    .foregroundStyle(Color(hex: "32D74B").opacity(0.2))
                                            } else {
                                                Marker("", coordinate: cell.centerCoordinate)
                                                    .tint(Color(hex: "32D74B"))
                                            }
                                        }
                                    }
                                    .frame(height: 350)
                                    .cornerRadius(24)
                                    .id(currentIndex) // Force fresh map for each story
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                    
                                    // Visual overlay for better contrast
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Text("Territorio Activo")
                                                .font(.caption.bold())
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(.ultraThinMaterial)
                                                .cornerRadius(8)
                                                .foregroundColor(.white)
                                            Spacer()
                                        }
                                        .padding()
                                    }
                                }
                                .padding(.horizontal)
                            } else {
                                // Fallback indicator
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color(hex: "1C1C1E"))
                                    .frame(height: 350)
                                    .overlay(
                                        Text("Aventura en curso...")
                                            .foregroundColor(.gray)
                                    )
                                    .padding(.horizontal)
                            }
                            
                            // Metrics & territory impact
                            VStack(spacing: 12) {
                                HStack(spacing: 32) {
                                    storyMetric(icon: "star.fill", value: "+\(currentPost.activityData.xpEarned) XP")
                                    storyMetric(icon: "flag.fill", value: "\(totalTerritories) Territorios")
                                }
                                
                                territoryImpactRow(for: currentPost)
                            }
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isInteracting = true }
                .onEnded { _ in isInteracting = false }
        )
        .onReceive(timer) { _ in
            guard isActive else { return }
            if !isInteracting {
                if progress < 1.0 {
                    progress = min(1.0, progress + 0.02) // 5 seconds per story roughly
                } else {
                    nextStory()
                }
            }
        }
        .onTapGesture { location in
            guard isActive else { return }
            if location.x < UIScreen.main.bounds.width / 3 {
                prevStory()
            } else {
                nextStory()
            }
        }
        .task(id: isActive) {
            guard isActive, currentIndex < story.activities.count else { return }
            await loadTerritoryCells(for: story.activities[currentIndex].activityId)
        }
        .onChange(of: currentIndex) { _, newIndex in
            guard isActive, newIndex < story.activities.count else { return }
            Task {
                await loadTerritoryCells(for: story.activities[newIndex].activityId)
            }
        }
    }
    
    private func loadTerritoryCells(for activityId: String?) async {
        await MainActor.run {
            self.territoryCells = []
            self.isLoadingTerritories = true
        }
        
        guard let activityId = activityId else { 
            await MainActor.run { self.isLoadingTerritories = false }
            return 
        }
        
        let cells = await ActivityRepository.shared.fetchTerritoriesForActivity(activityId: activityId)
        await MainActor.run {
            self.territoryCells = cells
            self.isLoadingTerritories = false
        }
    }
    
    private func nextStory() {
        if currentIndex < story.activities.count - 1 {
            currentIndex += 1
            progress = 0
        } else {
            // Check if there is a next user
            if let index = allStories.firstIndex(where: { $0.id == story.id }),
               index < allStories.count - 1 {
                // Move to next user
                selectedStory = allStories[index + 1]
            } else {
                if let action = containerDismiss {
                    action()
                } else {
                    dismiss()
                }
            }
        }
    }
    
    private func prevStory() {
        if currentIndex > 0 {
            currentIndex -= 1
            progress = 0
        } else {
            // Re-start current
            progress = 0
        }
    }
    
    func storyTitle(for post: SocialPost) -> String {
        guard let type = post.eventType else { return "Actividad" }
        switch type {
        case .territoryConquered: return "Nueva Conquista"
        case .territoryLost: return "Territorio Perdido"
        case .territoryRecaptured: return "Territorio Recapturado"
        default: return "Expansión"
        }
    }
    
    private func storyMetric(icon: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.orange)
            Text(value)
                .foregroundColor(.white)
                .font(.subheadline.bold())
        }
    }

    private func territoryImpactRow(for post: SocialPost) -> some View {
        HStack(spacing: 10) {
            storyTerritoryBadge(title: "Nuevas", value: post.activityData.newZonesCount, color: "32D74B")
            storyTerritoryBadge(title: "Defendidas", value: post.activityData.defendedZonesCount, color: "4C6FFF")
            storyTerritoryBadge(title: "Recup.", value: post.activityData.recapturedZonesCount, color: "FF9F0A")
            storyTerritoryBadge(title: "Robadas", value: post.activityData.stolenZonesCount, color: "FF3B30")
        }
    }

    private func storyTerritoryBadge(title: String, value: Int, color: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.subheadline.bold())
                .foregroundColor(.white)
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(hex: color).opacity(0.25))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: color).opacity(0.6), lineWidth: 1)
        )
        .cornerRadius(10)
    }

    private func stolenVictimsLine(for post: SocialPost) -> String? {
        guard post.activityData.stolenZonesCount > 0 else { return nil }
        let victims = uniqueVictimNames(post.activityData.stolenVictimNames ?? [])
        guard !victims.isEmpty else {
            return "Robó territorios a otros jugadores"
        }
        if victims.count == 1 {
            return "Robó territorios a \(victims[0])"
        }
        if victims.count == 2 {
            return "Robó territorios a \(victims[0]) y \(victims[1])"
        }
        return "Robó territorios a \(victims[0]) y \(victims.count - 1) más"
    }

    private func uniqueVictimNames(_ names: [String]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed).inserted {
                unique.append(trimmed)
            }
        }
        return unique
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct StoryAvatarSmall: View {
    let user: SocialUser
    
    var body: some View {
        Group {
            if let data = user.avatarData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let avatarURL = user.avatarURL {
                AsyncImage(url: avatarURL) { image in
                    image.resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle().fill(Color(hex: "2C2C2E"))
                }
            } else {
                Circle()
                    .fill(Color(hex: "2C2C2E"))
                    .overlay(
                        Text(user.displayName.prefix(1).uppercased())
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
    }
}
struct StoryContainerView: View {
    let stories: [UserStory]
    @Binding var selectedStory: UserStory?
    @Binding var isPresented: Bool
    
    // We use a State to track the *visible* tab ID.
    @State private var visibleStoryId: String = ""
    
    var body: some View {
        TabView(selection: $visibleStoryId) {
            ForEach(stories) { story in
                StoryDetailView(
                    story: story,
                    allStories: stories,
                    selectedStory: $selectedStory,
                    isActive: visibleStoryId == story.id,
                    containerDismiss: {
                        isPresented = false
                    }
                )
                .tag(story.id)
                .ignoresSafeArea()
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            if let start = selectedStory {
                visibleStoryId = start.id
            }
        }
        .onChange(of: selectedStory) { _, newStory in
             if let newStory = newStory {
                 // Logic: if external binding changes (from detail view logic), update tab
                 visibleStoryId = newStory.id
             }
        }
        .onChange(of: visibleStoryId) { _, newId in
            // Keep the binding in sync so we know "where we are"
            if let story = stories.first(where: { $0.id == newId }) {
                selectedStory = story
            }
        }
    }
}

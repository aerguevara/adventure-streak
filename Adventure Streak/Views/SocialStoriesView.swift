import SwiftUI
import MapKit

struct StoriesBarView: View {
    let stories: [UserStory]
    let onSelect: (UserStory) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(stories) { story in
                    StoryCircleView(story: story) {
                        onSelect(story)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color.black)
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
                            
                            // Metrics small
                            HStack(spacing: 40) {
                                storyMetric(icon: "star.fill", value: "+\(currentPost.activityData.xpEarned) XP")
                                storyMetric(icon: "map.fill", value: "\(currentPost.activityData.newZonesCount) Zonas")
                            }
                            
                            Spacer()
                            
                            // Bottom Action (View Post)
                            NavigationLink(destination: SocialPostDetailView(post: currentPost)) {
                                Text("Ver detalles")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 24)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(20)
                            }
                            .padding(.bottom, 40)
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
            if !isInteracting {
                if progress < 1.0 {
                    progress += 0.02 // 5 seconds per story roughly
                } else {
                    nextStory()
                }
            }
        }
        .onTapGesture { location in
            if location.x < UIScreen.main.bounds.width / 3 {
                prevStory()
            } else {
                nextStory()
            }
        }
        .task {
            if currentIndex < story.activities.count {
                await loadTerritoryCells(for: story.activities[currentIndex].activityId)
            }
        }
        .onChange(of: currentIndex) { _, newIndex in
            if newIndex < story.activities.count {
                Task {
                    await loadTerritoryCells(for: story.activities[newIndex].activityId)
                }
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

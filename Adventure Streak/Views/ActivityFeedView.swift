import SwiftUI
import MapKit

struct ActivityFeedView: View {
    @StateObject var viewModel: FeedViewModel
    
    // Init with dependency injection
    init(viewModel: FeedViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.events.isEmpty {
                    ProgressView("Cargando actividad...")
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(error)
                        Button("Reintentar") {
                            Task { await viewModel.refresh() }
                        }
                    }
                } else if viewModel.events.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("Todavía no hay actividad suficiente para mostrar el feed.")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Weekly Summary Header
                            if let summary = viewModel.weeklySummary {
                                WeeklySummaryCard(data: summary)
                                    .padding(.horizontal)
                                    .padding(.top)
                            }
                            
                            // Events List
                            ForEach(viewModel.events) { event in
                                FeedEventRowView(event: event)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.bottom)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationTitle("Actividad")
            .task {
                await viewModel.loadFeed()
            }
        }
    }
}

// MARK: - Weekly Summary Card

struct WeeklySummaryCard: View {
    let data: WeeklySummaryViewData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Resumen Semanal")
                    .font(.headline)
                Spacer()
            }
            
            Divider()
            
            HStack(spacing: 20) {
                SummaryStat(label: "Distancia", value: String(format: "%.1f km", data.totalDistance))
                SummaryStat(label: "Conquistas", value: "\(data.territoriesConquered)")
                SummaryStat(label: "Pérdidas", value: "\(data.territoriesLost)")
            }
            
            if let rival = data.rivalName {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Tu mayor rival: \(rival)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
            
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("Racha actual: \(data.currentStreakWeeks) semanas")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct SummaryStat: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Feed Event Row

struct FeedEventRowView: View {
    let event: FeedEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Icon + Title + Date
            HStack(alignment: .top) {
                iconView
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let subtitle = displaySubtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let xp = event.xpEarned {
                        Text("+\(xp) XP")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                Text(event.date.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            // Content: MiniMap if available
            if let region = event.miniMapRegion {
                Map(initialPosition: .region(region.coordinateRegion)) {
                    // Simple marker for context
                    Marker("Zona", coordinate: region.coordinateRegion.center)
                }
                .frame(height: 120)
                .cornerRadius(8)
                .disabled(true) // Static map
            }
            
            // Footer: Call to action for lost territories
            if event.type == .territoryLost {
                Text("¿Vas a recuperarlo?")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Style Helpers
    
    var iconView: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor)
                .frame(width: 40, height: 40)
            
            Image(systemName: iconName)
                .foregroundColor(iconColor)
        }
    }
    
    var iconName: String {
        switch event.type {
        case .streakMaintained: return "flame.fill"
        case .newBadge: return "star.fill"
        case .levelUp: return "trophy.fill"
        case .territoryConquered: return "globe.europe.africa.fill"
        case .territoryLost: return "flag.slash.fill"
        case .territoryRecaptured: return "shield.fill"
        case .distanceRecord: return "chart.line.uptrend.xyaxis"
        case .weeklySummary: return "list.bullet.clipboard"
        }
    }
    
    var iconColor: Color {
        switch event.type {
        case .streakMaintained: return .orange
        case .newBadge:
            switch event.badgeRarity {
            case .common: return .gray
            case .rare: return .blue
            case .epic: return .purple
            case .legendary: return .yellow
            case .none: return .yellow
            }
        case .levelUp: return .yellow
        case .territoryConquered: return .green
        case .territoryLost: return .red
        case .territoryRecaptured: return .blue
        case .distanceRecord: return .pink
        case .weeklySummary: return .primary
        }
    }
    
    var iconBackgroundColor: Color {
        iconColor.opacity(0.15)
    }
    
    var backgroundColor: Color {
        switch event.type {
        case .territoryConquered, .territoryRecaptured:
            return Color.green.opacity(0.05)
        case .territoryLost:
            return Color.red.opacity(0.05)
        case .newBadge:
            if event.badgeRarity == .legendary {
                return Color.yellow.opacity(0.1)
            }
            return Color(UIColor.secondarySystemGroupedBackground)
        default:
            return Color(UIColor.secondarySystemGroupedBackground)
        }
    }
    
    var borderColor: Color {
        switch event.type {
        case .newBadge:
            return iconColor.opacity(0.3)
        default:
            return Color.clear
        }
    }
    
    // MARK: - Text Helpers
    
    var isMe: Bool {
        guard let currentUserId = AuthenticationService.shared.userId,
              let eventUserId = event.userId else { return false }
        return currentUserId == eventUserId
    }
    
    var displayTitle: String {
        if isMe {
            return event.title
        } else {
            // Third person transformation
            let userName = event.relatedUserName ?? "Un aventurero"
            switch event.type {
            case .territoryConquered: return "\(userName) ha conquistado"
            case .territoryLost: return "\(userName) ha perdido un territorio"
            case .territoryRecaptured: return "\(userName) ha recuperado territorio"
            case .levelUp: return "\(userName) ha subido de nivel"
            case .newBadge: return "\(userName) ha ganado una insignia"
            case .streakMaintained: return "\(userName) mantiene su racha"
            case .distanceRecord: return "\(userName) rompió un récord"
            default: return event.title
            }
        }
    }
    
    var displaySubtitle: String? {
        if isMe {
            return event.subtitle
        } else {
            // Third person transformation
            guard let subtitle = event.subtitle else { return nil }
            // Simple heuristic replacement for MVP
            // Ideally, we'd store the data and generate the string, but replacing "Has" with "Ha" works for Spanish
            return subtitle.replacingOccurrences(of: "Has ", with: "Ha ")
                           .replacingOccurrences(of: "tus ", with: "sus ")
                           .replacingOccurrences(of: "tu ", with: "su ")
        }
    }
}

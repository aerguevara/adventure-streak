import SwiftUI

struct WorkoutsView: View {
    @StateObject var viewModel: WorkoutsViewModel
    
    // Init with dependency injection
    init(viewModel: WorkoutsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.workouts.isEmpty {
                    ProgressView("Cargando entrenos...")
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
                } else if viewModel.workouts.isEmpty {
                    ScrollView {
                        VStack(spacing: 16) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("Aún no tienes entrenos registrados.")
                                .foregroundColor(.secondary)
                            Text("Desliza hacia abajo para importar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.workouts) { workout in
                                WorkoutCard(workout: workout)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.top)
                        .padding(.bottom)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationTitle("Entrenos")
            .onAppear {
                Task {
                    await viewModel.refresh()
                }
            }
        }
    }
}

struct WorkoutCard: View {
    let workout: WorkoutItemViewData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top) {
                HStack(spacing: 12) {
                    iconView
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(workout.dateString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            // Metrics Grid
            HStack(spacing: 0) {
                metricItem(value: workout.duration, label: "Duración")
                Spacer()
                if let pace = workout.pace {
                    metricItem(value: pace, label: "Ritmo")
                    Spacer()
                }
                if let xp = workout.xp {
                    metricItem(value: "+\(xp) XP", label: "Total", valueColor: .purple)
                }
            }
            
            // Territory / Secondary Info
            // Territory / Secondary Info
            if let territoryCount = workout.territoryCount {
                // New Data: Show if there are new territories OR if there was territory XP (Defense)
                if territoryCount > 0 || (workout.territoryXP ?? 0) > 0 {
                    Divider()
                    HStack {
                        Image(systemName: "globe.europe.africa.fill")
                            .foregroundColor(.green)
                        Text("Territorio")
                            .font(.caption)
                            .fontWeight(.bold)
                        Spacer()
                        Text("\(territoryCount) Territorios")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            } else if let territoryXP = workout.territoryXP, territoryXP > 0 {
                // Fallback for old data if count is missing but XP exists
                Divider()
                HStack {
                    Image(systemName: "globe.europe.africa.fill")
                        .foregroundColor(.green)
                    Text("Territorio")
                        .font(.caption)
                        .fontWeight(.bold)
                    Spacer()
                    Text("+\(territoryXP) XP")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Tags
            if workout.isStreak || workout.isRecord || workout.hasBadge {
                HStack(spacing: 8) {
                    if workout.isStreak {
                        TagView(text: "Streak ✅", color: .orange)
                    }
                    if workout.isRecord {
                        TagView(text: "Nuevo récord", color: .pink)
                    }
                    if workout.hasBadge {
                        TagView(text: "Badge 🏅", color: .yellow)
                    }
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    var iconView: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 48, height: 48)
            
            Image(systemName: iconName)
                .font(.title3)
                .foregroundColor(.blue)
        }
    }
    
    var iconName: String {
        switch workout.type {
        case .run: return "figure.run"
        case .walk: return "figure.walk"
        case .bike: return "bicycle"
        case .otherOutdoor: return "figure.outdoor.cycle"
        }
    }
    
    func metricItem(value: String, label: String, valueColor: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.body, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(valueColor)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
    }
}

struct TagView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .cornerRadius(8)
    }
}

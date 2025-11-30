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
                // Background
                Color(hex: "0F0F0F")
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.workouts.isEmpty {
                    ProgressView("Cargando entrenos...")
                        .foregroundColor(.white)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.white)
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
                                .foregroundColor(.gray)
                            Text("Desliza hacia abajo para importar")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Title
                            Text("Entrenos")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.top, 20)
                                .padding(.horizontal)
                            
                            LazyVStack(spacing: 20) {
                                ForEach(viewModel.workouts) { workout in
                                    GamifiedWorkoutCard(workout: workout)
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.bottom, 40)
                        }
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            // Hide default navigation title to use custom one
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                Task {
                    await viewModel.refresh()
                }
            }
        }
        .preferredColorScheme(.dark)
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
            if let newCount = workout.newTerritories,
               let defendedCount = workout.defendedTerritories,
               let recapturedCount = workout.recapturedTerritories {
                
                // Check if we have ANY territory activity (even if all are 0, we might want to show something if it was a valid outdoor workout)
                // But usually we only show if > 0.
                // User wants to see "0" if it was a defense.
                // Let's show the row if any count exists (which they should if territoryStats was present)
                
                Divider()
                HStack(spacing: 12) {
                    // 1. New Territories (Green)
                    if newCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill")
                            Text("\(newCount) Nuevos")
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // 2. Recaptured/Stolen (Orange)
                    if recapturedCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("\(recapturedCount) Robados")
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // 3. Defended/Renewed (Blue)
                    if defendedCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "shield.fill")
                            Text("\(defendedCount) Renovados")
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Fallback: If all are 0 (e.g. ran in empty space or error), show "0 Territorios"
                    if newCount == 0 && recapturedCount == 0 && defendedCount == 0 {
                         HStack(spacing: 4) {
                            Image(systemName: "globe.europe.africa.fill")
                            Text("0 Territorios")
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
            } else if let territoryXP = workout.territoryXP, territoryXP > 0 {
                // Fallback for old data
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
        case .hike: return "figure.hiking"
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

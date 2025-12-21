import SwiftUI
import MapKit

struct HistoryView: View {
    @StateObject var viewModel: HistoryViewModel
    
    var body: some View {
        NavigationView {
            List(viewModel.activities) { activity in
                NavigationLink(destination: ActivityDetailView(activity: activity)) {
                    HStack {
                        Image(systemName: activity.activityType.iconName)
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            let headline = activity.missions?.first?.name ?? activity.startDate.formatted(date: .abbreviated, time: .shortened)
                            Text(headline)
                                .font(.headline)
                                .foregroundColor(activity.missions?.isEmpty == false ? missionColor(for: activity.missions?.first?.rarity ?? .common) : .primary)
                            
                            HStack(spacing: 8) {
                                Text(String(format: "%.2f km", activity.distanceMeters / 1000))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("·")
                                    .foregroundColor(.secondary)
                                
                                let subheadline = activity.workoutName ?? activity.activityType.displayName
                                Text(subheadline)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text(formatDuration(activity.durationSeconds))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("History")
            .onAppear {
                viewModel.loadActivities()
            }
            .alert(isPresented: $viewModel.showAlert) {
                Alert(title: Text("Import Status"), message: Text(viewModel.alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
    
    func missionColor(for rarity: MissionRarity) -> Color {
        switch rarity {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
}

struct ActivityDetailView: View {
    let activity: ActivitySession
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Mini Map
                if !activity.route.isEmpty {
                    Map(initialPosition: .region(regionFor(route: activity.route))) {
                        if let firstPoint = activity.route.first {
                            Marker("Start", coordinate: firstPoint.coordinate)
                        }
                        MapPolyline(coordinates: activity.route.map { $0.coordinate })
                            .stroke(.blue, lineWidth: 3)
                    }
                    .frame(height: 200)
                    .cornerRadius(12)
                }
                
                HStack {
                    StatBox(title: "Distance", value: String(format: "%.2f km", activity.distanceMeters / 1000))
                    StatBox(title: "Duration", value: formatDuration(activity.durationSeconds))
                }
                
                HStack {
                    let baseName = activity.workoutName ?? activity.activityType.displayName
                    StatBox(title: "Type", value: baseName)
                    StatBox(title: "Date", value: activity.startDate.formatted(date: .numeric, time: .omitted))
                }
                
                // Missions Section
                if let missions = activity.missions, !missions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Misiones")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        ForEach(missions) { mission in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(mission.name)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text(mission.rarity.rawValue.capitalizingFirstLetter())
                                        .font(.caption.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(missionColor(for: mission.rarity).opacity(0.2))
                                        .foregroundColor(missionColor(for: mission.rarity))
                                        .cornerRadius(4)
                                }
                                
                                Text(mission.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Activity Details")
    }
    
    func regionFor(route: [RoutePoint]) -> MKCoordinateRegion {
        guard !route.isEmpty else { return MKCoordinateRegion() }
        let center = route[0].coordinate
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        return formatter.string(from: duration) ?? ""
    }
    
    func missionColor(for rarity: MissionRarity) -> Color {
        switch rarity {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
}

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }
}

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

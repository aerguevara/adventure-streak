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
                            Text(activity.startDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.headline)
                            Text(String(format: "%.2f km", activity.distanceMeters / 1000))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(formatDuration(activity.durationSeconds))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("History")
            .navigationTitle("History")
            .onAppear {
                viewModel.loadActivities()
            }
            // Removed manual import button as requested
            // .toolbar { ... }
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
                    StatBox(title: "Type", value: activity.activityType.displayName)
                    StatBox(title: "Date", value: activity.startDate.formatted(date: .numeric, time: .omitted))
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

import SwiftUI

struct ActivityDiscoveryView: View {
    let activities: [ActivitySession]
    let isImporting: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            if isImporting {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(Color(hex: "4C6FFF"))
                    Text("Importando tus entrenos...")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Estamos analizando tus rutas y calculando tus territorios.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(activities) { activity in
                            DiscoveryItem(activity: activity)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 400)
            }
        }
    }
}

struct DiscoveryItem: View {
    let activity: ActivitySession
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "4C6FFF").opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: activity.activityType.iconName)
                    .foregroundColor(Color(hex: "4C6FFF"))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                
                Text("\(formatDistance(activity.distanceMeters)) · \(formatDuration(activity.durationSeconds))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Text(formatDate(activity.startDate))
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func formatDistance(_ meters: Double) -> String {
        let km = meters / 1000.0
        return String(format: "%.1f km", km)
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }
}

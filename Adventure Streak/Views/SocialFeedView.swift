import SwiftUI

struct SocialFeedView: View {
    @StateObject var viewModel = SocialViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if viewModel.posts.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(viewModel.posts) { post in
                                SocialPostCard(post: post)
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationTitle("Actividad Social")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No hay actividad reciente")
                .font(.headline)
                .foregroundColor(.white)
            Text("Sigue a otros aventureros para ver su progreso aquí.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

struct SocialPostCard: View {
    let post: SocialPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(Color(hex: "2C2C2E"))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(post.user.displayName.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.user.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Nivel \(post.user.level)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(timeAgo(from: post.date))
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(formatAbsoluteDate(post.date))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            // Auto-generated text
            Text(generatePostText())
                .font(.body)
                .foregroundColor(.white)
            
            // Stats Grid
            HStack(spacing: 0) {
                statItem(value: String(format: "%.1f km", post.activityData.distanceKm), label: "Distancia", icon: "figure.run")
                Divider().background(Color.white.opacity(0.1))
                statItem(value: formatDuration(post.activityData.durationSeconds), label: "Tiempo", icon: "clock")
                Divider().background(Color.white.opacity(0.1))
                statItem(value: "\(post.activityData.xpEarned) XP", label: "Ganado", icon: "star.fill", valueColor: Color(hex: "A259FF"))
            }
            .padding(.vertical, 12)
            .background(Color(hex: "2C2C2E").opacity(0.5))
            .cornerRadius(12)
            
            // New Zones Badge (if applicable)
            if post.activityData.newZonesCount > 0 {
                HStack {
                    Image(systemName: "map.fill")
                        .foregroundColor(.green)
                    Text("\(post.activityData.newZonesCount) nuevas zonas conquistadas")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(hex: "18181C"))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private func generatePostText() -> String {
        let typeName = post.activityData.activityType.rawValue.capitalized
        return "Ha completado una sesión de \(typeName) y ha ganado \(post.activityData.xpEarned) XP."
    }
    
    private func statItem(value: String, label: String, icon: String, valueColor: Color = .white) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(valueColor)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
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
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func formatAbsoluteDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

import SwiftUI

struct ActivitySummaryCard: View {
    let activity: ActivitySession
    
    private var distanceText: String {
        let km = activity.distanceMeters / 1000.0
        return String(format: "%.1f km", km)
    }
    
    private var durationText: String {
        let hours = Int(activity.durationSeconds) / 3600
        let minutes = (Int(activity.durationSeconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: activity.startDate)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Activity Icon with category color
            ZStack {
                Circle()
                    .fill(activity.activityType.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: activity.activityType.iconName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(activity.activityType.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(activity.locationLabel ?? activity.displayName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if activity.locationLabel != nil {
                        Text(activity.activityType.displayName.uppercased())
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(durationText)
                    Text("·")
                    Text(dateText)
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(distanceText)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                
                if let xp = activity.xpBreakdown?.total, xp > 0 {
                    Text("+\(xp) XP")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "3DF68B"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "3DF68B").opacity(0.1))
                        .cornerRadius(4)
                } else if activity.processingStatus != .completed {
                     ProgressView()
                        .scaleEffect(0.6)
                        .tint(.gray)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .background(BlurView(style: .systemThinMaterialDark).cornerRadius(16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// Helper to support older iOS versions or custom blur if needed
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ActivitySummaryCard(activity: ActivitySession(
            startDate: Date(),
            endDate: Date(),
            activityType: .run,
            distanceMeters: 5200,
            durationSeconds: 1800,
            route: [],
            locationLabel: "El Retiro",
            processingStatus: .completed
        ))
        .padding()
    }
}

import SwiftUI

struct RivalsRowView: View {
    let title: String
    let rivalries: [RivalryRelationship]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if !rivalries.isEmpty {
                    Text("\(rivalries.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            
            if rivalries.isEmpty {
                Text("Aún no hay actividad reciente.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(rivalries) { rivalry in
                            RivalAvatarCell(rivalry: rivalry)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8) // Space for shadows and glows
                }
            }
        }
    }
}

struct RivalAvatarCell: View {
    let rivalry: RivalryRelationship
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Main Avatar with Dynamic Border
                ZStack {
                    if let urlString = rivalry.avatarURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .padding()
                                .background(Color(hex: "2C2C2E"))
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .resizable()
                            .padding(16)
                            .frame(width: 64, height: 64)
                            .foregroundColor(.white.opacity(0.5))
                            .background(Color(hex: "2C2C2E"))
                            .clipShape(Circle())
                    }
                }
                .overlay(
                    Circle()
                        .stroke(rivalry.isUserLeading ? Color(hex: "32D74B") : Color(hex: "FF3B30"), lineWidth: 3)
                )
                .glowPulse(isActive: rivalry.isVengeancePending, color: Color(hex: "FF3B30"))
                .shadow(color: (rivalry.isUserLeading ? Color(hex: "32D74B") : Color(hex: "FF3B30")).opacity(0.3), radius: 8)
                
                // User Score (Top Left)
                ScoreBadge(score: rivalry.userScore, color: Color(hex: "007AFF"), alignment: .topLeading)
                
                // Rival Score (Bottom Right)
                ScoreBadge(score: rivalry.rivalScore, color: Color(hex: "FF3B30"), alignment: .bottomTrailing)
                
                // Vengeance Icon (Middle Right-ish)
                if rivalry.isVengeancePending {
                    Image(systemName: "flag.slash.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color(hex: "FF3B30"))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                        .offset(x: 28, y: -18)
                }
            }
            .frame(width: 72, height: 72)
            
            // Info text
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text(rivalry.displayName)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    TrendIndicator(trend: rivalry.trend)
                }
                
                Text(formatRelativeTime(rivalry.lastInteractionAt))
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                
                if rivalry.isVengeancePending {
                    Text("Venganza disponible")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(Color(hex: "FF3B30"))
                        .textCase(.uppercase)
                        .padding(.top, 2)
                }
            }
            .frame(width: 100)
        }
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ScoreBadge: View {
    let score: Int
    let color: Color
    let alignment: Alignment
    
    var body: some View {
        ZStack {
            Text("\(score)")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.black, lineWidth: 2))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .offset(x: alignment == .topLeading ? -8 : 8, y: alignment == .topLeading ? -8 : 8)
    }
}

struct TrendIndicator: View {
    let trend: RankingTrend
    
    var body: some View {
        Group {
            switch trend {
            case .up:
                Image(systemName: "arrow.up.right")
                    .foregroundColor(.green)
            case .down:
                Image(systemName: "arrow.down.right")
                    .foregroundColor(.red)
            case .neutral:
                EmptyView()
            }
        }
        .font(.system(size: 10, weight: .bold))
    }
}


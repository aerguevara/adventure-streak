import SwiftUI

struct TerritoryOwnerCard: View {
    let ownerName: String
    let territoryId: String
    let avatarData: Data?
    let ownerIcon: String?
    let xp: Int?
    let territories: Int?
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with Avatar and Names
            HStack(spacing: 16) {
                // Large Avatar with Ring
                ZStack {
                    if let data = avatarData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 60, height: 60)
                    }
                    
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "4C6FFF"), Color(hex: "A259FF")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 66, height: 66)
                    
                    // Map Icon Badge
                    if let icon = ownerIcon {
                        Text(icon)
                            .font(.system(size: 18))
                            .padding(4)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                            .offset(x: 24, y: 24)
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(ownerName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Territorio \(territoryId)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            // Stats Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
            
            // Stats Row
            HStack(spacing: 24) {
                MapStatItem(icon: "star.fill", value: "\(xp ?? 0) XP", color: Color(hex: "A259FF"))
                MapStatItem(icon: "map.fill", value: "\(territories ?? 0) ZONAS", color: Color(hex: "32D74B"))
                Spacer()
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .padding(16)
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
    }
}

struct MapStatItem: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

import SwiftUI
import CoreLocation
import FirebaseStorage

struct VulnerableTerritoryCard: View {
    let item: TerritoryInventoryItem
    var onShowOnMap: (String) -> Void
    
    @State private var thiefAvatarURL: URL?
    
    // Logic extraction
    private var isHotSpot: Bool {
        item.territories.contains { $0.isHotSpot == true }
    }
    
    // If not vengeance, check expiry
    private var timeRemaining: TimeInterval {
        item.expiresAt.timeIntervalSince(Date())
    }
    
    private var isExpired: Bool {
        timeRemaining <= 0
    }
    
    private var cardColor: Color {
        if item.isVengeance { return Color(hex: "FF3B30") } // Red
        if isHotSpot { return .orange }
        if isExpired { return .gray }
        return .yellow // Expiring soon
    }
    
    private var scopeIcon: String {
        if item.isVengeance { return "scope" }
        if isHotSpot { return "flame.fill" }
        return "clock.fill"
    }
    
    private var statusTitle: String {
        if item.isVengeance { return "¡RECUPERA TU TERRITORIO!" }
        if isHotSpot { return "ZONA DE CONFLICTO" }
        if isExpired { return "ÚLTIMA OPORTUNIDAD" }
        return "VENCE PRONTO"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Graphical Element (Map + Avatar)
            ZStack(alignment: .bottomTrailing) {
                // Map Element
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 70, height: 70)
                    
                    TerritoryMinimapView(territories: item.territories)
                        .frame(width: 70, height: 70)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(cardColor.opacity(0.8), lineWidth: 2)
                        )
                    
                    // Scope Overlay
                    Image(systemName: scopeIcon)
                        .font(.system(size: item.isVengeance ? 30 : 24, weight: .light))
                        .foregroundColor(cardColor.opacity(0.6))
                }
                
                // Avatar (Only for Vengeance)
                if item.isVengeance {
                    ZStack {
                        if let url = thiefAvatarURL {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
                    .shadow(radius: 4)
                    .offset(x: 4, y: 4)
                }
            }
            
            // Right: Content
            VStack(alignment: .leading, spacing: 4) {
                // Urgency Badge
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text(statusTitle)
                        .font(.system(size: 10, weight: .black))
                }
                .foregroundColor(cardColor)
                .padding(.bottom, 2)
                
                // Location Name
                Text(item.locationLabel)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                // Context Info
                if let thievery = item.thieveryData, item.isVengeance {
                    Text("Robado por \(thievery.thiefName)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                } else if isExpired {
                    Text("Expiró hace \(timeString(from: abs(timeRemaining)))")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                } else {
                    Text("Vence en \(timeString(from: timeRemaining))")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(cardColor)
                }
                
                // Tiny Action Hint
                HStack(spacing: 4) {
                    Image(systemName: "map.fill")
                    Text("Toca para ubicar")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 4)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.3))
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(16)
        // Keep it flexible width
        .frame(width: 300) 
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(cardColor.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: cardColor.opacity(0.15), radius: 10, x: 0, y: 5)
        .onTapGesture {
            if let cell = item.territories.first {
                onShowOnMap(cell.id)
            }
        }
        .task {
            if item.isVengeance {
                await loadAvatarURL()
            }
        }
    }
    
    private func timeString(from interval: TimeInterval) -> String {
        let absInterval = abs(interval)
        let hours = Int(absInterval) / 3600
        let minutes = Int(absInterval) % 3600 / 60
        if hours > 24 {
            return "\(hours/24)d \(hours%24)h"
        }
        return "\(hours)h \(minutes)m"
    }
    
    private func loadAvatarURL() async {
        guard let thiefId = item.thieveryData?.thiefId else { return }
        // Simple logic to try fetching avatar URL. 
        // We assume standard path. If it fails, we just don't show it.
        let storageRef = Storage.storage().reference().child("users/\(thiefId)/avatar.jpg")
        do {
            let url = try await storageRef.downloadURL()
            self.thiefAvatarURL = url
        } catch {
            print("Failed to load thief avatar: \(error)")
        }
    }
}

import SwiftUI
import CoreLocation
import FirebaseStorage

struct VulnerableTerritoryCard: View {
    let item: TerritoryInventoryItem
    var onShowOnMap: (String) -> Void
    
    @State private var thiefAvatarURL: URL?
    
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
                                .stroke(Color(hex: "FF3B30").opacity(0.8), lineWidth: 2)
                        )
                    
                    // Scope Overlay
                    Image(systemName: "scope")
                        .font(.system(size: 30, weight: .light))
                        .foregroundColor(Color(hex: "FF3B30").opacity(0.6))
                }
                
                // Thief Avatar
                if let _ = item.thieveryData {
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
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text("¡RECUPERA TU TERRITORIO!")
                        .font(.system(size: 10, weight: .black))
                }
                .foregroundColor(Color(hex: "FF3B30"))
                .padding(.bottom, 2)
                
                // Location Name
                Text(item.locationLabel)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                // Thief Info
                if let thievery = item.thieveryData {
                    Text("Robado por \(thievery.thiefName)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
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
        // Keep it flexible width instead of fixed 220
        .frame(width: 300) 
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "FF3B30").opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color(hex: "FF3B30").opacity(0.15), radius: 10, x: 0, y: 5)
        .onTapGesture {
            if let cell = item.territories.first {
                onShowOnMap(cell.id)
            }
        }
        .task {
            await loadAvatarURL()
        }
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

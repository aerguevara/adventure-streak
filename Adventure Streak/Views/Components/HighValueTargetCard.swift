import SwiftUI
import CoreLocation
#if canImport(FirebaseStorage)
import FirebaseStorage
#elseif canImport(Firebase)
import Firebase
#endif

struct HighValueTargetItem: Identifiable {
    let id: String
    let ownerId: String
    let ownerName: String
    let ownerIcon: String?
    let ownerAvatarURL: URL?
    let locationLabel: String
    let lootXP: Int
    let ageInDays: Int
    let territories: [TerritoryCell]
}

struct HighValueTargetCard: View {
    let item: HighValueTargetItem
    @State private var avatarURL: URL?
    
    private var cardColor: Color { Color(hex: "FFD700") } // Gold
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Graphical Element (Map + Avatar)
            ZStack(alignment: .bottomTrailing) {
                // Map Element
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 70, height: 70)
                    
                    TerritoryMinimapView(territories: item.territories, tintColor: cardColor)
                        .frame(width: 70, height: 70)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(cardColor.opacity(0.8), lineWidth: 2)
                        )
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundColor(cardColor.opacity(0.6))
                }
                
                // Owner Avatar
                ZStack {
                    if let url = avatarURL ?? item.ownerAvatarURL {
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
                .background(Color.black)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.black, lineWidth: 2))
                .shadow(radius: 4)
                .offset(x: 4, y: 4)
            }
            
            // Right: Content
            VStack(alignment: .leading, spacing: 4) {
                // Treasure Badge
                HStack(spacing: 4) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.system(size: 10))
                    Text("TESORO DISPONIBLE")
                        .font(.system(size: 10, weight: .black))
                }
                .foregroundColor(cardColor)
                .padding(.bottom, 2)
                
                // Location Name
                Text(item.locationLabel)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Loot Info
                Text("+\(item.lootXP) XP acumulados")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(cardColor)
                
                Text("Antigüedad: \(item.ageInDays) días")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
                
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
        .frame(width: 300)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(cardColor.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: cardColor.opacity(0.1), radius: 10, x: 0, y: 5)
        .task {
            await loadAvatarURL()
        }
    }
    
    private func loadAvatarURL() async {
        // First check if we already have one
        if item.ownerAvatarURL != nil { return }
        
        // Construct standard path
        let storageRef = Storage.storage().reference().child("users/\(item.ownerId)/avatar.jpg")
        do {
            let url = try await storageRef.downloadURL()
            self.avatarURL = url
        } catch {
            // Quiet fail
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HighValueTargetCard(item: HighValueTargetItem(
            id: "1",
            ownerId: "u1",
            ownerName: "Xavi",
            ownerIcon: "🏃‍♂️",
            ownerAvatarURL: nil,
            locationLabel: "Parque del Retiro, Madrid",
            lootXP: 340,
            ageInDays: 170,
            territories: []
        ))
    }
}

import SwiftUI

struct RivalsRowView: View {
    let title: String
    let rivals: [Rival]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if !rivals.isEmpty {
                    Text("\(rivals.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.15))
                        .foregroundColor(color)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            
            if rivals.isEmpty {
                Text("Aún no hay actividad reciente.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(rivals) { rival in
                            RivalAvatarCell(rival: rival, color: color)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4) // Space for shadows
                }
            }
        }
    }
}

struct RivalAvatarCell: View {
    let rival: Rival
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                // Avatar
                if let urlString = rival.avatarURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .padding()
                            .background(Color(hex: "2C2C2E"))
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                } else {
                    Image(systemName: "person.fill")
                        .resizable()
                        .padding(14)
                        .frame(width: 56, height: 56)
                        .foregroundColor(.white.opacity(0.5))
                        .background(Color(hex: "2C2C2E"))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                
                // Interaction Count Badge
                Text("\(rival.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(color)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
                    .offset(x: 4, y: 0)
            }
            
            // Name & Date
            VStack(spacing: 2) {
                Text(rival.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(formatRelativeTime(rival.lastInteractionAt))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(width: 90)
        }
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

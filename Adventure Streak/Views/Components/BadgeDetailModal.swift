import SwiftUI

struct BadgeDetailModal: View {
    let badge: Badge
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "1C1C1E").ignoresSafeArea()
            
            // Decorative Background Glow
            Circle()
                .fill(badgeColor.opacity(0.2))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
            
            VStack(spacing: 30) {
                // Close Handle
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                
                Spacer()
                
                // 3D Badge (Large Spin Animation could be added)
                ThreeDBadgeView(badge: badge, size: 200)
                    .shadow(color: badgeColor.opacity(0.5), radius: 30, x: 0, y: 15)
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6), value: true) // Simple entry animation trigger if State used
                
                VStack(spacing: 16) {
                    Text(badge.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(badge.category.rawValue.capitalized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(badgeColor.opacity(0.2))
                        .foregroundColor(badgeColor)
                        .clipShape(Capsule())
                    
                    Text(badge.longDescription)
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .lineLimit(4)
                    
                    if badge.isUnlocked {
                        HStack(spacing: 4) {
                             Image(systemName: "checkmark.seal.fill")
                            Text("Conseguido")
                        }
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.top, 8)
                    } else {
                        HStack(spacing: 4) {
                             Image(systemName: "lock.fill")
                            Text("Bloqueado")
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                    }
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Text("Cerrar")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }
    
    var badgeColor: Color {
        switch badge.category {
        case .aggressive: return Color(hex: "FF3B30")
        case .social: return Color(hex: "5856D6")
        case .training: return Color(hex: "32D74B")
        }
    }
}

import SwiftUI

struct ThreeDBadgeView: View {
    let badge: Badge
    let size: CGFloat
    
    // Compute colors based on category
    var baseColor: Color {
        switch badge.category {
        case .aggressive: return Color(hex: "FF3B30") // Red
        case .social: return Color(hex: "5856D6") // Purple
        case .training: return Color(hex: "32D74B") // Green
        }
    }
    
    var body: some View {
        ZStack {
            // 1. Outer Ring / Rim (Simulating 3D thickness)
            HexagonShape()
                .fill(
                    LinearGradient(
                        colors: [
                            baseColor.opacity(0.8),
                            baseColor.opacity(0.4),
                            baseColor.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: baseColor.opacity(0.5), radius: 10, x: 0, y: 5) // Glow
            
            // 2. Inner Face (Slightly smaller)
            HexagonShape()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.2),
                            Color.black.opacity(0.8)
                        ],
                        center: .center,
                        startRadius: size * 0.1,
                        endRadius: size * 0.6
                    )
                )
                .frame(width: size * 0.85, height: size * 0.85)
                .overlay(
                    HexagonShape()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .clear, .white.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
            
            // 3. Icon (Floating)
            Group {
                if badge.iconSystemName.count < 3 {
                    Text(badge.iconSystemName)
                        .font(.system(size: size * 0.4))
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 4)
                } else {
                    Image(systemName: badge.iconSystemName)
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 4)
                }
            }
            // 4. Locked State Overlay
            if !badge.isUnlocked {
                Color.black.opacity(0.7)
                    .clipShape(HexagonShape())
                    .frame(width: size, height: size)
                
                Image(systemName: "lock.fill")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: size * 0.3))
            }
        }
    }
}

// Simple Hexagon Shape
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        
        // Hexagon points
        // Point 1: Top Center
        path.move(to: CGPoint(x: width * 0.5, y: 0))
        // Point 2: Top Right
        path.addLine(to: CGPoint(x: width * 0.95, y: height * 0.25))
        // Point 3: Bottom Right
        path.addLine(to: CGPoint(x: width * 0.95, y: height * 0.75))
        // Point 4: Bottom Center
        path.addLine(to: CGPoint(x: width * 0.5, y: height))
        // Point 5: Bottom Left
        path.addLine(to: CGPoint(x: width * 0.05, y: height * 0.75))
        // Point 6: Top Left
        path.addLine(to: CGPoint(x: width * 0.05, y: height * 0.25))
        
        path.closeSubpath()
        return path
    }
}

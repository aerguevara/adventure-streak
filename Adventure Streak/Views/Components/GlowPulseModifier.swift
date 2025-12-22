import SwiftUI

struct GlowPulseModifier: ViewModifier {
    var isActive: Bool
    var color: Color = .orange
    
    @State private var opacity: Double = 0.0
    @State private var scale: CGFloat = 0.95
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    if isActive {
                        RoundedRectangle(cornerRadius: 20) // Match card radius approximation
                            .fill(color)
                            .blur(radius: 20) // Soft diffused light
                            .opacity(opacity)
                            .scaleEffect(scale)
                    }
                }
            )
            .onAppear {
                if isActive {
                    // Start pulsing animation
                    withAnimation(Animation.easeInOut(duration: 1.5).repeatCount(3, autoreverses: true)) {
                        opacity = 0.6 // Reduce max opacity for subtlety
                        scale = 1.05  // Slight breathing expansion
                    }
                    
                    // Fade out completely after
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                        withAnimation(.easeOut(duration: 1.0)) {
                            opacity = 0.0
                            scale = 0.95
                        }
                    }
                }
            }
    }
}

extension View {
    func glowPulse(isActive: Bool = true, color: Color = .orange) -> some View {
        self.modifier(GlowPulseModifier(isActive: isActive, color: color))
    }
}

import SwiftUI

struct AnimatedBackgroundView: View {
    @State private var animate = false
    
    // Adventure Streak Colors
    private let color1 = Color(red: 0.1, green: 0.1, blue: 0.2) // Dark Blue/Grey
    private let color2 = Color(red: 0.2, green: 0.1, blue: 0.3) // Deep Purple
    private let color3 = Color(red: 0.8, green: 0.3, blue: 0.1) // Deep Orange (Burnt)
    
    var body: some View {
        ZStack {
            // Base background
            Color.black.ignoresSafeArea()
            
            // Animated Gradients
            ZStack {
                // Blob 1
                Circle()
                    .fill(color1)
                    .frame(width: 350, height: 350)
                    .blur(radius: 60)
                    .offset(x: animate ? -100 : 100, y: animate ? -100 : 100)
                
                // Blob 2
                Circle()
                    .fill(color2)
                    .frame(width: 400, height: 400)
                    .blur(radius: 60)
                    .offset(x: animate ? 100 : -100, y: animate ? 100 : -50)
                
                // Blob 3 (Accent)
                Circle()
                    .fill(color3.opacity(0.4))
                    .frame(width: 300, height: 300)
                    .blur(radius: 50)
                    .offset(x: animate ? -50 : 150, y: animate ? 150 : -150)
            }
            .scaleEffect(animate ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: animate)
        }
        .onAppear {
            animate = true
        }
    }
}

#Preview {
    AnimatedBackgroundView()
}

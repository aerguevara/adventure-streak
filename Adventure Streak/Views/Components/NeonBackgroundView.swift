import SwiftUI

struct NeonBackgroundView: View {
    let scrollOffset: CGFloat
    
    var body: some View {
        ZStack {
            // Capa 1: Fondo Parallax (Mesh Gradient)
            ZStack {
                LinearGradient(colors: [Color(hex: "08080A"), Color(hex: "121216")], startPoint: .top, endPoint: .bottom)
                
                Circle()
                    .fill(Color(hex: "4C6FFF").opacity(0.12))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .offset(x: -150, y: -200 + (scrollOffset * 0.1))
                
                Circle()
                    .fill(Color(hex: "A259FF").opacity(0.12))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: 150, y: 100 + (scrollOffset * 0.15))
            }
            .ignoresSafeArea()
            
            // Capa 2: Partículas Flotantes
            GeometryReader { geo in
                Canvas { context, size in
                    for i in 0..<20 {
                        let x = CGFloat((i * 137) % Int(size.width))
                        let y = CGFloat((i * 251) % Int(size.height * 2)) - (scrollOffset * 0.2)
                        let rect = CGRect(x: x, y: y, width: 2, height: 2)
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.2)))
                    }
                }
            }
            .ignoresSafeArea()
        }
    }
}

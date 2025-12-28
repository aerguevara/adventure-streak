import SwiftUI

// MARK: - Modern Models
struct ModernUser: Identifiable {
    let id = UUID()
    let name: String
    let xp: Int
    let rank: Int
    let isMe: Bool
    let color: Color
}

// MARK: - Main Preview
struct RankingImprovementsPreview: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            // Fondo Base Profundo
            Color(hex: "08080A").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Selector Minimalista
                HStack(spacing: 20) {
                    ForEach(0..<3) { index in
                        Button(action: { selectedTab = index }) {
                            VStack(spacing: 4) {
                                Text(["Neon Horizon", "Cinematic", "Parallax"][index])
                                    .font(.system(size: 14, weight: selectedTab == index ? .bold : .medium))
                                    .foregroundColor(selectedTab == index ? .white : .gray)
                                
                                if selectedTab == index {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 4, height: 4)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 20)
                
                // Content
                TabView(selection: $selectedTab) {
                    NeonHorizonView().tag(0)
                    CinematicSplitView().tag(1)
                    VerticalFlowView().tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
    }
}

// MARK: - Propuesta 1: Neon Horizon (v2)
struct NeonHorizonView: View {
    let users = [
        ModernUser(name: "Dania Perpiña", xp: 4143, rank: 1, isMe: false, color: .yellow),
        ModernUser(name: "Carlos Padina", xp: 3680, rank: 2, isMe: false, color: .gray),
        ModernUser(name: "Anyelo Reyes", xp: 3517, rank: 3, isMe: false, color: .orange),
        ModernUser(name: "Usuario simulador", xp: 3247, rank: 4, isMe: true, color: .blue),
        ModernUser(name: "Albanys Cuberos", xp: 742, rank: 5, isMe: false, color: .white),
        ModernUser(name: "Andrea Siles", xp: 472, rank: 6, isMe: false, color: .white)
    ]
    
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Capa 1: Fondo Parallax (Mesh Gradient)
            ZStack {
                LinearGradient(colors: [Color(hex: "0F172A"), Color(hex: "1E1B4B")], startPoint: .top, endPoint: .bottom)
                
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .offset(x: -100, y: -200 + (scrollOffset * 0.1))
                
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: 150, y: 100 + (scrollOffset * 0.15))
            }
            .ignoresSafeArea()
            
            // Capa 2: Partículas Flotantes
            GeometryReader { geo in
                Canvas { context, size in
                    for i in 0..<30 {
                        let x = CGFloat((i * 137) % Int(size.width))
                        let y = CGFloat((i * 251) % Int(size.height * 2)) - (scrollOffset * 0.2)
                        let rect = CGRect(x: x, y: y, width: 2, height: 2)
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.3)))
                    }
                }
            }
            .ignoresSafeArea()
            
            // Capa 3: Contenido
            ScrollView {
                VStack(spacing: 25) {
                    // Header con Avatar del Líder (Horizonte)
                    VStack(spacing: 20) {
                        ZStack {
                            // Halo de Poder
                            Circle()
                                .stroke(
                                    LinearGradient(colors: [.yellow, .orange, .clear], startPoint: .top, endPoint: .bottom),
                                    lineWidth: 2
                                )
                                .frame(width: 140, height: 140)
                                .rotationEffect(.degrees(scrollOffset * 0.5))
                            
                            // Avatar del Puesto 1
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60)
                                        .foregroundColor(.white.opacity(0.8))
                                )
                                .overlay(
                                    Circle().stroke(Color.yellow, lineWidth: 3)
                                )
                                .shadow(color: .yellow.opacity(0.5), radius: 20)
                            
                            // Corona
                            Image(systemName: "crown.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.yellow)
                                .offset(y: -70)
                                .shadow(color: .black, radius: 4)
                        }
                        .scaleEffect(max(1.0 - (scrollOffset * 0.001), 0.8))
                        .opacity(max(1.0 - (scrollOffset * 0.005), 0.0))
                        
                        VStack(spacing: 4) {
                            Text("Dania Perpiña")
                                .font(.system(size: 32, weight: .black))
                                .foregroundColor(.white)
                            
                            Text("LÍDER DEL HORIZONTE • 4.143 XP")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(3)
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(.top, 40)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: proxy.frame(in: .named("scroll")).minY)
                        }
                    )
                    
                    // Glass Cards con Parallax Individual
                    VStack(spacing: 15) {
                        ForEach(users.filter { $0.rank > 1 }) { user in
                            HStack(spacing: 15) {
                                Text("\(user.rank)")
                                    .font(.system(size: 18, weight: .black, design: .monospaced))
                                    .foregroundColor(user.color == .white ? .gray : user.color)
                                    .frame(width: 30)
                                
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 45, height: 45)
                                
                                VStack(alignment: .leading) {
                                    Text(user.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("\(user.xp) XP")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                
                                Spacer()
                                
                                if user.isMe {
                                    Text("TÚ")
                                        .font(.system(size: 10, weight: .black))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue)
                                        .cornerRadius(4)
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = -value
            }
        }
    }
}

// MARK: - Propuesta 2: Cinematic Split
struct CinematicSplitView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Split Screen Hero
            ZStack {
                HStack(spacing: 0) {
                    // Me Side
                    ZStack {
                        Color.blue.opacity(0.1)
                        VStack {
                            Spacer()
                            Text("TÚ")
                                .font(.system(size: 60, weight: .black))
                                .opacity(0.05)
                                .offset(y: 20)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Rival Side
                    ZStack {
                        Color.red.opacity(0.1)
                        VStack {
                            Spacer()
                            Text("RIVAL")
                                .font(.system(size: 60, weight: .black))
                                .opacity(0.05)
                                .offset(y: 20)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // The Contenders
                HStack {
                    VStack {
                        Image(systemName: "person.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                            .shadow(color: .blue, radius: 20)
                        Text("3.247").font(.system(size: 20, weight: .bold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    
                    Text("VS")
                        .font(.system(size: 30, weight: .black))
                        .italic()
                        .foregroundColor(.white)
                        .padding(15)
                        .background(Circle().fill(Color.black))
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    
                    VStack {
                        Image(systemName: "person.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red.opacity(0.8))
                            .shadow(color: .red, radius: 20)
                        Text("3.517").font(.system(size: 20, weight: .bold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 300)
            .clipped()
            
            // Battle Progress
            VStack(spacing: 20) {
                HStack {
                    Text("LA CAZA COMIENZA")
                        .font(.system(size: 10, weight: .black))
                        .tracking(3)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("DOMINA O CAE")
                        .font(.system(size: 10, weight: .black))
                        .tracking(3)
                        .foregroundColor(.red.opacity(0.5))
                }
                .padding(.horizontal)
                
                // Particle-like Progress
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 8)
                    
                    LinearGradient(colors: [.blue, .purple, .red], startPoint: .leading, endPoint: .trailing)
                        .mask(
                            Capsule().frame(width: 250, height: 8)
                        )
                        .shadow(color: .purple.opacity(0.5), radius: 6)
                }
                .padding(.horizontal)
                
                // Timer
                VStack(spacing: 5) {
                    Text("04:22:15")
                        .font(.system(size: 40, weight: .light, design: .monospaced))
                        .foregroundColor(.white)
                    Text("TIEMPO RESTANTE PARA EL IMPACTO")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)
            }
            .padding(.top, 30)
            
            Spacer()
        }
    }
}

// MARK: - Propuesta 3: Vertical Flow (Parallax)
struct VerticalFlowView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: -15) { // Overlap effect
                ForEach(0..<10) { index in
                    RankingLayer(index: index)
                        .zIndex(Double(10 - index))
                }
            }
            .padding(.top, 40)
        }
    }
}

struct RankingLayer: View {
    let index: Int
    
    var isMe: Bool { index == 4 }
    
    var body: some View {
        HStack {
            Text("#\(index + 1)")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(isMe ? .blue : .white.opacity(0.3))
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(isMe ? "TÚ" : "USUARIO \(index + 0)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text("\(5000 - (index * 400)) XP")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(isMe ? .blue : .gray)
            }
            
            Circle()
                .fill(isMe ? Color.blue : Color.white.opacity(0.1))
                .frame(width: 50, height: 50)
                .shadow(color: isMe ? .blue.opacity(0.5) : .clear, radius: 15)
        }
        .padding(25)
        .background(
            ZStack {
                Color(hex: isMe ? "101830" : "121216")
                
                if isMe {
                    LinearGradient(colors: [Color.blue.opacity(0.2), Color.clear], startPoint: .top, endPoint: .bottom)
                }
            }
        )
        .cornerRadius(25)
        .shadow(color: .black.opacity(0.5), radius: 10, y: 10)
        .padding(.horizontal, isMe ? 10 : 25)
        .scaleEffect(isMe ? 1.05 : 1.0)
    }
}

struct RankingImprovementsPreview_Previews: PreviewProvider {
    static var previews: some View {
        RankingImprovementsPreview()
            .preferredColorScheme(.dark)
    }
}

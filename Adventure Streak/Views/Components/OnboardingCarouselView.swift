import SwiftUI

struct OnboardingCarouselView: View {
    @State private var pageIndex = 0
    private let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    
    struct SlideData: Identifiable {
        let id = UUID()
        let image: String
        let title: String
        let subtitle: String
        let color: Color
    }
    
    private let slides = [
        SlideData(image: "map.fill", title: "Conquista", subtitle: "Reclama tu territorio y expande tu dominio.", color: .orange),
        SlideData(image: "trophy.fill", title: "Compite", subtitle: "Sube de rango y defiende tu corona.", color: .yellow),
        SlideData(image: "flame.fill", title: "Racha", subtitle: "Mantén tu constancia y supera tus límites.", color: .red)
    ]
    
    var body: some View {
        TabView(selection: $pageIndex) {
            ForEach(0..<slides.count, id: \.self) { index in
                VStack(spacing: 16) {
                    // Icon/Image
                    ZStack {
                        Circle()
                            .fill(slides[index].color.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .blur(radius: 20)
                        
                        Image(systemName: slides[index].image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .foregroundColor(.white)
                            .shadow(color: slides[index].color, radius: 10)
                    }
                    .padding(.bottom, 10)
                    
                    // Texts
                    VStack(spacing: 8) {
                        Text(slides[index].title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                        
                        Text(slides[index].subtitle)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: 280)
                            .lineLimit(2)
                    }
                }
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        .frame(height: 300)
        .onReceive(timer) { _ in
            withAnimation(.spring()) {
                pageIndex = (pageIndex + 1) % slides.count
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OnboardingCarouselView()
    }
}

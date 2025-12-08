import SwiftUI

struct MissionGuideView: View {
    private let rarities: [GuideItem] = [
        GuideItem(
            title: "Común",
            subtitle: "Base de progreso",
            description: "Actividades habituales que mantienen la racha. Otorgan XP estable y suelen requerir distancias o tiempos moderados.",
            color: Color.gray,
            icon: "leaf.fill"
        ),
        GuideItem(
            title: "Rara",
            subtitle: "Retos destacados",
            description: "Subidas de exigencia: más distancia, mayor tiempo o condiciones específicas (ritmo objetivo, defensa de territorio). Recompensa superior.",
            color: Color(hex: "4DA8FF"),
            icon: "sparkles"
        ),
        GuideItem(
            title: "Épica",
            subtitle: "Conquista clave",
            description: "Misiones con alto impacto: grandes distancias, múltiples territorios nuevos o esfuerzos largos. Otorgan mucho XP y suelen dar misiones únicas.",
            color: Color(hex: "C084FC"),
            icon: "flame.fill"
        ),
        GuideItem(
            title: "Legendaria",
            subtitle: "Hazaña excepcional",
            description: "Casos muy poco frecuentes: maratones personales, grandes reconquistas o eventos especiales. Máxima recompensa y rareza.",
            color: Color(hex: "FFAA33"),
            icon: "crown.fill"
        )
    ]
    
    private let categories: [GuideItem] = [
        GuideItem(
            title: "Territorial",
            subtitle: "Conquista y defensa",
            description: "Se centra en capturar, defender o reconquistar zonas del mapa. Afectan directamente a la dominación de territorios.",
            color: Color(hex: "34C759"),
            icon: "map.fill"
        ),
        GuideItem(
            title: "Esfuerzo físico",
            subtitle: "Reto deportivo",
            description: "Mide distancia, ritmo, desnivel o duración. Ejemplos: mantener un ritmo, superar kilómetros, sesiones largas.",
            color: Color(hex: "FF6B6B"),
            icon: "figure.run.circle.fill"
        ),
        GuideItem(
            title: "Progresión",
            subtitle: "Consistencia y racha",
            description: "Apunta a la continuidad: entrenar varios días seguidos, acumular semanas activas o mejorar marcas personales.",
            color: Color(hex: "4DA8FF"),
            icon: "chart.line.uptrend.xyaxis"
        ),
        GuideItem(
            title: "Social",
            subtitle: "Con la comunidad",
            description: "Interacción con otros: competir, seguir, compartir o defender frente a rivales. Refuerza el aspecto multijugador.",
            color: Color(hex: "A259FF"),
            icon: "person.2.fill"
        ),
        GuideItem(
            title: "Dinámica",
            subtitle: "Eventos especiales",
            description: "Misiones temporales o variables según contexto (clima, hora del día, temporada). Cambian con frecuencia.",
            color: Color(hex: "FFB740"),
            icon: "clock.badge.exclamationmark.fill"
        )
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Clases y Misiones")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Explora las rarezas de actividades y los tipos de misión. Toca una tarjeta para ver detalles.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                SectionView(title: "Rarezas de actividad", items: rarities)
                SectionView(title: "Categorías de misión", items: categories)
            }
            .padding()
        }
        .background(Color(hex: "000000").ignoresSafeArea())
        .navigationTitle("Misiones")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color(hex: "000000"), for: .navigationBar)
    }
}

private struct SectionView: View {
    let title: String
    let items: [GuideItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVStack(spacing: 12) {
                ForEach(items) { item in
                    NavigationLink(destination: MissionDetailView(item: item)) {
                        GuideCard(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct GuideCard: View {
    let item: GuideItem
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: item.icon)
                    .foregroundColor(item.color)
                    .font(.system(size: 22, weight: .bold))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.4))
        }
        .padding()
        .background(Color(hex: "111114"))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(item.color.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct MissionDetailView: View {
    let item: GuideItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(item.color.opacity(0.2))
                        .frame(width: 64, height: 64)
                    Image(systemName: item.icon)
                        .foregroundColor(item.color)
                        .font(.system(size: 28, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text(item.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Text(item.description)
                .font(.body)
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding()
        .background(Color(hex: "000000").ignoresSafeArea())
        .navigationTitle(item.title)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color(hex: "000000"), for: .navigationBar)
    }
}

private struct GuideItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let description: String
    let color: Color
    let icon: String
}

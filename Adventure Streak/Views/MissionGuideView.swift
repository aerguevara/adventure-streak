import SwiftUI

struct MissionGuideView: View {
    private let rarities: [GuideItem] = [
        GuideItem(
            title: "Común",
            subtitle: "Base de progreso",
            description: "Actividades habituales que mantienen la racha. Otorgan XP estable y suelen requerir distancias o tiempos moderados.",
            example: "Ejemplo: 3 km caminando en 30 min → ~40 XP. Si añades 1 territorio nuevo, +20 XP extra.",
            color: Color.gray,
            icon: "leaf.fill"
        ),
        GuideItem(
            title: "Rara",
            subtitle: "Retos destacados",
            description: "Subidas de exigencia: más distancia, mayor tiempo o condiciones específicas (ritmo objetivo, defensa de territorio). Recompensa superior.",
            example: "Ejemplo: 8 km a ritmo objetivo o defender 2 territorios → ~120 XP (80 base + 40 territorial).",
            color: Color(hex: "4DA8FF"),
            icon: "sparkles"
        ),
        GuideItem(
            title: "Épica",
            subtitle: "Conquista clave",
            description: "Misiones con alto impacto: grandes distancias, múltiples territorios nuevos o esfuerzos largos. Otorgan mucho XP y suelen dar misiones únicas.",
            example: "Ejemplo: 15 km con 4 territorios nuevos y 1 defendido → ~260 XP (160 base + 100 territorial).",
            color: Color(hex: "C084FC"),
            icon: "flame.fill"
        ),
        GuideItem(
            title: "Legendaria",
            subtitle: "Hazaña excepcional",
            description: "Casos muy poco frecuentes: maratones personales, grandes reconquistas o eventos especiales. Máxima recompensa y rareza.",
            example: "Ejemplo: media maratón + 6 territorios + reconquista masiva → 400+ XP (alto base + territorial + bonus evento).",
            color: Color(hex: "FFAA33"),
            icon: "crown.fill"
        )
    ]
    
    private let categories: [GuideItem] = [
        GuideItem(
            title: "Territorial",
            subtitle: "Conquista y defensa",
            description: "Se centra en capturar, defender o reconquistar zonas del mapa. Afectan directamente a la dominación de territorios.",
            example: "Ejemplo: +25 XP por territorio nuevo, +15 XP por defendido, +20 XP por reconquista (valores aproximados).",
            color: Color(hex: "34C759"),
            icon: "map.fill"
        ),
        GuideItem(
            title: "Esfuerzo físico",
            subtitle: "Reto deportivo",
            description: "Mide distancia, ritmo, desnivel o duración. Ejemplos: mantener un ritmo, superar kilómetros, sesiones largas.",
            example: "Ejemplo: 5 km run a ritmo objetivo → ~90 XP base.",
            color: Color(hex: "FF6B6B"),
            icon: "figure.run.circle.fill"
        ),
        GuideItem(
            title: "Progresión",
            subtitle: "Consistencia y racha",
            description: "Apunta a la continuidad: entrenar varios días seguidos, acumular semanas activas o mejorar marcas personales.",
            example: "Ejemplo: 4 días seguidos activos → bonus de racha acumulado (p.ej. +20 XP extra).",
            color: Color(hex: "4DA8FF"),
            icon: "chart.line.uptrend.xyaxis"
        ),
        GuideItem(
            title: "Social",
            subtitle: "Con la comunidad",
            description: "Interacción con otros: competir, seguir, compartir o defender frente a rivales. Refuerza el aspecto multijugador.",
            example: "Ejemplo: defensa frente a rival en el mapa → bonus de territorio y posible misión social.",
            color: Color(hex: "A259FF"),
            icon: "person.2.fill"
        ),
        GuideItem(
            title: "Dinámica",
            subtitle: "Eventos especiales",
            description: "Misiones temporales o variables según contexto (clima, hora del día, temporada). Cambian con frecuencia.",
            example: "Ejemplo: entreno al amanecer o con clima específico → bonus situacional.",
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
                
                XPCard()
                
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
            
            if let example = item.example {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ejemplo")
                        .font(.headline)
                        .foregroundColor(item.color)
                    Text(example)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
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
    let example: String?
    let color: Color
    let icon: String
}

private struct XPCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("¿Cómo calculamos el XP?")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Base por esfuerzo + bonus territorial + racha/misiones.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: "star.circle.fill")
                    .foregroundColor(Color(hex: "FFC300"))
                    .font(.system(size: 28))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Fórmula simplificada")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("""
Base por tipo y distancia/tiempo +
Territorios: +25 nuevo / +15 defensa / +20 reconquista (aprox) +
Misiones: según rareza (Común < Rara < Épica < Legendaria) +
Racha/consistencia: bonus creciente por días/semana activa.
""")
                .font(.callout)
                .foregroundColor(.white.opacity(0.8))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Ejemplo detallado")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("""
Sesión: 10 km run en 55 min
Base: ~140 XP (distancia/ritmo)
Territorio: 3 nuevos (+75 XP) + 1 defendido (+15 XP)
Misión: rara (p.ej. ritmo objetivo) +30 XP
Racha: semana activa +20 XP
Total aproximado: 280 XP
""")
                .font(.callout)
                .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding()
        .background(Color(hex: "111114"))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

import SwiftUI

struct ResetInfoView: View {
    @Environment(\.dismiss) var dismiss
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Background Glow
            RadialGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.15), Color.black]),
                center: .center,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Animated Icon Header
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .stroke(Color.blue.opacity(0.1), lineWidth: 8)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 60, weight: .light))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.blue)
                }
                .padding(.top, 20)
                
                VStack(spacing: 12) {
                    Text("NUEVA ERA")
                        .font(.caption)
                        .fontWeight(.black)
                        .foregroundColor(.blue)
                        .tracking(4)
                    
                    Text("Punto de Partida")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Diciembre 2025")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                }
                
                Text("Hemos optimizado el sistema de territorios y XP para una experiencia más justa y competitiva.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 40)
                
                // Highlights
                VStack(spacing: 20) {
                    ResetFeatureRow(
                        icon: "archivebox.fill",
                        title: "Historial Preservado",
                        description: "Tus datos anteriores al 1 de diciembre se han movido a tu archivo personal."
                    )
                    
                    ResetFeatureRow(
                        icon: "bolt.fill",
                        title: "XP Recalculado",
                        description: "Hemos procesado tus entrenos recientes para ajustar tu nivel actual."
                    )
                    
                    ResetFeatureRow(
                        icon: "map.fill",
                        title: "Mapa Global Reset",
                        description: "Los territorios están listos para ser reclamados de nuevo. ¡Sal ahí fuera!"
                    )
                }
                .padding(25)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 20)
                
                Spacer()
                
                Button(action: {
                    // Force clear ALL local data caches so the app
                    // reflects only the new post-reset state immediately.
                    ActivityStore.shared.clear()
                    TerritoryStore.shared.clear()
                    FeedRepository.shared.clear()
                    SocialService.shared.clear()
                    
                    onDismiss()
                    dismiss()
                }) {
                    Text("ENTENDIDO")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(Color.blue)
                                .shadow(color: Color.blue.opacity(0.4), radius: 10, x: 0, y: 5)
                        )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

struct ResetFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    ResetInfoView(onDismiss: {})
}

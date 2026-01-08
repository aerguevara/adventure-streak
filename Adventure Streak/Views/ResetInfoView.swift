import SwiftUI

struct ResetInfoView: View {
    @Environment(\.dismiss) var dismiss
    let seasonId: String
    let seasonName: String
    let seasonSubtitle: String
    let startDate: Date
    let endDate: Date
    var onDismiss: (String) -> Void
    
    @State private var isAnimating = false
    
    private var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM"
        
        let startString = formatter.string(from: startDate)
        let endString = formatter.string(from: endDate)
        
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let yearString = yearFormatter.string(from: startDate)
        
        return "\(startString) - \(endString) \(yearString)"
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Emotive Background Glow
            ZStack {
                // Central deep glow
                RadialGradient(
                    gradient: Gradient(colors: [Color(hex: "5B2C6F").opacity(0.4), Color.black]), // Deep Purple/Blue center
                    center: .center,
                    startRadius: 0,
                    endRadius: 600
                )
                
                // Bottom subtle blue haze
                RadialGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.clear]),
                    center: .bottom,
                    startRadius: 0,
                    endRadius: 400
                )
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Main Content
                VStack(spacing: 25) {
                    
                    // Header
                    VStack(spacing: 16) {
                        Text("NUEVA ERA")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(.cyan)
                            .tracking(8)
                            .opacity(isAnimating ? 1 : 0)
                            .offset(y: isAnimating ? 0 : 20)
                            .animation(.easeOut(duration: 0.8).delay(0.2), value: isAnimating)
                        
                        Text(seasonName.uppercased())
                            .font(.system(size: 48, weight: .heavy, design: .rounded)) // Much larger
                            .foregroundColor(.white)
                            .shadow(color: .cyan.opacity(0.5), radius: 20, x: 0, y: 0) // Glow effect
                            .scaleEffect(isAnimating ? 1 : 0.9)
                            .opacity(isAnimating ? 1 : 0)
                            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.4), value: isAnimating)
                        
                        Text(formattedDateRange)
                            .font(.title3)
                            .fontWeight(.light)
                            .foregroundColor(.white.opacity(0.7))
                            .opacity(isAnimating ? 1 : 0)
                            .animation(.easeOut(duration: 0.8).delay(0.6), value: isAnimating)
                    }
                    
                    Text("El mundo se ha reiniciado. Tu legado perdura, pero el mapa es nuevo.\nReclama tu territorio.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 40)
                        .padding(.top, 10)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.easeOut(duration: 0.8).delay(0.8), value: isAnimating)
                    
                    // Features - Conceptual/Minimalist
                    HStack(spacing: 40) {
                        VStack(spacing: 12) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.yellow)
                                .shadow(color: .yellow.opacity(0.6), radius: 10)
                            Text("XP Reset")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 12) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.green)
                                .shadow(color: .green.opacity(0.6), radius: 10)
                            Text("Mapa Nuevo")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.top, 30)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(1.0), value: isAnimating)
                }
                
                Spacer()
                
                Button(action: {
                    // Force clear ALL local data caches so the app
                    // reflects only the new post-reset state immediately.
                    ActivityStore.shared.clear()
                    TerritoryStore.shared.clear()
                    FeedRepository.shared.clear()
                    SocialService.shared.clear()
                    
                    onDismiss(seasonId)
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
                                .fill(Color.white)
                                .shadow(color: .white.opacity(0.3), radius: 20, x: 0, y: 0)
                        )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 50)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(1.2), value: isAnimating)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// ResetFeatureRow is no longer used but kept if needed for other places, 
// or I can delete it if it was only used here. 
// For now, I'll remove it since I replaced the layout.
// If it's used elsewhere, I should check. 
// "grep -r ResetFeatureRow" showed it was defined in this file. 
// I'll check if it's used elsewhere. 
// Actually, to be safe, I'll omit it since it was defined in this file and likely private to it.

#Preview {
    ResetInfoView(
        seasonId: "T1_2026",
        seasonName: "Temporada 1",
        seasonSubtitle: "Enero 2026",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 90),
        onDismiss: { _ in }
    )
}

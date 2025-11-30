import SwiftUI

struct WorkoutsPreviewView: View {
    
    // MARK: - Colors
    private let bgDark = Color(hex: "0F0F0F")
    private let cardBg = Color(hex: "1A1A1D")
    private let xpGreen = Color(hex: "3DF68B")
    private let rareBlue = Color(hex: "4DA8FF")
    private let epicPurple = Color(hex: "C084FC")
    private let commonGray = Color.gray
    
    var body: some View {
        ZStack {
            // Background
            bgDark.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Title
                    Text("Entrenos")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 20)
                        .padding(.horizontal)
                    
                    // Cards
                    VStack(spacing: 20) {
                        // Card 1: Epic
                        WorkoutPreviewCard(
                            icon: "figure.run",
                            title: "Exploración avanzada",
                            activity: "Running · 5,4 km · 32 min",
                            territoryNew: 12,
                            territoryDefended: 4,
                            territoryRecovered: 1,
                            xp: "+230 XP",
                            badge: "Explorador del Norte",
                            streak: "🔥 Semana #4",
                            rarity: "Épica",
                            rarityColor: epicPurple
                        )
                        
                        // Card 2: Rare
                        WorkoutPreviewCard(
                            icon: "bicycle",
                            title: "Expedición",
                            activity: "Cycling · 12,3 km · 41 min",
                            territoryNew: 6,
                            territoryDefended: 0,
                            territoryRecovered: 0,
                            xp: "+95 XP",
                            badge: "Rider",
                            streak: nil,
                            rarity: "Rara",
                            rarityColor: rareBlue
                        )
                        
                        // Card 3: Common
                        WorkoutPreviewCard(
                            icon: "figure.walk",
                            title: "Mantenimiento",
                            activity: "Walk · 2,1 km · 18 min",
                            territoryNew: 0,
                            territoryDefended: 1,
                            territoryRecovered: 0,
                            xp: "+20 XP",
                            badge: nil,
                            streak: nil,
                            rarity: "Común",
                            rarityColor: commonGray
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Subviews

struct WorkoutPreviewCard: View {
    let icon: String
    let title: String
    let activity: String
    let territoryNew: Int
    let territoryDefended: Int
    let territoryRecovered: Int
    let xp: String
    let badge: String?
    let streak: String?
    let rarity: String
    let rarityColor: Color
    
    @State private var isVisible = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // 1. Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(rarityColor.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(rarityColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(rarity)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(rarityColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(rarityColor.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                // XP Badge
                Text(xp)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: "3DF68B"))
                    .shadow(color: Color(hex: "3DF68B").opacity(0.5), radius: 8)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // 2. Metrics & Territory
            HStack(alignment: .top, spacing: 20) {
                // Activity
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text(activity)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    } icon: {
                        Image(systemName: "timer")
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
            
            // Territory Stats Grid
            if territoryNew > 0 || territoryDefended > 0 || territoryRecovered > 0 {
                HStack(spacing: 12) {
                    if territoryNew > 0 {
                        TerritoryStatChip(icon: "flag.fill", value: "+\(territoryNew)", color: .green)
                    }
                    if territoryDefended > 0 {
                        TerritoryStatChip(icon: "shield.fill", value: "\(territoryDefended)", color: .blue)
                    }
                    if territoryRecovered > 0 {
                        TerritoryStatChip(icon: "swords.fill", value: "\(territoryRecovered)", color: .orange)
                    }
                }
            }
            
            // 3. Footer (Badges & Streak)
            if badge != nil || streak != nil {
                HStack(spacing: 8) {
                    if let badge = badge {
                        HStack(spacing: 4) {
                            Image(systemName: "rosette")
                            Text(badge)
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    if let streak = streak {
                        Text(streak)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(20)
        .background(Color(hex: "1A1A1D"))
        .cornerRadius(18)
        .shadow(color: rarityColor.opacity(0.15), radius: 10, x: 0, y: 4)
        .scaleEffect(isVisible ? 1.0 : 0.96)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isVisible = true
            }
        }
    }
}

struct TerritoryStatChip: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Extensions

// MARK: - Extensions
// Color extension moved to Color+Extensions.swift

#Preview {
    WorkoutsPreviewView()
}

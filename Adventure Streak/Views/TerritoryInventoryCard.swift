import SwiftUI

struct EnergyProgressBar: View {
    let progress: Double // 0 to 1
    let color: Color
    let isUrgent: Bool
    
    @State private var pulseOpacity = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 6)
                
                // Progress
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(progress), height: 6)
                    .opacity(isUrgent ? pulseOpacity : 1.0)
            }
        }
        .frame(height: 6)
        .onAppear {
            if isUrgent {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseOpacity = 0.3
                }
            }
        }
    }
}

struct TerritoryInventoryCard: View {
    let item: TerritoryInventoryItem
    
    var body: some View {
        VStack(spacing: 12) {
            // Header: Status Badge
            HStack {
                if item.isVengeance {
                    Text("OBJETIVO")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8))
                        Text("+\(item.thieveryData != nil ? "20" : "25") XP")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4)
                } else {
                    Spacer()
                    Text(expirationText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            // Center: Minimap
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 80, height: 80)
                
                TerritoryMinimapView(territories: item.territories)
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(item.isVengeance ? Color.red.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1.5)
                    )
                    .shadow(color: item.isVengeance ? .red.opacity(0.4) : .clear, radius: 8)
                    // Visual "Target" overlay if vengeance
                    .overlay {
                        if item.isVengeance {
                            Image(systemName: "scope")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(.red.opacity(0.6))
                        }
                    }
            }
            .padding(.vertical, 4)
            
            // Footer: Info
            VStack(spacing: 4) {
                Text(item.locationLabel)
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(item.isVengeance ? .red : .white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let thievery = item.thieveryData {
                    VStack(spacing: 1) {
                        Text(thievery.thiefName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                        Text("hace \(relativeTime(thievery.stolenAt))")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                } else {
                    VStack(spacing: 6) {
                        EnergyProgressBar(progress: energyProgress, color: statusColor, isUrgent: isUrgent)
                            .padding(.top, 4)
                        
                        HStack(spacing: 4) {
                            Text("\(item.territories.count) zonas")
                            Spacer()
                            if isUrgent {
                                Text("+3 XP")
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                        }
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 140)
        .background(item.isVengeance ? Color.red.opacity(0.08) : Color.black.opacity(0.1))
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(item.isVengeance ? Color.red.opacity(0.5) : Color.white.opacity(0.12), lineWidth: item.isVengeance ? 1 : 0.5)
                .shadow(color: item.isVengeance ? .red.opacity(0.2) : .clear, radius: 8)
        )
    }
    
    private var expirationText: String {
        let remaining = item.expiresAt.timeIntervalSinceNow
        if remaining < 0 { return "Expirado" }
        
        let days = Int(remaining / 86400)
        if days > 0 {
            return "Vence en \(days)d"
        }
        
        let hours = Int(remaining / 3600)
        return "Vence en \(hours)h"
    }
    
    // Unified color logic
    private var statusColor: Color {
        let remaining = item.expiresAt.timeIntervalSinceNow
        
        if remaining < 0 { return .gray } // Expired -> Gray
        if remaining < 86400 * 3 { return .red } // < 3 days -> Red
        if remaining < 86400 * 7 { return .yellow } // < 7 days -> Yellow
        return .green // > 7 days -> Green
    }
    
    private var isUrgent: Bool {
        return item.expiresAt.timeIntervalSinceNow < 86400 * 3
    }
    
    private var energyProgress: Double {
        let maxDuration: TimeInterval = 30 * 86400
        let remaining = item.expiresAt.timeIntervalSinceNow
        return max(0, min(1.0, remaining / maxDuration))
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "es_ES")
        
        let relative = formatter.localizedString(for: date, relativeTo: Date())
        return relative.replacingOccurrences(of: "hace ", with: "")
    }
}

import SwiftUI

struct TerritoryInventoryCard: View {
    let item: TerritoryInventoryItem
    
    var body: some View {
        VStack(spacing: 12) {
            // Header: Status Badge
            HStack {
                if item.isVengeance {
                    Text("VENGANZA")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cyan.opacity(0.15))
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8))
                        Text("+25 XP")
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
                        .foregroundColor(isExpiringSoon ? .red : .green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((isExpiringSoon ? Color.red : Color.green).opacity(0.1))
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
                    .overlay(Circle().stroke(item.isVengeance ? Color.cyan.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1))
                    .shadow(color: item.isVengeance ? .cyan.opacity(0.3) : .clear, radius: 5)
            }
            .padding(.vertical, 4)
            
            // Footer: Info
            VStack(spacing: 2) {
                Text(item.locationLabel)
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(item.isVengeance ? .cyan : .white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let thievery = item.thieveryData {
                    VStack(spacing: 0) {
                        Text("hace \(relativeTime(thievery.stolenAt))")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                        Text("por \(thievery.thiefName)")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                } else {
                    Text("\(item.territories.count) zonas")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .frame(width: 140)
        .background(item.isVengeance ? Color.cyan.opacity(0.05) : Color.black.opacity(0.1))
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(item.isVengeance ? Color.cyan.opacity(0.5) : Color.white.opacity(0.12), lineWidth: item.isVengeance ? 1 : 0.5)
                .shadow(color: item.isVengeance ? .cyan.opacity(0.3) : .clear, radius: 8)
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
    
    private var isExpiringSoon: Bool {
        return item.expiresAt.timeIntervalSinceNow < 86400 // Less than 24h
    }
    
    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "es_ES")
        
        let relative = formatter.localizedString(for: date, relativeTo: Date())
        // Remove "hace " from the beginning to control it in the UI
        return relative.replacingOccurrences(of: "hace ", with: "")
    }
}

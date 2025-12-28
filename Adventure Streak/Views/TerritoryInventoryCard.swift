import SwiftUI

struct TerritoryInventoryCard: View {
    let item: TerritoryInventoryItem
    
    var body: some View {
        VStack(spacing: 12) {
            // Header: Expiration
            HStack {
                Spacer()
                Text(expirationText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isExpiringSoon ? .red : .green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isExpiringSoon ? Color.red : Color.green).opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Center: Minimap
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 80, height: 80)
                
                TerritoryMinimapView(territories: item.territories)
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .padding(.vertical, 4)
            
            // Footer: Title
            VStack(spacing: 2) {
                Text(item.locationLabel)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("\(item.territories.count) zonas")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .frame(width: 140)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
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
}

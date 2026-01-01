import SwiftUI
import CoreLocation

struct VulnerableTerritoryCard: View {
    let item: TerritoryInventoryItem
    var onShowOnMap: (String) -> Void
    
    // Threat detection
    private var isHotSpot: Bool {
        item.territories.contains { $0.isHotSpot == true }
    }
    
    private var timeRemaining: TimeInterval {
        item.expiresAt.timeIntervalSince(Date())
    }
    
    private var isExpired: Bool {
        timeRemaining <= 0
    }
    
    private var progress: Double {
        // Assume 7 days max duration for progress calculation
        let maxDuration: TimeInterval = 7 * 24 * 60 * 60
        let remaining = max(0, timeRemaining)
        return 1.0 - (remaining / maxDuration)
    }
    
    private var statusColor: Color {
        if isExpired { return .gray }
        let hours = timeRemaining / 3600
        if hours < 12 { return .red }
        if hours < 24 { return .yellow }
        return .green
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Name & Icons
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.locationLabel)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(item.territories.count) celdas")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if isHotSpot {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .shadow(color: .orange.opacity(0.5), radius: 4)
                            .font(.system(size: 14))
                    }
                    
                    if timeRemaining < 24 * 3600 && !isExpired {
                        Image(systemName: "clock.fill")
                            .foregroundColor(statusColor)
                            .font(.system(size: 14))
                    } else if isExpired {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                }
            }
            
            // Progress Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(isExpired ? "Expirado" : timeString(from: timeRemaining))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(statusColor)
                    
                    Spacer()
                    
                    Text(isExpired ? "YA EXPIRADO" : (isHotSpot ? "ZONA DE CONFLICTO" : "EXPIRA PRONTO"))
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(isExpired ? .gray : (isHotSpot ? .orange : .gray))
                }
                
                // Expiry Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(statusColor)
                            .frame(width: isExpired ? geo.size.width : geo.size.width * (1.0 - progress), height: 6)
                            .animation(.linear, value: progress)
                    }
                }
                .frame(height: 6)
            }
            
            // Action Button
            Button {
                if let cell = item.territories.first {
                    onShowOnMap(cell.id)
                }
            } label: {
                HStack {
                    Image(systemName: "map.fill")
                    Text("Ver en Mapa")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding(16)
        .frame(width: 220)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func timeString(from interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        if hours > 24 {
            return "\(hours/24)d \(hours%24)h"
        }
        return "\(hours)h \(minutes)m"
    }
}

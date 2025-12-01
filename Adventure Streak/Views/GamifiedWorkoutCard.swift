import SwiftUI

struct GamifiedWorkoutCard: View {
    let workout: WorkoutItemViewData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // 1. Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(workout.rarityColor.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(workout.rarityColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Mission name (if available) or activity title
                    if let missionName = workout.missionName {
                        Text(missionName)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    } else {
                        Text(workout.title.components(separatedBy: " · ").first ?? workout.title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Text(workout.rarity)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(workout.rarityColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(workout.rarityColor.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                // XP Badge
                if let xp = workout.xp {
                    Text("+\(xp) XP")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: "3DF68B"))
                        .shadow(color: Color(hex: "3DF68B").opacity(0.5), radius: 8)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // 2. Metrics & Territory
            HStack(alignment: .top, spacing: 20) {
                // Activity
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text("\(workout.type.displayName) · \(workout.title.components(separatedBy: " · ").last ?? "") · \(workout.duration)")
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
            if let new = workout.newTerritories, let def = workout.defendedTerritories, let rec = workout.recapturedTerritories, (new > 0 || def > 0 || rec > 0) {
                HStack(spacing: 12) {
                    if new > 0 {
                        TerritoryStatChip(icon: "flag.fill", value: "+\(new)", color: .green)
                    }
                    if def > 0 {
                        TerritoryStatChip(icon: "shield.fill", value: "\(def)", color: .blue)
                    }
                    if rec > 0 {
                        TerritoryStatChip(icon: "swords.fill", value: "\(rec)", color: .orange)
                    }
                }
            } else if let territoryXP = workout.territoryXP, territoryXP > 0 {
                 // Fallback for old data
                 TerritoryStatChip(icon: "globe.europe.africa.fill", value: "+\(territoryXP) XP", color: .green)
            }
            
            // 3. Footer (Badges & Streak)
            if workout.hasBadge || workout.isStreak || workout.isRecord {
                HStack(spacing: 8) {
                    if workout.hasBadge {
                        HStack(spacing: 4) {
                            Image(systemName: "rosette")
                            Text("Badge Earned")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    if workout.isStreak {
                        Text("Streak Active 🔥")
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
                    
                    if workout.isRecord {
                         Text("New Record 🏆")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.pink.opacity(0.2))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.pink.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(20)
        .background(Color(hex: "1A1A1D"))
        .cornerRadius(18)
        .shadow(color: workout.rarityColor.opacity(0.15), radius: 10, x: 0, y: 4)
        .shadow(color: workout.rarityColor.opacity(0.15), radius: 10, x: 0, y: 4)
    }
    
    var iconName: String {
        switch workout.type {
        case .run: return "figure.run"
        case .walk: return "figure.walk"
        case .bike: return "bicycle"
        case .hike: return "figure.hiking"
        case .otherOutdoor: return "figure.outdoor.cycle"
        }
    }
}

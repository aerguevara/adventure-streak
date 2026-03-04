import SwiftUI

struct GamifiedWorkoutCard: View {
    let workout: WorkoutItemViewData
    @State private var showReportOptions = false
    @State private var showReportingSuccess = false
    @ObservedObject private var supportService = SupportService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // 1. Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(workout.rarityColor.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: workout.type.iconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(workout.rarityColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if let missionName = workout.missionName {
                        Text(missionName)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    } else if let location = workout.locationLabel {
                        Text(location)
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
                    HStack(spacing: 8) {
                        if workout.processingStatus != .completed {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        
                        Text("+\(xp) XP")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(hex: "3DF68B"))
                            .shadow(color: Color(hex: "3DF68B").opacity(0.5), radius: 8)
                        
                        Menu {
                            Section("Reportar problema") {
                                ForEach(IncidentType.allCases, id: \.self) { type in
                                    Button {
                                        SupportService.shared.reportWorkoutIncident(activityId: workout.id, type: type)
                                    } label: {
                                        Label(type.displayName, systemImage: "exclamationmark.bubble")
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(8)
                        }
                    }
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Fechas de inicio y fin
            HStack(spacing: 12) {
                Label {
                    Text("Inicio \(workout.startDateTime)")
                } icon: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                
                Label {
                    Text("Fin \(workout.endDateTime)")
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            }
            
            // 2. Metrics & Territory
            HStack(alignment: .top, spacing: 20) {
                // Activity
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text("\(workout.type.displayName) · \(workout.title.components(separatedBy: " · ").last ?? "") · \(workout.duration)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "timer")
                            .foregroundColor(.gray)
                    }
                    
                    if let calories = workout.calories {
                        Label {
                            Text("\(Int(calories)) kcal")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        } icon: {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if let hr = workout.averageHeartRate {
                        Label {
                            Text("\(hr) ppm")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        } icon: {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                        }
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
                    if let stolen = workout.stolenTerritories, stolen > 0 {
                        TerritoryStatChip(icon: "flag.slash.fill", value: "\(stolen)", color: .red)
                    }
                    if rec > 0 {
                        TerritoryStatChip(icon: "swords.fill", value: "\(rec)", color: .orange)
                    }
                }
            } else if let territoryXP = workout.territoryXP, territoryXP > 0 {
                 // Fallback for old data
                 TerritoryStatChip(icon: "globe.europe.africa.fill", value: "+\(territoryXP) XP", color: .green)
            }
            
            // Social Conquest Section
            if let victims = workout.conqueredVictims, !victims.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CONQUISTAS")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.gray)
                        .tracking(1)
                    
                    HStack(spacing: -8) {
                        ForEach(victims.prefix(5), id: \.self) { victim in
                            Text(victim.prefix(1).uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color.blue.opacity(0.3)))
                                .overlay(Circle().stroke(Color.black, lineWidth: 1))
                        }
                        
                        if victims.count > 5 {
                            Text("+\(victims.count - 5)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.gray)
                                .padding(.leading, 12)
                        }
                        
                        let names = victims.joined(separator: ", ")
                        Text("Has conquistado a \(names)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.leading, victims.count > 5 ? 0 : 12)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 4)
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
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

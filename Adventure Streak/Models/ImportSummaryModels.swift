
import Foundation
import CoreLocation

/// Model to aggregate data for the post-processing summary modal
struct GlobalImportSummary {
    var processedCount: Int = 0
    var totalXP: Int = 0
    var totalNewTerritories: Int = 0
    var totalDefended: Int = 0
    var totalStolen: Int = 0
    var stolenVictims: Set<String> = [] // Names of players stolen from
    var locations: [String] = [] // Smart place names
    var totalDistance: Double = 0.0
    var totalRecaptured: Int = 0 
    var vengeanceFulfilledCount: Int = 0
    var durationSeconds: Double = 0.0
    var totalLootXP: Int = 0
    var totalConsolidationXP: Int = 0
    var totalStreakInterruptionXP: Int = 0
    // For the mini-map visualization
    var routeCoordinates: [[CLLocationCoordinate2D]] = []
    // NEW: Territory Polygons for map
    // NEW: Territories for map
    // NEW: Territories for map
    var territories: [RemoteTerritory] = []
    
    // NEW: Activity Type tracking for fallback visuals
    var mainActivityType: ActivityType?
    
    // NEW: Gamification Elements
    var completedMissions: [Mission] = []
    var highestRarity: String = "Común" // Común, Rara, Épica
    
    // Helper to prioritize rarity
    private func rank(_ rarity: String) -> Int {
        switch rarity {
        case "Épica": return 3
        case "Rara": return 2
        default: return 1
        }
    }
    
    // Mutating function to add data from a processed activity
    mutating func add(stats: TerritoryStats, xp: Int, distance: Double, duration: Double, victimNames: [String], location: String?, route: [RoutePoint], activityType: ActivityType? = nil) {
        self.processedCount += 1
        self.totalXP += xp
        self.totalDistance += distance
        self.durationSeconds += duration
        self.totalNewTerritories += stats.newCellsCount ?? 0
        self.totalDefended += stats.defendedCellsCount ?? 0
        self.totalStolen += stats.stolenCellsCount ?? 0
        self.totalRecaptured += stats.recapturedCellsCount ?? 0
        self.stolenVictims.formUnion(victimNames)
        if let loc = location, !loc.isEmpty {
            self.locations.append(loc)
        }
        
        if let type = activityType {
            self.mainActivityType = type
        }
        
        let coords = route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        if !coords.isEmpty {
            self.routeCoordinates.append(coords)
        }
    }
    
    // Overload to include missions, rarity AND territories
    mutating func add(stats: TerritoryStats, xp: Int, distance: Double, duration: Double, victimNames: [String], location: String? = nil, route: [RoutePoint] = [], missions: [Mission]?, rarity: String, territories: [RemoteTerritory]?, activityType: ActivityType? = nil) {
        // Call base add for core stats
        self.add(stats: stats, xp: xp, distance: distance, duration: duration, victimNames: victimNames, location: location, route: route, activityType: activityType)
        
        // Handle missions
        if let newMissions = missions {
            self.completedMissions.append(contentsOf: newMissions)
        }
        
        // Handle rarity
        if rank(rarity) > rank(self.highestRarity) {
            self.highestRarity = rarity
        }
        
        // Handle territories
        if let newTerritories = territories {
                self.territories.append(contentsOf: newTerritories)
        }
        
        // Handle new XP bonuses if available in Stats
        self.totalLootXP += stats.totalLootXP ?? 0
        self.totalConsolidationXP += stats.totalConsolidationXP ?? 0
        self.totalStreakInterruptionXP += stats.totalStreakInterruptionXP ?? 0
    }
}

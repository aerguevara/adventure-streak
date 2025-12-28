
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
    // For the mini-map visualization
    var routeCoordinates: [[CLLocationCoordinate2D]] = []
    // NEW: Territory Polygons for map
    var territoryPolygons: [[CLLocationCoordinate2D]] = []
    
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
    mutating func add(stats: TerritoryStats, xp: Int, victimNames: [String], location: String?, route: [RoutePoint]) {
        self.processedCount += 1
        self.totalXP += xp
        self.totalNewTerritories += stats.newCellsCount ?? 0
        self.totalDefended += stats.defendedCellsCount ?? 0
        self.totalStolen += stats.stolenCellsCount ?? 0
        self.stolenVictims.formUnion(victimNames)
        if let loc = location, !loc.isEmpty {
            self.locations.append(loc)
        }
        
        let coords = route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        if !coords.isEmpty {
            self.routeCoordinates.append(coords)
        }
    }
    
    // Overload to include missions, rarity AND territories
    mutating func add(stats: TerritoryStats, xp: Int, victimNames: [String], location: String?, route: [RoutePoint], missions: [Mission]?, rarity: String, territories: [RemoteTerritory]?) {
        // Call base add for core stats
        self.add(stats: stats, xp: xp, victimNames: victimNames, location: location, route: route)
        
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
            for territory in newTerritories {
                let polygon = territory.boundary.map { $0.coordinate }
                if !polygon.isEmpty {
                    self.territoryPolygons.append(polygon)
                }
            }
        }
    }
}

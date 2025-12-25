
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
    
    // Mutating function to add data from a processed activity
    mutating func add(stats: TerritoryStats, xp: Int, victimNames: [String], location: String?, route: [RoutePoint]) {
        self.processedCount += 1
        self.totalXP += xp
        self.totalNewTerritories += stats.newCellsCount
        self.totalDefended += stats.defendedCellsCount
        self.totalStolen += stats.recapturedCellsCount
        self.stolenVictims.formUnion(victimNames)
        if let loc = location, !loc.isEmpty {
            self.locations.append(loc)
        }
        
        let coords = route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        if !coords.isEmpty {
            self.routeCoordinates.append(coords)
        }
    }
}

import Foundation
import CoreLocation
import MapKit

struct TerritoryGrid {
    // Use a fixed degree step for stable grid alignment
    // 0.002 degrees is approx 222m at equator, getting smaller as we go north
    static let cellSizeDegrees: Double = 0.002
    static let daysToExpire: Int = 7
    
    static func cellIndex(for coordinate: CLLocationCoordinate2D) -> (x: Int, y: Int) {
        let xIndex = Int(floor(coordinate.longitude / cellSizeDegrees))
        let yIndex = Int(floor(coordinate.latitude / cellSizeDegrees))
        return (xIndex, yIndex)
    }
    
    static func cellCenter(x: Int, y: Int) -> CLLocationCoordinate2D {
        let lon = (Double(x) + 0.5) * cellSizeDegrees
        let lat = (Double(y) + 0.5) * cellSizeDegrees
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    static func cellId(x: Int, y: Int) -> String {
        return "\(x)_\(y)"
    }
    
    static func getCell(for coordinate: CLLocationCoordinate2D, ownerUserId: String? = nil, ownerDisplayName: String? = nil) -> TerritoryCell {
        let (x, y) = cellIndex(for: coordinate)
        let center = cellCenter(x: x, y: y)
        let id = cellId(x: x, y: y)
        
        // Calculate boundary immediately
        let halfSize = cellSizeDegrees / 2.0
        let boundary = [
            TerritoryPoint(latitude: center.latitude + halfSize, longitude: center.longitude - halfSize), // Top Left
            TerritoryPoint(latitude: center.latitude + halfSize, longitude: center.longitude + halfSize), // Top Right
            TerritoryPoint(latitude: center.latitude - halfSize, longitude: center.longitude + halfSize), // Bottom Right
            TerritoryPoint(latitude: center.latitude - halfSize, longitude: center.longitude - halfSize)  // Bottom Left
        ]
        
        return TerritoryCell(
            id: id,
            centerLatitude: center.latitude,
            centerLongitude: center.longitude,
            boundary: boundary,
            lastConqueredAt: Date(),
            expiresAt: Calendar.current.date(byAdding: .day, value: daysToExpire, to: Date())!,
            ownerUserId: ownerUserId,
            ownerDisplayName: ownerDisplayName,
            ownerUploadedAt: nil
        )
    }
    
    static func polygon(for cell: TerritoryCell) -> [CLLocationCoordinate2D] {
        let center = cell.centerCoordinate
        let halfSize = cellSizeDegrees / 2.0
        
        // Simple rectangle in Lat/Lon space
        // This ensures the polygon matches the grid index logic perfectly
        return [
            CLLocationCoordinate2D(latitude: center.latitude + halfSize, longitude: center.longitude - halfSize), // Top Left
            CLLocationCoordinate2D(latitude: center.latitude + halfSize, longitude: center.longitude + halfSize), // Top Right
            CLLocationCoordinate2D(latitude: center.latitude - halfSize, longitude: center.longitude + halfSize), // Bottom Right
            CLLocationCoordinate2D(latitude: center.latitude - halfSize, longitude: center.longitude - halfSize)  // Bottom Left
        ]
    }
    
    // Interpolate cells between two coordinates to avoid gaps
    static func cellsBetween(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) -> [TerritoryCell] {
        var cells: [TerritoryCell] = []
        
        let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLocation = CLLocation(latitude: end.latitude, longitude: end.longitude)
        let distance = startLocation.distance(from: endLocation)
        
        // If points are very close, just return the cell for the start point
        if distance < 10 { // 10 meters threshold
            return [getCell(for: start)]
        }
        
        // Interpolate points every 20 meters to ensure we hit every cell
        // 20m is much smaller than ~200m cell size, ensuring we don't skip corners
        let stepSize: Double = 20.0
        let steps = Int(ceil(distance / stepSize))
        
        for i in 0...steps {
            let fraction = Double(i) / Double(steps)
            let lat = start.latitude + (end.latitude - start.latitude) * fraction
            let lon = start.longitude + (end.longitude - start.longitude) * fraction
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            
            cells.append(getCell(for: coordinate))
        }
        
        return cells
    }
}

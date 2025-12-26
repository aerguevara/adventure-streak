import Foundation
import CoreLocation

struct RoutePoint: Codable, Identifiable {
    var id: UUID = UUID()
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let altitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(latitude: Double, longitude: Double, timestamp: Date, altitude: Double = 0) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.altitude = altitude
    }
    
    init(location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.timestamp = location.timestamp
        self.altitude = location.altitude
    }
}

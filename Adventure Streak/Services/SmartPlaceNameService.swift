import Foundation
import CoreLocation

/// Service responsible for generating "smart" semantic names for activities
/// based on their geographic location using Apple's Core Location (Free & Privacy-preserving).
class SmartPlaceNameService {
    static let shared = SmartPlaceNameService()
    
    private let geocoder = CLGeocoder()
    
    private init() {}
    
    /// Generates a semantic title like "Running in Retiro Park" or "Conquering Calle Gran Via"
    /// based on the route's centroid or most significant point.
    func generateSmartTitle(for route: [RoutePoint]) async -> String? {
        guard !route.isEmpty else { return nil }
        
        // 1. Calculate Centroid (Simple average)
        // Optimization: For long routes, maybe take the middle point or sample a few.
        // For territory purposes, the center of mass of the route is a good "Area" indicator.
        let latitudeSum = route.reduce(0.0) { $0 + $1.latitude }
        let longitudeSum = route.reduce(0.0) { $0 + $1.longitude }
        let count = Double(route.count)
        
        let centerLocation = CLLocation(
            latitude: latitudeSum / count,
            longitude: longitudeSum / count
        )
        
        // 2. Reverse Geocoding
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(centerLocation)
            guard let place = placemarks.first else { return nil }
            
            return constructSemanticLabel(from: place)
        } catch {
            print("⚠️ [SmartPlaceNameService] Geocoding failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Logic to prioritize specific sematic fields
    private func constructSemanticLabel(from place: CLPlacemark) -> String? {
        // Priority 1: Areas of Interest (Parks, Stadiums, Landmarks)
        if let interest = place.areasOfInterest?.first {
            return interest
        }
        
        // Priority 2: Street Name (Thoroughfare)
        if let street = place.thoroughfare {
            // Optional: Append number if available? "Calle Gran Via 22" -> might be too specific.
            return street
        }
        
        // Priority 3: Neighborhood (SubLocality)
        if let neighborhood = place.subLocality {
            return neighborhood
        }
        
        // Priority 4: City/Locality (Fallback)
        if let city = place.locality {
            return city
        }
        
        return nil
    }
}

import Foundation
import CoreLocation
import Combine

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var routePoints: [RoutePoint] = []
    @Published var isTracking = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    // NEW: Start getting location updates without recording a route
    func startMonitoring() {
        locationManager.startUpdatingLocation()
    }
    
    func startTracking() {
        routePoints = []
        isTracking = true
        locationManager.startUpdatingLocation()
    }
    
    func stopTracking() {
        isTracking = false
        // We might want to keep updating location for the map, but for now let's stop to save battery if not needed.
        // Actually, if we are on the map screen, we want updates.
        // But let's leave this as is for "stopping a workout".
        // locationManager.stopUpdatingLocation() 
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        
        DispatchQueue.main.async {
            self.currentLocation = latest
            
            if self.isTracking {
                let point = RoutePoint(location: latest)
                self.routePoints.append(point)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}

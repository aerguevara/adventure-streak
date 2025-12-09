import Foundation
import CoreLocation
import Combine

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var routePoints: [RoutePoint] = []
    @Published var isTracking = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private var isMonitoring = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    // NEW: Start getting location updates without recording a route
    func startMonitoring() {
        guard !isMonitoring, !isTracking else { return }
        isMonitoring = true
        locationManager.startUpdatingLocation()
    }
    
    func stopMonitoring() {
        guard !isTracking else { return }
        isMonitoring = false
        locationManager.stopUpdatingLocation()
    }
    
    func startTracking() {
        routePoints = []
        isTracking = true
        locationManager.startUpdatingLocation()
    }
    
    func stopTracking() {
        isTracking = false
        if !isMonitoring {
            locationManager.stopUpdatingLocation()
        }
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

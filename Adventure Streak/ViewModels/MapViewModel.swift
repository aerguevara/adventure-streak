import Foundation
import MapKit
import Combine
import SwiftUI

@MainActor
class MapViewModel: ObservableObject {
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default SF
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @Published var conqueredTerritories: [TerritoryCell] = []
    // NEW: Added for multiplayer conquest feature
    @Published var otherTerritories: [RemoteTerritory] = []
    
    @Published var activities: [ActivitySession] = []
    @Published var isTracking = false
    @Published var currentActivityDistance: Double = 0.0
    @Published var currentActivityDuration: TimeInterval = 0.0
    
    private let locationService: LocationService
    private let territoryStore: TerritoryStore
    private let activityStore: ActivityStore
    private let territoryService: TerritoryService
    // NEW: Repository for multiplayer
    private let territoryRepository = TerritoryRepository.shared
    
    private var timer: Timer?
    private var startTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    init(locationService: LocationService, territoryStore: TerritoryStore, activityStore: ActivityStore) {
        self.locationService = locationService
        self.territoryStore = territoryStore
        self.activityStore = activityStore
        self.territoryService = TerritoryService(territoryStore: territoryStore)
        
        setupBindings()
        // NEW: Start observing remote territories
        territoryRepository.observeTerritories()
    }
    
    private func setupBindings() {
        locationService.$currentLocation
            .compactMap { $0 }
            .first() // Only set initial region once
            .sink { [weak self] location in
                self?.region.center = location.coordinate
            }
            .store(in: &cancellables)
        
        territoryStore.$conqueredCells
            .map { Array($0.values) }
            .assign(to: &$conqueredTerritories)
            
        // NEW: Bind remote territories to view model with "Restore from Cloud" logic
        territoryRepository.$otherTerritories
            .combineLatest($conqueredTerritories)
            .receive(on: RunLoop.main)
            .map { [weak self] (remote, local) -> [RemoteTerritory] in
                guard let self = self else { return [] }
                let currentUserId = AuthenticationService.shared.userId ?? ""
                let localIds = Set(local.map { $0.id })
                
                // 1. Identify my territories that are missing locally (Restore)
                let myMissingTerritories = remote.filter { 
                    $0.userId == currentUserId && !localIds.contains($0.id ?? "")
                }
                
                if !myMissingTerritories.isEmpty {
                    print("Restoring \(myMissingTerritories.count) territories from cloud...")
                    let restoredCells = myMissingTerritories.map { remoteT -> TerritoryCell in
                        return TerritoryCell(
                            id: remoteT.id ?? "",
                            centerLatitude: remoteT.centerLatitude,
                            centerLongitude: remoteT.centerLongitude,
                            boundary: remoteT.boundary,
                            lastConqueredAt: remoteT.timestamp,
                            expiresAt: remoteT.expiresAt
                        )
                    }
                    // Async update to avoid publishing changes during view update
                    DispatchQueue.main.async {
                        self.territoryStore.upsertCells(restoredCells)
                    }
                }
                
                // 2. Return only TRUE rivals (not me, and not already local)
                return remote.filter { 
                    $0.userId != currentUserId && !localIds.contains($0.id ?? "")
                }
            }
            .assign(to: &$otherTerritories)
            
        activityStore.$activities
            .assign(to: &$activities)
        
        locationService.$routePoints
            .sink { [weak self] points in
                self?.calculateDistance(points: points)
            }
            .store(in: &cancellables)
    }
    
    func startActivity(type: ActivityType) {
        locationService.startTracking()
        isTracking = true
        startTime = Date()
        currentActivityDistance = 0
        currentActivityDuration = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let start = self.startTime else { return }
                self.currentActivityDuration = Date().timeIntervalSince(start)
            }
        }
    }
    
    func stopActivity(type: ActivityType) {
        locationService.stopTracking()
        isTracking = false
        timer?.invalidate()
        timer = nil
        
        guard let start = startTime else { return }
        let end = Date()
        
        let session = ActivitySession(
            startDate: start,
            endDate: end,
            activityType: type,
            distanceMeters: currentActivityDistance,
            durationSeconds: currentActivityDuration,
            route: locationService.routePoints
        )
        
        activityStore.saveActivity(session)
        let newCells = territoryService.processActivity(session)
        print("Conquered \(newCells) new cells")
    }
    
    private func calculateDistance(points: [RoutePoint]) {
        guard points.count > 1 else { return }
        var dist = 0.0
        for i in 0..<points.count-1 {
            let loc1 = CLLocation(latitude: points[i].latitude, longitude: points[i].longitude)
            let loc2 = CLLocation(latitude: points[i+1].latitude, longitude: points[i+1].longitude)
            dist += loc1.distance(from: loc2)
        }
        currentActivityDistance = dist
    }
}

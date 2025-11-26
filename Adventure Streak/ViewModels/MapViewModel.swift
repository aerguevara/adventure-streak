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
    
    // NEW: Loading state removed to allow map to load first
    // @Published var isLoading = true
    
    private let locationService: LocationService
    let territoryStore: TerritoryStore
    let activityStore: ActivityStore
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
    
    func checkLocationPermissions() {
        print("DEBUG: Checking location permissions...")
        locationService.requestPermission()
        locationService.startMonitoring()
    }
    
    @Published var visibleTerritories: [TerritoryCell] = []
    
    private func setupBindings() {
        locationService.$currentLocation
            .compactMap { $0 }
            .first() // Only set initial region once
            .sink { [weak self] location in
                self?.region.center = location.coordinate
            }
            .store(in: &cancellables)
        
        // OPTIMIZATION: Filter visible territories
        // Combine latest territories with latest visible region
        territoryStore.$conqueredCells
            .combineLatest($region.debounce(for: .milliseconds(500), scheduler: DispatchQueue.global(qos: .userInteractive)))
            .map { (cellsDict, region) -> [TerritoryCell] in
                // Filter for last 7 days
                let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                
                // 1. LOD Check: If zoomed out too far, don't render individual cells
                if region.span.latitudeDelta > 0.2 || region.span.longitudeDelta > 0.2 {
                    print("DEBUG: Zoomed out too far (Span: \(region.span.latitudeDelta)), hiding territories.")
                    return []
                }
                
                let allCells = Array(cellsDict.values)
                // Filter by date first
                let recentCells = allCells.filter { $0.lastConqueredAt >= sevenDaysAgo }
                
                // Simple bounding box check
                let minLat = region.center.latitude - region.span.latitudeDelta / 2
                let maxLat = region.center.latitude + region.span.latitudeDelta / 2
                let minLon = region.center.longitude - region.span.longitudeDelta / 2
                let maxLon = region.center.longitude + region.span.longitudeDelta / 2
                
                // Filter cells whose center is within the visible region (plus a small buffer)
                // AND validate geometry (must have at least 3 points)
                let visible = recentCells.filter { cell in
                    // Geometry check
                    guard cell.boundary.count >= 3 else { return false }
                    
                    // Visibility check
                    return cell.centerLatitude >= minLat && cell.centerLatitude <= maxLat &&
                           cell.centerLongitude >= minLon && cell.centerLongitude <= maxLon
                }
                
                print("DEBUG: Found \(visible.count) visible territories in region (Last 7 Days).")
                
                // 2. Hard Cap: Never return more than 500 polygons to keep UI smooth
                return Array(visible.prefix(500))
            }
            .receive(on: RunLoop.main)
            .assign(to: &$visibleTerritories)
        
        territoryStore.$conqueredCells
            .map { dict -> [TerritoryCell] in
                let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                return Array(dict.values).filter { $0.lastConqueredAt >= sevenDaysAgo }
            }
            .assign(to: &$conqueredTerritories)
            
        // NEW: Optimized pipeline - Process on background, update on main
        territoryRepository.$otherTerritories
            .combineLatest(territoryStore.$conqueredCells)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.global(qos: .userInitiated)) // Debounce to prevent thrashing
            .receive(on: DispatchQueue.global(qos: .userInitiated)) // Process in background
            .map { [weak self] (remote, localDict) -> [RemoteTerritory] in
                guard let self = self else { return [] }
                let currentUserId = AuthenticationService.shared.userId ?? ""
                let local = Array(localDict.values)
                let localIds = Set(local.map { $0.id })
                
                // 1. Identify my territories that are missing locally (Restore)
                let myMissingTerritories = remote.filter { 
                    $0.userId == currentUserId && !localIds.contains($0.id ?? "")
                }
                
                // Only restore if we have a significant number or it's a new batch
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
                    // Async update to store - This will trigger the pipeline again, but localIds will be updated next time
                    DispatchQueue.main.async {
                        self.territoryStore.upsertCells(restoredCells)
                    }
                }
                
                // 2. Return only TRUE rivals
                return remote.filter { 
                    $0.userId != currentUserId && !localIds.contains($0.id ?? "")
                }
            }
            .removeDuplicates() // Prevent UI updates if the list of rivals hasn't changed
            .receive(on: RunLoop.main) // Update UI on main
            .assign(to: &$otherTerritories)
            
        activityStore.$activities
            .map { activities -> [ActivitySession] in
                let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                return activities.filter { $0.startDate >= sevenDaysAgo }
            }
            .assign(to: &$activities)
        
        locationService.$routePoints
            .sink { [weak self] points in
                self?.calculateDistance(points: points)
            }
            .store(in: &cancellables)
    }
    
    func updateVisibleRegion(_ region: MKCoordinateRegion) {
        // Sync the view's region with the ViewModel
        // Wrap in async to avoid "Publishing changes from within view updates" warning
        DispatchQueue.main.async {
            self.region = region
        }
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
        
        Task {
            let userId = AuthenticationService.shared.userId ?? "unknown_user"
            
            // 1. Process Territories
            // Create temporary session for territory processing (without XP yet)
            let tempSession = ActivitySession(
                startDate: start,
                endDate: end,
                activityType: type,
                distanceMeters: currentActivityDistance,
                durationSeconds: currentActivityDuration,
                route: locationService.routePoints
            )
            
            let territoryStats = territoryService.processActivity(tempSession)
            
            // 2. Calculate XP
            var breakdown: XPBreakdown?
            do {
                let context = try await GamificationRepository.shared.buildXPContext(for: userId)
                breakdown = try await GamificationService.shared.computeXP(for: tempSession, territoryStats: territoryStats, context: context)
                
                if let breakdown = breakdown {
                    try await GamificationService.shared.applyXP(breakdown, to: userId, at: end)
                    print("XP Earned: \(breakdown.total)")
                }
            } catch {
                print("Error calculating XP: \(error)")
            }
            
            // 3. Save Activity with XP
            let finalSession = ActivitySession(
                startDate: start,
                endDate: end,
                activityType: type,
                distanceMeters: currentActivityDistance,
                durationSeconds: currentActivityDuration,
                route: locationService.routePoints,
                xpBreakdown: breakdown
            )
            
            activityStore.saveActivity(finalSession)
            
            // 4. Post to Feed
            if territoryStats.newCellsCount > 0 {
                let userName = AuthenticationService.shared.userName ?? "Un aventurero"
                
                let event = FeedEvent(
                    id: nil,
                    type: .territoryConquered,
                    date: Date(),
                    title: "Nueva conquista",
                    subtitle: "Has reclamado \(territoryStats.newCellsCount) nuevos territorios!",
                    xpEarned: territoryStats.newCellsCount * 10, // Example XP calc
                    userId: userId,
                    relatedUserName: userName,
                    miniMapRegion: nil, // Could calculate this from newCells if we wanted
                    badgeName: nil,
                    badgeRarity: nil,
                    isPersonal: true
                )
                FeedRepository.shared.postEvent(event)
            }
        }
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

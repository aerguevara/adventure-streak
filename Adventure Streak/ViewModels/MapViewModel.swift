import Foundation
import MapKit
import Combine
import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

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
    @Published var selectedTerritoryId: String?
    @Published var selectedTerritoryOwner: String?
    @Published var selectedTerritoryOwnerId: String?
    @Published var selectedTerritoryOwnerXP: Int?
    @Published var selectedTerritoryOwnerTerritories: Int?
    @Published var selectedTerritoryOwnerAvatarData: Data?
    @Published var selectedTerritoryOwnerIcon: String?
    @Published var userIcons: [String: String] = [:]
    // NEW: Version counter to trigger UI refreshes when icons are loaded
    @Published var iconVersion: Int = 0
    
    @Published var activities: [ActivitySession] = []
    @Published var isTracking = false
    @Published var currentActivityDistance: Double = 0.0
    @Published var currentActivityDuration: TimeInterval = 0.0
    
    // NEW: Loading state removed to allow map to load first
    // @Published var isLoading = true
    
    // NEW: Trigger for programmatic recentering
    @Published var shouldRecenter = false
    
    private let locationService: LocationService
    let territoryStore: TerritoryStore
    let activityStore: ActivityStore
    private let territoryService: TerritoryService
    // NEW: Repository for multiplayer
    private let territoryRepository = TerritoryRepository.shared
    private let configService: GameConfigService
    
    private var lastQueryRegion: MKCoordinateRegion?
    
    private var timer: Timer?
    private var startTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    init(
        locationService: LocationService,
        territoryStore: TerritoryStore,
        activityStore: ActivityStore,
        configService: GameConfigService
    ) {
        self.locationService = locationService
        self.territoryStore = territoryStore
        self.activityStore = activityStore
        self.territoryService = TerritoryService(territoryStore: territoryStore)
        self.configService = configService
        
        setupBindings()
        
        Task {
            await configService.loadConfigIfNeeded()
            
            // PRE-LOAD: Use AuthenticationService and Cache to avoid flickering
            let auth = AuthenticationService.shared
            if let userId = auth.userId {
                // 1. Try AuthenticationService (should have it if just logged in or synced)
                if let authIcon = auth.userMapIcon {
                    self.userIcons[userId] = authIcon
                    MapIconCacheManager.shared.setIcon(authIcon, for: userId)
                } 
                // 2. Try Cache fallback
                else if let cachedIcon = MapIconCacheManager.shared.getIcon(for: userId) {
                    self.userIcons[userId] = cachedIcon
                }
                // 3. Last resort: Fetch from Firestore
                else {
                    await fetchIcons(for: [userId])
                }
            }
        }
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
                // Initial fetch for the starting location
                self?.territoryRepository.observeTerritories(in: self?.region ?? MKCoordinateRegion())
            }
            .store(in: &cancellables)
        
        // NEW: Region change listener with debounce for remote territories
        $region
            .debounce(for: .seconds(1.0), scheduler: RunLoop.main)
            .sink { [weak self] newRegion in
                guard let self = self else { return }
                
                // Only query if the region has changed significantly (e.g. > 20% of the span)
                if let last = self.lastQueryRegion {
                    let latChange = abs(newRegion.center.latitude - last.center.latitude)
                    let lonChange = abs(newRegion.center.longitude - last.center.longitude)
                    let significantThreshold = 0.2
                    
                    if latChange < last.span.latitudeDelta * significantThreshold &&
                       lonChange < last.span.longitudeDelta * significantThreshold &&
                       abs(newRegion.span.latitudeDelta - last.span.latitudeDelta) < last.span.latitudeDelta * significantThreshold {
                        return // Not significant enough
                    }
                }
                
                print("[Map] Triggering region-based territory fetch...")
                self.lastQueryRegion = newRegion
                self.territoryRepository.observeTerritories(in: newRegion)
            }
            .store(in: &cancellables)
        
        // OPTIMIZATION: Filter visible territories
        // Combine latest territories with latest visible region
        territoryStore.$conqueredCells
            .combineLatest($region.debounce(for: .milliseconds(500), scheduler: DispatchQueue.global(qos: .userInteractive)))
            .combineLatest(configService.$config)
            .map { combined, config -> [TerritoryCell] in
                let (cellsDict, region) = combined
                
                let allCells = Array(cellsDict.values)
                let recentCells = allCells // Show everything
                
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
                
                print("DEBUG: Found \(visible.count) visible territories in region (Filtered by config window).")
                
                // 2. Hard Cap: Never return more than 500 polygons to keep UI smooth
                let result = Array(visible.prefix(500))
                
                // NEW: Trigger icon fetch for local territories if needed
                let owners = Set(result.compactMap { $0.ownerUserId })
                if !owners.isEmpty {
                    Task { [weak self] in
                        await self?.fetchIcons(for: owners)
                    }
                }
                
                return result
            }
            .receive(on: RunLoop.main)
            .assign(to: &$visibleTerritories)
        
        territoryStore.$conqueredCells
            .map { dict in
                Array(dict.values)
            }
            .assign(to: &$conqueredTerritories)
            
        // NEW: Optimized pipeline - Process on background, update on main
        territoryRepository.$otherTerritories
            .combineLatest(territoryStore.$conqueredCells, AuthenticationService.shared.$userId)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.global(qos: .userInitiated)) // Debounce to prevent thrashing
            .receive(on: DispatchQueue.global(qos: .userInitiated)) // Process in background
            .map { [weak self] (remote, localDict, currentUserId) -> [RemoteTerritory] in
                guard let self = self else { return [] }
                guard let currentUserId = currentUserId, !currentUserId.isEmpty else {
                    print("[Territories] Ignoring remote updates until userId is available")
                    return []
                }
                let local = Array(localDict.values)
                let localById = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
                let localIds = Set(local.map { $0.id })

                // Identify territories that are now owned by someone else using timestamp/expiresAt for conflict resolution
                var lostIds = Set<String>()
                for territory in remote {
                    guard territory.userId != currentUserId, let territoryId = territory.id, let localCell = localById[territoryId] else { continue }

                    let remoteEnd = territory.activityEndAt
                    let localEnd = localCell.lastConqueredAt
                    let remoteUploaded = territory.uploadedAt?.dateValue() ?? territory.activityEndAt
                    let localUploaded = localCell.ownerUploadedAt ?? localCell.lastConqueredAt
                    let remoteIsNewer: Bool
                    if localCell.ownerUserId == currentUserId && territory.userId != currentUserId {
                        // El servidor dice que pertenece a otro usuario: confiar en servidor y soltarla
                        remoteIsNewer = true
                    } else if remoteEnd > localEnd {
                        remoteIsNewer = true
                    } else if remoteEnd == localEnd {
                        // Si empatan en hora de entreno, gana quien subió más tarde (o cualquiera si no hay uploadedAt)
                        remoteIsNewer = remoteUploaded >= localUploaded
                    } else {
                        remoteIsNewer = false
                    }
                    if remoteIsNewer {
                        lostIds.insert(territoryId)
                        print("[Territories] Marking cell as rival due to newer remote activity end time: \(territoryId)")
                    }
                }

                // Remove lost territories locally so they re-render as rivals
                if !lostIds.isEmpty {
                    DispatchQueue.main.async {
                        self.territoryStore.removeCells(withIds: lostIds)
                    }
                }

                let effectiveLocalIds = localIds.subtracting(lostIds)
                
                // 1. Identify my territories that are missing locally (Restore)
                let myMissingTerritories = remote.filter {
                    $0.userId == currentUserId && !effectiveLocalIds.contains($0.id ?? "")
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
                            lastConqueredAt: remoteT.activityEndAt,
                            expiresAt: remoteT.expiresAt,
                            ownerUserId: remoteT.userId,
                            ownerDisplayName: nil
                        )
                    }
                    // Async update to store - This will trigger the pipeline again, but localIds will be updated next time
                    DispatchQueue.main.async {
                        self.territoryStore.upsertCells(restoredCells)
                    }
                }
                
                // 2. Return only TRUE rivals
                let rivals = remote.filter {
                    $0.userId != currentUserId && !effectiveLocalIds.contains($0.id ?? "")
                }

                // Cap rivals to avoid flooding UI in dense maps
                if rivals.count > 500 {
                    print("[Territories] Capping rivals to 500 of \(rivals.count) fetched")
                }
                
                // Trigger icon fetch for rivals
                let uniqueUserIds = Set(rivals.compactMap { $0.userId })
                Task {
                    await self.fetchIcons(for: uniqueUserIds)
                }
                
                return Array(rivals.prefix(500))
            }
            .removeDuplicates() // Prevent UI updates if the list of rivals hasn't changed
            .receive(on: RunLoop.main) // Update UI on main
            .assign(to: &$otherTerritories)
            
        activityStore.$activities
            .map { activities in
                activities
            }
            .assign(to: &$activities)
        
        locationService.$routePoints
            .sink { [weak self] points in
                self?.calculateDistance(points: points)
            }
            .store(in: &cancellables)
    }
    
    private func cutoffDate(for config: GameConfig) -> Date {
        Calendar.current.date(byAdding: .day, value: -config.clampedLookbackDays, to: Date()) ?? Date()
    }
    
    func updateVisibleRegion(_ region: MKCoordinateRegion) {
        // Sync the view's region with the ViewModel
        // Wrap in async to avoid "Publishing changes from within view updates" warning
        DispatchQueue.main.async {
            // Guard against overwriting a programmatic move (like "Show on Map")
            guard !self.shouldRecenter else { return }
            self.region = region
        }
    }
    
    func centerOnUserLocation() {
        guard let location = locationService.currentLocation else { return }
        
        // Update region to center on user
        let newRegion = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01) // Zoom in a bit
        )
        
        self.region = newRegion
        self.shouldRecenter = true
    }
    
    func selectTerritoryByCellId(_ cellId: String) {
        // 1. Try local store first
        if let cell = territoryStore.conqueredCells[cellId] {
            let coord = CLLocationCoordinate2D(latitude: cell.centerLatitude, longitude: cell.centerLongitude)
            self.region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005))
            self.shouldRecenter = true
            selectTerritory(id: cellId, ownerName: cell.ownerDisplayName, ownerUserId: cell.ownerUserId)
            print("[Map] Navigating to local territory: \(cellId) at \(cell.centerLatitude), \(cell.centerLongitude)")
            return
        }
        
        // 2. Try remote territories (rivals/other)
        if let remote = otherTerritories.first(where: { $0.id == cellId }) {
            let coord = remote.centerCoordinate
            self.region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005))
            self.shouldRecenter = true
            selectTerritory(id: cellId, ownerName: nil, ownerUserId: remote.userId)
            print("[Map] Navigating to remote territory: \(cellId) at \(remote.centerLatitude), \(remote.centerLongitude)")
            return
        }
        
        // 3. Fallback: Parse from ID "x_y" if possible (for offline or emergency navigation)
        // ... handled if coordinate extraction logic existed
    }
    
    func selectTerritory(id: String?, ownerName: String?, ownerUserId: String?) {
        let currentUserId = AuthenticationService.shared.userId
        let finalOwnerId = ownerUserId ?? currentUserId
        let finalOwnerName: String? = {
            if let ownerName = ownerName { return ownerName }
            if let finalOwnerId, finalOwnerId == currentUserId {
                return AuthenticationService.shared.resolvedUserName()
            }
            return nil
        }()
        
        selectedTerritoryId = id
        selectedTerritoryOwner = finalOwnerName
        selectedTerritoryOwnerId = finalOwnerId
        selectedTerritoryOwnerAvatarData = finalOwnerId.flatMap { AvatarCacheManager.shared.data(for: $0) }
        selectedTerritoryOwnerIcon = finalOwnerId.flatMap { userIcons[$0] }
        
        if let currentUserId,
           finalOwnerId == currentUserId {
            selectedTerritoryOwnerXP = GamificationService.shared.currentXP
            selectedTerritoryOwnerTerritories = territoryStore.conqueredCells.count
        } else {
            selectedTerritoryOwnerXP = nil
            selectedTerritoryOwnerTerritories = nil
        }
        
        // Intentar cargar avatar si no está en caché
        if let finalOwnerId, selectedTerritoryOwnerAvatarData == nil {
            Task {
                await fetchOwnerAvatar(userId: finalOwnerId)
            }
        }
        
        // Completar datos del dueño si es un rival
        if let finalOwnerId, finalOwnerId != currentUserId {
            Task {
                await fetchOwnerProfile(userId: finalOwnerId)
            }
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
            guard let userId = AuthenticationService.shared.userId else {
                print("Stop activity -> aborted: no authenticated user")
                return
            }
            let userName = AuthenticationService.shared.userName
            
            // Create activity session
            let session = ActivitySession(
                startDate: start,
                endDate: end,
                activityType: type,
                distanceMeters: currentActivityDistance,
                durationSeconds: currentActivityDuration,
                route: locationService.routePoints
            )
            
            // IMPLEMENTATION: ADVENTURE STREAK GAME SYSTEM
            // Use GameEngine to process the complete activity through the game system
            do {
                try await GameEngine.shared.completeActivity(session, for: userId, userName: userName)
                print("✅ Activity processed successfully through GameEngine")
            } catch {
                print("❌ Error processing activity: \(error)")
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
    
    private func fetchOwnerAvatar(userId: String) async {
        if let cached = AvatarCacheManager.shared.data(for: userId) {
            // Ya está en caché, solo refrescar selección
            if selectedTerritoryOwnerId == userId {
                selectedTerritoryOwnerAvatarData = cached
            }
            return
        }
        
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.shared
            let doc = try await db.collection("users").document(userId).getDocument()
            if let urlString = doc.get("avatarURL") as? String,
               let url = URL(string: urlString) {
                let (data, _) = try await URLSession.shared.data(from: url)
                AvatarCacheManager.shared.save(data: data, for: userId)
                if selectedTerritoryOwnerId == userId {
                    selectedTerritoryOwnerAvatarData = data
                }
            }
        } catch {
            print("[Map] Error al obtener avatar de \(userId): \(error)")
        }
        #endif
    }
    
    private func fetchOwnerProfile(userId: String) async {
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.shared
            let doc = try await db.collection("users").document(userId).getDocument()
            let displayName = (doc.get("displayName") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let xpValue = doc.get("xp") as? Int
            let avatarURLString = doc.get("avatarURL") as? String
            var territoryCount: Int?
            
            // Obtener número de territorios del dueño
            do {
                // Agregado server-side si está disponible
                if #available(iOS 15.0, *) {
                    let countQuery = db.collection("remote_territories")
                        .whereField("userId", isEqualTo: userId)
                        .count
                    let snapshot = try await countQuery.getAggregation(source: .server)
                    territoryCount = Int(truncating: snapshot.count)
                } else {
                    // Fallback: fetch documents (menos eficiente, pero solo al seleccionar)
                    let snapshot = try await db.collection("remote_territories")
                        .whereField("userId", isEqualTo: userId)
                        .getDocuments()
                    territoryCount = snapshot.documents.count
                }
            } catch {
                print("[Map] Error obteniendo conteo de territorios para \(userId): \(error)")
            }
            
            if let urlString = avatarURLString,
               let url = URL(string: urlString),
               AvatarCacheManager.shared.data(for: userId) == nil {
                let (data, _) = try await URLSession.shared.data(from: url)
                AvatarCacheManager.shared.save(data: data, for: userId)
                if selectedTerritoryOwnerId == userId {
                    selectedTerritoryOwnerAvatarData = data
                }
            }
            
            if selectedTerritoryOwnerId == userId {
                if let name = displayName, !name.isEmpty {
                    selectedTerritoryOwner = name
                }
                if let xpValue {
                    selectedTerritoryOwnerXP = xpValue
                }
                if let territoryCount {
                    selectedTerritoryOwnerTerritories = territoryCount
                }
            }
        } catch {
            print("[Map] Error al obtener perfil remoto de \(userId): \(error)")
        }
        #endif
    }
    
    private func fetchIcons(for userIds: Set<String>) async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.shared
        var newIconsFound = false
        
        for userId in userIds {
            // Priority: Local State > Global Cache > Firestore
            if userIcons[userId] != nil { continue }
            
            if let cachedIcon = MapIconCacheManager.shared.getIcon(for: userId) {
                await MainActor.run {
                    self.userIcons[userId] = cachedIcon
                }
                newIconsFound = true
                continue
            }
            
            do {
                let doc = try await db.collection("users").document(userId).getDocument()
                if let icon = doc.get("mapIcon") as? String {
                    await MainActor.run {
                        self.userIcons[userId] = icon
                    }
                    MapIconCacheManager.shared.setIcon(icon, for: userId)
                    newIconsFound = true
                }
            } catch {
                print("[Map] Error fetching icon for \(userId): \(error)")
            }
        }
        
        // If we selected a territory whose owner's icon just arrived, update it
        if newIconsFound {
            await MainActor.run {
                self.iconVersion += 1
                if let selectedId = selectedTerritoryOwnerId {
                    self.selectedTerritoryOwnerIcon = self.userIcons[selectedId]
                }
            }
        }
        #endif
    }
}

import Foundation
import CoreLocation
import MapKit
// NEW: Added for multiplayer conquest feature
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

class TerritoryRepository: ObservableObject {
    // NEW: Singleton instance for shared access
    static let shared = TerritoryRepository()
    
    @Published var otherTerritories: [RemoteTerritory] = []
    @Published var proactiveTerritories: [RemoteTerritory] = [] // NEW: Dedicated pool for nearby treasures
    @Published var vengeanceTargets: [VengeanceTarget] = []
    @Published var vengeanceTerritoryDetails: [RemoteTerritory] = [] // NEW: Store details for off-screen targets
    @Published private(set) var hasInitialSnapshot: Bool = false
    
    private var db: Any? // Type-erased Firestore reference to avoid build errors if SDK missing
    private var listener: Any?
    private var vengeanceListener: Any?
    private var proactiveListener: Any? // Added for proactive fetch
    private var currentRegion: MKCoordinateRegion?
    private var lastObservedRegion: MKCoordinateRegion? // NEW: For movement debouncing
    private var isObserving = false
    
    // NEW: Geohash range listeners for better spatial queries
    private var geohashListeners: [String: Any] = [:] 
    
    // NEW: Thread-safe storage for territories by geohash to prevent race conditions
    private var territoriesByGeohash: [String: [RemoteTerritory]] = [:]
    private let storageQueue = DispatchQueue(label: "com.aerguevara.AdventureStreak.TerritoryStore", qos: .userInitiated)
    
    init() {
        #if canImport(FirebaseFirestore)
        db = Firestore.shared
        #endif
    }
    
    // NEW: Listen for territories (now routes)
    func observeTerritories() {
        // Fallback to a global observation if no region provided (not recommended for production)
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        guard !isObserving else { return }
        isObserving = true
        
        listener = setupRelativeListener(query: db.collection("remote_territories").limit(to: 1000), geohash: "global")
        #endif
    }
    
    private var observingVengeanceUserId: String?
    private var isSyncingUser = false
    
    // NEW: Observe vengeance targets for the current user
    func observeVengeanceTargets(userId: String) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore, !userId.isEmpty,
              let currentUser = Auth.auth().currentUser,
              currentUser.uid == userId else { return }
        
        // Prevent redundant listener setup
        if observingVengeanceUserId == userId {
            return
        }
        
        if let currentListener = vengeanceListener as? ListenerRegistration {
            currentListener.remove()
        }
        
        observingVengeanceUserId = userId
        print("[Territories] Observing vengeance targets for user \(userId)...")
        vengeanceListener = db.collection("users").document(userId).collection("vengeance_targets")
            .addSnapshotListener { [weak self] (snapshot, error) in
                guard let documents = snapshot?.documents else {
                    print("Error fetching vengeance targets: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                print("[Territories] Vengeance snapshot received with \(documents.count) documents.")
                
                var targets: [VengeanceTarget] = []
                for doc in documents {
                    do {
                        var target = try doc.data(as: VengeanceTarget.self)
                        target.id = doc.documentID
                        targets.append(target)
                    } catch {
                         print("❌ [TerritoryRepository] Error decoding VengeanceTarget \(doc.documentID): \(error)")
                    }
                }
                
                DispatchQueue.main.async {
                    self?.vengeanceTargets = targets
                    print("[Territories] Updated vengeance targets (\(targets.count) targets found)")
                    
                    // NEW: Fetch details for these targets so we have boundaries/expiry
                    Task { [weak self] in
                        let ids = targets.map { $0.cellId }
                        // Ensure we don't re-fetch if we already have them (optional optimization, but good practice)
                        // For now, just fetch fresh to be safe
                        if !ids.isEmpty {
                            let details = await self?.fetchTerritories(ids: ids) ?? []
                            await MainActor.run {
                                self?.vengeanceTerritoryDetails = details
                            }
                        } else {
                             await MainActor.run {
                                self?.vengeanceTerritoryDetails = []
                            }
                        }
                    }
                }
            }
        #endif
    }
    
    func observeTerritories(in region: MKCoordinateRegion) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore, Auth.auth().currentUser != nil else { return }
        
        // DEBOUNCING: Check if we've moved enough to justify a new query (20% threshold)
        if let last = lastObservedRegion {
            let latThreshold = last.span.latitudeDelta * 0.1
            let lonThreshold = last.span.longitudeDelta * 0.1
            
            let latDiff = abs(region.center.latitude - last.center.latitude)
            let lonDiff = abs(region.center.longitude - last.center.longitude)
            
            if latDiff < latThreshold && lonDiff < lonThreshold {
                // Not enough movement, skip query to save bandwidth
                return
            }
        }
        
        self.lastObservedRegion = region
        self.currentRegion = region
        
        // Determine required Geohash precision based on zoom level
        // Approx: span 0.2 deg (~22km) -> precision 5 (~4.9km x 4.9km)
        // Adjust threshold to use Precision 5 earlier for smoother panning
        let precision = region.span.latitudeDelta >= 0.04 ? 5 : 6
        let centerHash = Geohash.encode(latitude: region.center.latitude, longitude: region.center.longitude, precision: precision)
        let neighborHashes = Geohash.neighbours(for: centerHash)
        
        // Remove listeners for hashes no longer needed
        let currentHashes = Set(neighborHashes)
        for hash in geohashListeners.keys {
            if !currentHashes.contains(hash) {
                if let listener = geohashListeners[hash] as? ListenerRegistration {
                    listener.remove()
                }
                geohashListeners.removeValue(forKey: hash)
            }
        }
        
        // Create new listeners for revealed hashes
        for hash in neighborHashes {
            if geohashListeners[hash] == nil {
                let query = db.collection("remote_territories")
                    .whereField("geohash", isGreaterThanOrEqualTo: hash)
                    .whereField("geohash", isLessThanOrEqualTo: hash + "~")
                    .whereField("expiresAt", isGreaterThan: Date())
                    .limit(to: 1000) // Double limit for better coverage
                
                let listener = setupRelativeListener(query: query, geohash: hash)
                geohashListeners[hash] = listener
            }
        }
        
        isObserving = true
        #endif
    }
    
    func observeProactiveZone(around center: CLLocationCoordinate2D, radiusInMeters: Double = 10000) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore, Auth.auth().currentUser != nil else { return }
        
        // Use Geohash for proactive zone (radius 10km -> precision 5 is enough)
        let hash = Geohash.encode(latitude: center.latitude, longitude: center.longitude, precision: 5)
        _ = Geohash.neighbours(for: hash)
        
        print("[Territories] Setting up proactive Geohash observation zone around \(center.latitude), \(center.longitude)")
        
        // For proactive zone, we'll use a simpler approach of one listener per neighbor or a combined query if possible.
        // But Firestore 'in' query on geohash would require exact matches. 
        // We'll use multiple listeners for the ranges.
        
        // (Simplified for now: just clear and rebuild proactive pool)
        // In a real scenario, we might want to keep these listeners persistent too.
        
        // Remove existing proactive listeners if any (not shown in current struct but good practice)
        
        let query = db.collection("remote_territories")
            .whereField("geohash", isGreaterThanOrEqualTo: hash)
            .whereField("geohash", isLessThanOrEqualTo: hash + "~")
            .limit(to: 500)
            
        proactiveListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let documents = snapshot?.documents else {
                print("[Territories] Error proactive fetching: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                let territories = documents.compactMap { doc -> RemoteTerritory? in
                    var territory = try? doc.data(as: RemoteTerritory.self)
                    territory?.id = doc.documentID
                    return territory
                }
                
                DispatchQueue.main.async {
                    self?.proactiveTerritories = territories
                    self?.hasInitialSnapshot = true
                    // print("[Territories] Proactive pool updated: \(territories.count) targets found.")
                }
            }
        }
        #endif
    }
    
    private func setupRelativeListener(query: Query, geohash: String) -> ListenerRegistration? {
        #if canImport(FirebaseFirestore)
        return query.addSnapshotListener { [weak self] snapshot, error in
            guard let changes = snapshot?.documentChanges else {
                if let error = error {
                    print("Error fetching territories for \(geohash): \(error.localizedDescription)")
                }
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                guard let self = self else { return }
                
                self.storageQueue.async {
                    var currentBatch = self.territoriesByGeohash[geohash] ?? []
                    var hasChanges = false
                    
                    for change in changes {
                        let doc = change.document
                        switch change.type {
                        case .added, .modified:
                            if var territory = try? doc.data(as: RemoteTerritory.self) {
                                territory.id = doc.documentID
                                if let index = currentBatch.firstIndex(where: { $0.id == territory.id }) {
                                    currentBatch[index] = territory
                                } else {
                                    currentBatch.append(territory)
                                }
                                hasChanges = true
                            }
                        case .removed:
                            let id = doc.documentID
                            if let index = currentBatch.firstIndex(where: { $0.id == id }) {
                                currentBatch.remove(at: index)
                                hasChanges = true
                            }
                        }
                    }
                    
                    if hasChanges {
                        self.territoriesByGeohash[geohash] = currentBatch
                        
                        // Flatten and update public state
                        let allTerritories = self.territoriesByGeohash.values.flatMap { $0 }
                        // Unique by ID in case of geohash overlaps (though they shouldn't overlap in standard grid)
                        let uniqueTerritories = Array(Dictionary(grouping: allTerritories, by: { $0.id }).compactMap { $0.value.first })

                        DispatchQueue.main.async {
                            self.otherTerritories = uniqueTerritories
                            self.hasInitialSnapshot = true
                        }
                    }
                }
            }
        }
        #else
        return nil
        #endif
    }
    

    /// Espera a la primera sincronización remota (o timeout) para evitar cálculos con store vacío.
    func waitForInitialSync(timeout: TimeInterval = 3.0) async {
        if hasInitialSnapshot { return }
        let start = Date()
        while !hasInitialSnapshot && Date().timeIntervalSince(start) < timeout {
            try? await Task.sleep(nanoseconds: 200_000_000) // 200 ms
        }
    }
    
    // NEW: Stop proactive observation to save resources
    func stopProactiveObservation() {
        #if canImport(FirebaseFirestore)
        if let currentListener = proactiveListener as? ListenerRegistration {
            currentListener.remove()
        }
        proactiveListener = nil
        #endif
    }
    
    func stopObservation() {
        #if canImport(FirebaseFirestore)
        if let currentListener = listener as? ListenerRegistration {
            currentListener.remove()
        }
        listener = nil
        isObserving = false
        
        for (hash, listener) in geohashListeners {
            if let reg = listener as? ListenerRegistration {
                reg.remove()
            }
            // Clear data for this hash to avoid stale results
            storageQueue.async {
                self.territoriesByGeohash.removeValue(forKey: hash)
            }
        }
        geohashListeners.removeAll()
        #endif
    }
    
    // Fetch a set of territories by IDs (used for prefetch before calcular)
    func fetchTerritories(ids: [String]) async -> [RemoteTerritory] {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore, !ids.isEmpty else { return [] }
        var results: [RemoteTerritory] = []
        let chunkSize = 10 // Firestore "in" queries limited to 10
        let chunks = stride(from: 0, to: ids.count, by: chunkSize).map { Array(ids[$0..<min($0 + chunkSize, ids.count)]) }
        
        for chunk in chunks {
            do {
                let snapshot = try await db.collection("remote_territories")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                for doc in snapshot.documents {
                    do {
                        var territory = try doc.data(as: RemoteTerritory.self)
                        territory.id = doc.documentID
                        results.append(territory)
                    } catch {
                         print("❌ [TerritoryRepository] Error decoding territory \(doc.documentID): \(error)")
                    }
                }
            } catch {
                print("[Territories] fetchTerritories error: \(error)")
            }
        }
        return results
        #else
        return []
        #endif
    }
    
    // NEW: Fetch all territories conquered by a specific activity
    func fetchConqueredTerritories(forActivityId activityId: String) async -> [RemoteTerritory] {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore, !activityId.isEmpty else { return [] }
        do {
            let snapshot = try await db.collection("remote_territories")
                .whereField("activityId", isEqualTo: activityId)
                .getDocuments()
            
            return snapshot.documents.compactMap { doc -> RemoteTerritory? in
                var territory = try? doc.data(as: RemoteTerritory.self)
                territory?.id = doc.documentID
                return territory
            }
        } catch {
            print("❌ Error fetching activity territories: \(error)")
            return []
        }
        #else
        return []
        #endif
    }
    
    // NEW: Save conquered cells to Firestore
    func saveCells(_ cells: [TerritoryCell], userId: String, activityId: String? = nil) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        let batch = db.batch()
        
        for cell in cells {
            let ref = db.collection("remote_territories").document(cell.id)
            
            let remoteTerritory = RemoteTerritory(
                id: cell.id,
                userId: userId,
                centerLatitude: cell.centerLatitude,
                centerLongitude: cell.centerLongitude,
                boundary: cell.boundary,
                expiresAt: cell.expiresAt,
                activityEndAt: cell.lastConqueredAt,
                activityId: cell.activityId ?? activityId,
                isHotSpot: cell.isHotSpot ?? false,
                locationLabel: cell.locationLabel,
                firstConqueredAt: cell.firstConqueredAt,
                defenseCount: cell.defenseCount
            )
            
            do {
                try batch.setData(from: remoteTerritory, forDocument: ref)
            } catch {
                print("Error encoding cell \(cell.id): \(error)")
            }
        }
        
        batch.commit { error in
            if let error = error {
                print("Error saving cells batch: \(error)")
            } else {
                print("Successfully saved \(cells.count) cells")
            }
        }
        #endif
    }
    
    // NEW: Remove a territory (if expired or lost)
    func removeTerritory(_ id: String) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        db.collection("remote_territories").document(id).delete()
        #endif
    }
    
    // NEW: Sync user's territories from Firestore to local store
    func syncUserTerritories(userId: String, store: TerritoryStore) async {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore, !isSyncingUser else { return }
        isSyncingUser = true
        
        defer { isSyncingUser = false }
        
        print("[Territories] Syncing territories for user \(userId)...")
        do {
            let snapshot = try await db.collection("remote_territories")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            let territories = snapshot.documents.compactMap { doc -> TerritoryCell? in
                guard let remote = try? doc.data(as: RemoteTerritory.self) else { return nil }
                // Convert RemoteTerritory to TerritoryCell
                return TerritoryCell(
                    id: doc.documentID,
                    centerLatitude: remote.centerLatitude,
                    centerLongitude: remote.centerLongitude,
                    boundary: remote.boundary,
                    lastConqueredAt: remote.activityEndAt,
                    expiresAt: remote.expiresAt,
                    ownerUserId: remote.userId,
                    ownerDisplayName: nil, // Will be filled locally if needed
                    ownerUploadedAt: remote.uploadedAt?.dateValue(),
                    activityId: remote.activityId,
                    firstConqueredAt: remote.firstConqueredAt,
                    defenseCount: remote.defenseCount,
                    isHotSpot: remote.isHotSpot,
                    locationLabel: remote.locationLabel
                )
            }
            
        if !territories.isEmpty || snapshot.isEmpty {
                // DEBUG: Log what we found
                print("[Territories] Fetched \(territories.count) valid territories for user \(userId) from \(snapshot.documents.count) docs.")
                if territories.count < snapshot.documents.count {
                    print("[Territories] WARNING: Decoded fewer territories than fetched. \(snapshot.documents.count - territories.count) failed decoding.")
                }
                
                await MainActor.run {
                    store.reconcileUserTerritories(userId: userId, remoteCells: territories)
                }
                print("[Territories] Reconciled \(territories.count) territories from Firestore for user \(userId).")
            }
        } catch {
            print("[Territories] Error syncing user territories: \(error)")
        }
        #endif
    }
}


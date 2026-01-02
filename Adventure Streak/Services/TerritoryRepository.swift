import Foundation
import CoreLocation
import MapKit
// NEW: Added for multiplayer conquest feature
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

class TerritoryRepository: ObservableObject {
    // NEW: Singleton instance for shared access
    static let shared = TerritoryRepository()
    
    @Published var otherTerritories: [RemoteTerritory] = []
    @Published var vengeanceTargets: [VengeanceTarget] = []
    @Published var vengeanceTerritoryDetails: [RemoteTerritory] = [] // NEW: Store details for off-screen targets
    @Published private(set) var hasInitialSnapshot: Bool = false
    
    private var db: Any? // Type-erased Firestore reference to avoid build errors if SDK missing
    private var listener: Any?
    private var vengeanceListener: Any?
    private var currentRegion: MKCoordinateRegion?
    private var isObserving = false
    
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
        
        setupListener(query: db.collection("remote_territories").limit(to: 1000))
        #endif
    }
    
    // NEW: Observe vengeance targets for the current user
    func observeVengeanceTargets(userId: String) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore, !userId.isEmpty else { return }
        
        #if canImport(FirebaseFirestore)
        if let currentListener = vengeanceListener as? ListenerRegistration {
            currentListener.remove()
        }
        #endif
        
        print("[Territories] Observing vengeance targets for user \(userId)...")
        vengeanceListener = db.collection("users").document(userId).collection("vengeance_targets")
            .addSnapshotListener { [weak self] (snapshot, error) in
                guard let documents = snapshot?.documents else {
                    print("Error fetching vengeance targets: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let targets = documents.compactMap { doc -> VengeanceTarget? in
                    var target = try? doc.data(as: VengeanceTarget.self)
                    target?.id = doc.documentID
                    return target
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
    
    // NEW: Listen for territories within a specific region
    func observeTerritories(in region: MKCoordinateRegion) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        // Calculate bounds with a bit of buffer (20%)
        let latDelta = region.span.latitudeDelta * 1.2
        let lonDelta = region.span.longitudeDelta * 1.2
        
        let minLat = region.center.latitude - latDelta / 2
        let maxLat = region.center.latitude + latDelta / 2
        let minLon = region.center.longitude - lonDelta / 2
        let maxLon = region.center.longitude + lonDelta / 2
        
        // Store current region for in-memory filtering of longitude if needed
        self.currentRegion = region
        
        // Cancel existing listener
        #if canImport(FirebaseFirestore)
        if let currentListener = listener as? ListenerRegistration {
            currentListener.remove()
        }
        #endif
        
        // Firestore can only do range filters on one field easily. 
        // We'll filter by Latitude on server and Longitude in memory.
        let query = db.collection("remote_territories")
            .whereField("centerLatitude", isGreaterThanOrEqualTo: minLat)
            .whereField("centerLatitude", isLessThanOrEqualTo: maxLat)
            .limit(to: 1000)
            
        isObserving = true
        setupListener(query: query, minLon: minLon, maxLon: maxLon)
        #endif
    }
    
    private func setupListener(query: Query, minLon: Double? = nil, maxLon: Double? = nil) {
        #if canImport(FirebaseFirestore)
        listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let documents = snapshot?.documents else {
                print("Error fetching territories: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // Perform heavy decoding on background thread to avoid freezing UI
            DispatchQueue.global(qos: .userInitiated).async {
                let territories = documents.compactMap { doc -> RemoteTerritory? in
                    var territory = try? doc.data(as: RemoteTerritory.self)
                    territory?.id = doc.documentID // Force assignment of ID
                    
                    // In-memory longitude filtering
                    if let minLon = minLon, let maxLon = maxLon, let t = territory {
                        if t.centerLongitude < minLon || t.centerLongitude > maxLon {
                            return nil
                        }
                    }
                    
                    return territory
                }
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self?.otherTerritories = territories
                    self?.hasInitialSnapshot = true
                }
            }
        }
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
                isHotSpot: cell.isHotSpot ?? false
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
        guard let db = db as? Firestore else { return }
        
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
                    isHotSpot: remote.isHotSpot
                )
            }
            
            if !territories.isEmpty || snapshot.isEmpty {
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

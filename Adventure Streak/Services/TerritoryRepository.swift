import Foundation
import CoreLocation
// NEW: Added for multiplayer conquest feature
// Ensure you add the Firebase SDK to your project via SPM: https://github.com/firebase/firebase-ios-sdk
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

class TerritoryRepository: ObservableObject {
    // NEW: Singleton instance for shared access
    static let shared = TerritoryRepository()
    
    @Published var otherTerritories: [RemoteTerritory] = []
    @Published private(set) var hasInitialSnapshot: Bool = false
    
    private var db: Any? // Type-erased Firestore reference to avoid build errors if SDK missing
    private var listener: Any?
    private var isObserving = false
    
    init() {
        #if canImport(FirebaseFirestore)
        db = Firestore.firestore()
        #endif
    }
    
    // NEW: Listen for territories (now routes)
    func observeTerritories() {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        guard !isObserving else { return }
        isObserving = true
        
        // Listen to "remote_territories" collection
        listener = db.collection("remote_territories")
            .limit(to: 1000) // Increased limit to prevent missing territories
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching territories: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // Perform heavy decoding on background thread to avoid freezing UI
                DispatchQueue.global(qos: .userInitiated).async {
                    let territories = documents.compactMap { doc -> RemoteTerritory? in
                        var territory = try? doc.data(as: RemoteTerritory.self)
                        territory?.id = doc.documentID // Force assignment of ID
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
                    var territory = try? doc.data(as: RemoteTerritory.self)
                    territory?.id = doc.documentID
                    if let territory { results.append(territory) }
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
                activityId: cell.activityId ?? activityId
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
                    activityId: remote.activityId
                )
            }
            
            if !territories.isEmpty {
                await MainActor.run {
                    store.upsertCells(territories)
                }
                print("[Territories] Pulled \(territories.count) territories from Firestore.")
            }
        } catch {
            print("[Territories] Error syncing user territories: \(error)")
        }
        #endif
    }
}

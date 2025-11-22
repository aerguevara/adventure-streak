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
    
    private var db: Any? // Type-erased Firestore reference to avoid build errors if SDK missing
    private var listener: Any?
    
    init() {
        #if canImport(FirebaseFirestore)
        db = Firestore.firestore()
        #endif
    }
    
    // NEW: Listen for territories (now routes)
    func observeTerritories() {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        // Listen to "remote_territories" collection
        listener = db.collection("remote_territories")
            .limit(to: 1000) // Increased limit to prevent missing territories
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching territories: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.otherTerritories = documents.compactMap { doc -> RemoteTerritory? in
                    var territory = try? doc.data(as: RemoteTerritory.self)
                    territory?.id = doc.documentID // Force assignment of ID
                    return territory
                }
            }
        #endif
    }
    
    // NEW: Save conquered cells to Firestore
    func saveCells(_ cells: [TerritoryCell], userId: String) {
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
                timestamp: cell.lastConqueredAt
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
}

import Foundation

@MainActor
class TerritoryStore: ObservableObject {
    static let shared = TerritoryStore()

    private let store = JSONStore<TerritoryCell>(filename: "territories.json")
    private let persistenceQueue = DispatchQueue(label: "TerritoryStore.persist.queue")
    private var cleanupTimer: Timer?
    @Published var conqueredCells: [String: TerritoryCell] = [:]
    
    private init() {
        // Load asynchronously to prevent blocking the main thread (UI)
        DispatchQueue.global(qos: .userInitiated).async {
            // Create local instance to avoid accessing MainActor 'self.store'
            let localStore = JSONStore<TerritoryCell>(filename: "territories.json")
            let cells = localStore.load()
            
            // Process and update on Main Actor
            DispatchQueue.main.async {
                // Convert list to dictionary for faster access
                self.conqueredCells = Dictionary(uniqueKeysWithValues: cells.map { ($0.id, $0) })
                // NO Local Cleanup: Trust Server Sync
            }
        }
    }
    
    func upsertCells(_ cells: [TerritoryCell]) {
        for cell in cells {
            conqueredCells[cell.id] = cell
        }
        persist()
    }
    
    func clear() {
        guard !conqueredCells.isEmpty else { return }
        conqueredCells = [:]
        persist()
    }

    func removeCells(withIds ids: Set<String>) {
        let originalCount = conqueredCells.count
        ids.forEach { conqueredCells.removeValue(forKey: $0) }

        if conqueredCells.count != originalCount {
            persist()
        }
    }
    
    /// Reconciles local cache with a list of territories known by the server for a specific user.
    /// This ensures that territories stolen or lost on the server are removed from the local store.
    func reconcileUserTerritories(userId: String, remoteCells: [TerritoryCell]) {
        // 1. Keep cells that don't belong to this user (if any, though usually this store is user-specific)
        var updatedCells = conqueredCells.filter { $0.value.ownerUserId != userId }
        
        // 2. Add/Update cells from the server
        for cell in remoteCells {
            updatedCells[cell.id] = cell
        }
        
        // 3. Update the published dictionary and persist
        conqueredCells = updatedCells
        persist()
        
        print("[TerritoryStore] Reconciled: \(remoteCells.count) server cells, total in store: \(conqueredCells.count)")
    }
    
    func fetchAllCells() -> [TerritoryCell] {
        return Array(conqueredCells.values)
    }

    private func persist() {
        let cellsToSave = Array(conqueredCells.values)

        // Perform heavy JSON encoding and file writing in a serial background queue
        persistenceQueue.async {
            do {
                // Create a new local instance to avoid capturing MainActor-isolated 'self.store'
                let localStore = JSONStore<TerritoryCell>(filename: "territories.json")
                try localStore.save(cellsToSave)
            } catch {
                print("Failed to save territories: \(error)")
            }
        }
    }
}

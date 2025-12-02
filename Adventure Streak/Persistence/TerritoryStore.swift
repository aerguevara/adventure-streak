import Foundation

@MainActor
class TerritoryStore: ObservableObject {
    static let shared = TerritoryStore()
    
    private let store = JSONStore<TerritoryCell>(filename: "territories.json")
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
                self.removeExpiredCells(now: Date())
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
    
    func fetchAllCells() -> [TerritoryCell] {
        return Array(conqueredCells.values)
    }
    
    func removeExpiredCells(now: Date) {
        let originalCount = conqueredCells.count
        conqueredCells = conqueredCells.filter { $0.value.expiresAt > now }
        
        if conqueredCells.count != originalCount {
            persist()
        }
    }
    
    private func persist() {
        let cellsToSave = Array(conqueredCells.values)
        
        // Perform heavy JSON encoding and file writing in background
        Task.detached(priority: .background) {
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

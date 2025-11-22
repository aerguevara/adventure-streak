import Foundation

class TerritoryStore: ObservableObject {
    private let store = JSONStore<TerritoryCell>(filename: "territories.json")
    @Published var conqueredCells: [String: TerritoryCell] = [:]
    
    init() {
        let cells = store.load()
        // Convert list to dictionary for faster access
        self.conqueredCells = Dictionary(uniqueKeysWithValues: cells.map { ($0.id, $0) })
        removeExpiredCells(now: Date())
    }
    
    func upsertCells(_ cells: [TerritoryCell]) {
        for cell in cells {
            conqueredCells[cell.id] = cell
        }
        persist()
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
        do {
            try store.save(Array(conqueredCells.values))
        } catch {
            print("Failed to save territories: \(error)")
        }
    }
}

import Foundation

final class PendingRouteStore: ObservableObject, @unchecked Sendable {
    static let shared = PendingRouteStore()
    
    private let store = JSONStore<PendingRouteImport>(filename: "pending_routes.json")
    @Published private(set) var pending: [PendingRouteImport] = []
    private let queue = DispatchQueue(label: "com.adventurestreak.pendingroutestore")
    
    private init() {
        pending = store.load()
        print("🗄️ PendingRouteStore loaded \(pending.count) pending routes")
    }
    
    func upsert(_ item: PendingRouteImport) {
        queue.sync {
            if let index = pending.firstIndex(where: { $0.id == item.id }) {
                pending[index] = item
            } else {
                pending.append(item)
            }
            persistLocked()
        }
    }
    
    func remove(workoutId: UUID) {
        queue.sync {
            pending.removeAll { $0.id == workoutId }
            persistLocked()
        }
    }
    
    func find(workoutId: UUID) -> PendingRouteImport? {
        queue.sync {
            pending.first { $0.id == workoutId }
        }
    }
    
    private func persistLocked() {
        do {
            try store.save(pending)
        } catch {
            print("Failed to save pending routes: \(error)")
        }
    }
}

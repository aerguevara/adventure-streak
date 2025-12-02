import Foundation
// NEW: Added for multiplayer conquest feature
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif
#else
// Fallback if SDK is missing so it compiles
@propertyWrapper
struct DocumentID<T: Codable>: Codable {
    var wrappedValue: T
    init(wrappedValue: T) { self.wrappedValue = wrappedValue }
}
#endif
// Ensure Models are available (implicitly in same module)

@MainActor
protocol FeedRepositoryProtocol {
    func observeFeed()
    func postEvent(_ event: FeedEvent)
    func clear()
    func fetchLatest() async
    var events: [FeedEvent] { get }
}

@MainActor
class FeedRepository: ObservableObject, FeedRepositoryProtocol {
    static let shared = FeedRepository()
    
    @Published var events: [FeedEvent] = []
    
    private var db: Any?
    
    private var listenerRegistration: ListenerRegistration?
    
    init() {
        #if canImport(FirebaseFirestore)
        db = Firestore.firestore()
        #endif
    }
    
    // NEW: Stream recent feed events
    func observeFeed() {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        // Remove existing listener if any
        listenerRegistration?.remove()
        DispatchQueue.main.async { [weak self] in
            self?.events = []
        }
        
        listenerRegistration = db.collection("feed")
            .order(by: "date", descending: true)
            .limit(to: 20)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                let decoded = documents.compactMap { doc -> FeedEvent? in
                    do {
                        var event = try doc.data(as: FeedEvent.self)
                        // Manually assign the document ID since we aren't using @DocumentID in the model
                        event.id = doc.documentID
                        return event
                    } catch {
                        print("DEBUG: Error decoding FeedEvent \(doc.documentID): \(error)")
                        return nil
                    }
                }
                
                // Deduplicate: prefer events con activityId; descartar legacy duplicados sin activityId si hay uno cercano en tiempo del mismo usuario
                let withActivityId = decoded.filter { $0.activityId != nil }
                
                var unique: [String: FeedEvent] = [:]
                for event in decoded {
                    // Skip legacy doc if there's a version with activityId for same user in ~5 min window
                    if event.activityId == nil,
                       let userId = event.userId {
                        let hasModern = withActivityId.contains {
                            guard $0.userId == userId else { return false }
                            return abs($0.date.timeIntervalSince(event.date)) <= 300 // 5 min
                        }
                        if hasModern { continue }
                    }
                    
                    let roundedDate = floor(event.date.timeIntervalSince1970 / 60) // minute bucket
                    let fallbackKey = "\(event.userId ?? "unknown")|\(event.type.rawValue)|\(event.title)|\(roundedDate)"
                    let key = event.activityId.map { "act-\($0.uuidString)-\(event.type.rawValue)" } ?? fallbackKey
                    
                    guard let existing = unique[key] else {
                        unique[key] = event
                        continue
                    }
                    
                    let existingHasName = !(existing.relatedUserName ?? "").isEmpty
                    let currentHasName = !(event.relatedUserName ?? "").isEmpty
                    let existingHasActivity = existing.activityId != nil
                    let currentHasActivity = event.activityId != nil
                    
                    // Prefer events con activityId; luego con nombre; si no, mantener primero
                    if !existingHasActivity && currentHasActivity {
                        unique[key] = event
                    } else if existingHasActivity == currentHasActivity {
                        if !existingHasName && currentHasName {
                            unique[key] = event
                        }
                    }
                }
                
                let sorted = unique.values.sorted { $0.date > $1.date }
                DispatchQueue.main.async {
                    self?.events = sorted
                }
            }
        #endif
    }
    
    /// One-shot fetch to force a fresh read from Firestore (pull-to-refresh)
    func fetchLatest() async {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        do {
            let snapshot = try await db.collection("feed")
                .order(by: "date", descending: true)
                .limit(to: 20)
                .getDocuments()
            
            let decoded: [FeedEvent] = snapshot.documents.compactMap { doc in
                do {
                    var event = try doc.data(as: FeedEvent.self)
                    event.id = doc.documentID
                    return event
                } catch {
                    print("DEBUG: Error decoding FeedEvent \(doc.documentID): \(error)")
                    return nil
                }
            }
            
            let withActivityId = decoded.filter { $0.activityId != nil }
            
            var unique: [String: FeedEvent] = [:]
            for event in decoded {
                if event.activityId == nil,
                   let userId = event.userId {
                    let hasModern = withActivityId.contains {
                        guard $0.userId == userId else { return false }
                        return abs($0.date.timeIntervalSince(event.date)) <= 300 // 5 min
                    }
                    if hasModern { continue }
                }
                
                let roundedDate = floor(event.date.timeIntervalSince1970 / 60) // minute bucket
                let fallbackKey = "\(event.userId ?? "unknown")|\(event.type.rawValue)|\(event.title)|\(roundedDate)"
                let key = event.activityId.map { "act-\($0.uuidString)-\(event.type.rawValue)" } ?? fallbackKey
                
                guard let existing = unique[key] else {
                    unique[key] = event
                    continue
                }
                
                let existingHasName = !(existing.relatedUserName ?? "").isEmpty
                let currentHasName = !(event.relatedUserName ?? "").isEmpty
                let existingHasActivity = existing.activityId != nil
                let currentHasActivity = event.activityId != nil
                
                if !existingHasActivity && currentHasActivity {
                    unique[key] = event
                } else if existingHasActivity == currentHasActivity {
                    if !existingHasName && currentHasName {
                        unique[key] = event
                    }
                }
            }
            
            let sorted = unique.values.sorted { $0.date > $1.date }
            DispatchQueue.main.async { [weak self] in
                self?.events = sorted
            }
        } catch {
            print("Error fetching latest feed: \(error)")
        }
        #endif
    }
    
    // NEW: Post a new event
    func postEvent(_ event: FeedEvent) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        do {
            if let id = event.id, !id.isEmpty {
                try db.collection("feed").document(id).setData(from: event)
            } else {
                try db.collection("feed").addDocument(from: event)
            }
        } catch {
            print("Error posting feed event: \(error)")
        }
        #endif
    }
    
    func clear() {
        listenerRegistration?.remove()
        listenerRegistration = nil
        events = []
    }
}

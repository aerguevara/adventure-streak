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

struct FeedEvent: Identifiable, Codable {
    // NEW: Model for feed events
    @DocumentID var id: String?
    let type: String // "conquest", "streak", "badge"
    let message: String
    let userId: String
    let timestamp: Date
}

class FeedRepository: ObservableObject {
    static let shared = FeedRepository()
    
    @Published var events: [FeedEvent] = []
    
    private var db: Any?
    
    init() {
        #if canImport(FirebaseFirestore)
        db = Firestore.firestore()
        #endif
    }
    
    // NEW: Stream recent feed events
    func observeFeed() {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        db.collection("feed")
            .order(by: "timestamp", descending: true)
            .limit(to: 20)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                self?.events = documents.compactMap { doc -> FeedEvent? in
                    try? doc.data(as: FeedEvent.self)
                }
            }
        #endif
    }
    
    // NEW: Post a new event
    func postEvent(_ event: FeedEvent) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        do {
            try db.collection("feed").addDocument(from: event)
        } catch {
            print("Error posting feed event: \(error)")
        }
        #endif
    }
}

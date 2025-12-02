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

// Protocol definition
protocol FeedRepositoryProtocol {
    func observeFeed()
    func postEvent(_ event: FeedEvent)
    func clear()
    var events: [FeedEvent] { get }
}

// Old FeedEvent struct removed (now in Models/FeedModels.swift)

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
        
        listenerRegistration = db.collection("feed")
            .order(by: "date", descending: true)
            .limit(to: 20)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                self?.events = documents.compactMap { doc -> FeedEvent? in
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
    
    func clear() {
        listenerRegistration?.remove()
        listenerRegistration = nil
        events = []
    }
}

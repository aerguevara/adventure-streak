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
    nonisolated static let shared = FeedRepository()
    
    @Published var events: [FeedEvent] = []
    
    private let store = JSONStore<FeedEvent>(filename: "feed_cache.json")
    
    private var db: Any? = {
        #if canImport(FirebaseFirestore)
        return Firestore.shared
        #else
        return nil
        #endif
    }()
    
    #if canImport(FirebaseFirestore)
    private var listenerRegistration: ListenerRegistration?
    #else
    private var listenerRegistration: Any?
    #endif
    private var lastDocument: QueryDocumentSnapshot? // NEW: For pagination
    private var isFetchingNextPage = false
    
    nonisolated init() {
        // Load cached events on main actor during startup
        Task { @MainActor in
            self.events = self.store.load()
            print("📦 [FeedRepository] Loaded \(self.events.count) cached events")
        }
    }
    
    // NEW: Stream recent feed events
    func observeFeed() {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        // Remove existing listener if any
        listenerRegistration?.remove()
        
        listenerRegistration = db.collection("feed")
            .order(by: "date", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ [FeedRepository] Firestore Listener Error: \(error.localizedDescription)")
                    print("❌ [FeedRepository] Error details: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents, let self = self else { 
                    print("⚠️ [FeedRepository] Received empty snapshot or self is nil")
                    return 
                }
                
                print("📝 [FeedRepository] Received \(documents.count) documents from Firestore")
                
                // Store last document for pagination
                self.lastDocument = documents.last
                
                // OPTIMIZATION: Process heavy decoding and deduplication on background thread.
                DispatchQueue.global(qos: .userInitiated).async {
                    let sorted = self.processFeedDocuments(documents)
                    
                    DispatchQueue.main.async {
                        self.events = sorted
                        print("✅ [FeedRepository] Updated events list (total: \(sorted.count))")
                        
                        // Save to cache
                        do {
                            try self.store.save(sorted)
                            print("💾 [FeedRepository] Persisted \(sorted.count) events to disk")
                        } catch {
                            print("❌ [FeedRepository] Cache Save Error: \(error.localizedDescription)")
                        }
                    }
                }
            }
        #endif
    }
    
    /// NEW: Fetch the next page of feed events
    func fetchNextPage() async {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore, let last = lastDocument, !isFetchingNextPage else { return }
        isFetchingNextPage = true
        defer { isFetchingNextPage = false }
        
        print("📥 [FeedRepository] Fetching next page...")
        do {
            let snapshot = try await db.collection("feed")
                .order(by: "date", descending: true)
                .start(afterDocument: last)
                .limit(to: 30)
                .getDocuments()
            
            let newDocs = snapshot.documents
            guard !newDocs.isEmpty else { return }
            
            self.lastDocument = newDocs.last
            
            let newEvents = await Task.detached(priority: .userInitiated) {
                return self.processFeedDocuments(newDocs)
            }.value
            
            await MainActor.run {
                // Combine and deduplicate
                let combined = self.events + newEvents
                // Reuse processFeedDocuments logic (simplified by just unique IDs)
                var unique: [String: FeedEvent] = [:]
                for event in combined {
                    unique[event.id] = event
                }
                self.events = unique.values.sorted { $0.date > $1.date }
            }
        } catch {
            print("❌ [FeedRepository] Pagination Error: \(error)")
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
                .limit(to: 50)
                .getDocuments()
            
            let sorted = processFeedDocuments(snapshot.documents)
            self.events = sorted
            
            // Save to cache
            try? self.store.save(sorted)
        } catch {
            print("Error fetching latest feed: \(error)")
        }
        #endif
    }

    nonisolated private func processFeedDocuments(_ documents: [QueryDocumentSnapshot]) -> [FeedEvent] {
        let decoded = documents.compactMap { doc -> FeedEvent? in
            do {
                var event = try doc.data(as: FeedEvent.self)
                event.id = doc.documentID
                return event
            } catch {
                print("DEBUG: Error decoding FeedEvent \(doc.documentID): \(error)")
                return nil
            }
        }
        
        // Step 1: Group by Document ID (Firestore stability)
        var byDocId: [String: FeedEvent] = [:]
        for event in decoded {
            let id = event.id
            // If we have duplicates of the SAME document ID (rare in a single snapshot),
            // we'd probably want the most complete version, but here we just take the first.
            if byDocId[id] == nil { byDocId[id] = event }
        }
        
        // Step 2: Cross-document deduplication (identifying same activity across different docs)
        // e.g. a client post vs. a server-modified update
        let allEvents = Array(byDocId.values)
        let withActivityId = allEvents.filter { $0.activityId != nil }
        
        var unique: [String: FeedEvent] = [:]
        
        for event in allEvents {
            // Deduplicate legacy vs modern (5 min window for same user)
            if event.activityId == nil, let userId = event.userId {
                let hasModern = withActivityId.contains {
                    guard $0.userId == userId else { return false }
                    return abs($0.date.timeIntervalSince(event.date)) <= 300 
                }
                if hasModern { continue }
            }
            
            // Stable key for activities
            let roundedDate = floor(event.date.timeIntervalSince1970 / 60)
            let fallbackKey = "\(event.userId ?? "unknown")|\(event.type.rawValue)|\(event.title)|\(roundedDate)"
            let key = event.activityId.map { "act-\($0)-\(event.type.rawValue)" } ?? fallbackKey
            
            guard let existing = unique[key] else {
                var firstEvent = event
                firstEvent.id = key
                unique[key] = firstEvent
                continue
            }
            
            // Priority/Richness Logic:
            // 1. Has activityId
            // 2. Has Mission Info or "Misión" in title
            // 3. Has XP info
            // 4. Has relatedUserName
            
            let existingHasMission = (existing.rarity != nil) || existing.title.contains("Misión")
            let currentHasMission = (event.rarity != nil) || event.title.contains("Misión")
            
            let existingHasXP = (existing.xpEarned ?? 0) > 0
            let currentHasXP = (event.xpEarned ?? 0) > 0
            
            let existingHasActivity = existing.activityId != nil
            let currentHasActivity = event.activityId != nil
            
            let existingHasName = !(existing.relatedUserName ?? "").isEmpty
            let currentHasName = !(event.relatedUserName ?? "").isEmpty
            
            var shouldReplace = false
            
            if !existingHasActivity && currentHasActivity {
                shouldReplace = true
            } else if existingHasActivity == currentHasActivity {
                if !existingHasMission && currentHasMission {
                    shouldReplace = true
                } else if existingHasMission == currentHasMission {
                    if !existingHasXP && currentHasXP {
                        shouldReplace = true
                    } else if existingHasXP == currentHasXP {
                        if !existingHasName && currentHasName {
                            shouldReplace = true
                        }
                    }
                }
            }
            
            if shouldReplace {
                var updatedEvent = event
                updatedEvent.id = key
                unique[key] = updatedEvent
            }
        }
        
        return unique.values.sorted { $0.date > $1.date }
    }
    
    // NEW: Post a new event
    func postEvent(_ event: FeedEvent) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        do {
            if !event.id.isEmpty {
                try db.collection("feed").document(event.id).setData(from: event)
            } else {
                try db.collection("feed").addDocument(from: event)
            }
        } catch {
            print("Error posting feed event: \(error)")
        }
        #endif
    }
    
    // NEW: Update location label for existing feed events (Backfill support)
    func updateLocationLabel(activityId: String, label: String) async {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        do {
            // Find feed events linked to this activity
            let snapshot = try await db.collection("feed")
                .whereField("activityId", isEqualTo: activityId)
                .getDocuments()
            
            for doc in snapshot.documents {
                // Update the deep nested field 'activityData.locationLabel'
                // Note: Firestore supports dot notation for nested fields
                let data: [String: Any] = ["activityData.locationLabel": label]
                try await doc.reference.updateData(data)
                print("✅ [Feed] Updated locationLabel for event \(doc.documentID)")
            }
        } catch {
            print("Error updating feed location label: \(error)")
        }
        #endif
    }
    
    func clear() {
        #if canImport(FirebaseFirestore)
        listenerRegistration?.remove()
        #endif
        listenerRegistration = nil
        events = []
    }
}

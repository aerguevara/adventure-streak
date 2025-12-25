import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif
#endif

@MainActor
final class ReactionRepository: ObservableObject {
    nonisolated static let shared = ReactionRepository()

    @Published private(set) var reactionStates: [String: ActivityReactionState] = [:]

    #if canImport(FirebaseFirestore)
    nonisolated private let db = Firestore.firestore()
    private var statListeners: [String: ListenerRegistration] = [:]
    private var userListeners: [String: ListenerRegistration] = [:]
    #endif

    nonisolated private let localStore = JSONStore<ActivityReactionRecord>(filename: "activity_reactions.json")
    private var localRecords: [ActivityReactionRecord] = []

    nonisolated init() {
        Task {
            await self.loadInitialData()
        }
    }
    
    private func loadInitialData() {
        self.localRecords = localStore.load()
        self.rebuildStatesFromLocal()
    }

    func observeActivities(_ activityIds: [String]) {
        let set = Set(activityIds)
        self.reactionStates = self.reactionStates.filter { set.contains($0.key) }
        #if canImport(FirebaseFirestore)
        cleanObsoleteListeners(keeping: set)
        for id in set {
            if statListeners[id] == nil {
                let statsRef = db.collection("activity_reaction_stats").document(id)
                statListeners[id] = statsRef.addSnapshotListener { [weak self] snapshot, _ in
                    guard let self else { return }
                    let stats = snapshot.flatMap { try? $0.data(as: ReactionStats.self) }
                    var state = self.reactionStates[id] ?? .empty
                    state.fireCount = stats?.fireCount ?? 0
                    state.swordCount = stats?.swordCount ?? 0
                    state.shieldCount = stats?.shieldCount ?? 0
                    self.reactionStates[id] = state
                }
            }

            if let userId = AuthenticationService.shared.userId, userListeners[id] == nil {
                let userDoc = db.collection("activity_reactions").document("\(id)_\(userId)")
                userListeners[id] = userDoc.addSnapshotListener { [weak self] snapshot, _ in
                    guard let self else { return }
                    var state = self.reactionStates[id] ?? .empty
                    if let reaction = snapshot?.get("reactionType") as? String, let type = ReactionType(rawValue: reaction) {
                        state.currentUserReaction = type
                    }
                    self.reactionStates[id] = state
                }
            }
        }
        #else
        rebuildStatesFromLocal(only: set)
        #endif
    }

    func sendReaction(for activityId: String, authorId: String, type: ReactionType) async {
        guard let currentUserId = AuthenticationService.shared.userId else { return }

        #if canImport(FirebaseFirestore)
        let statsRef = db.collection("activity_reaction_stats").document(activityId)
        let userRef = db.collection("activity_reactions").document("\(activityId)_\(currentUserId)")

        do {
            _ = try await db.runTransaction { transaction, _ in
                // 1. Check Previous Reaction
                var oldType: ReactionType? = nil
                if let existingSnap = try? transaction.getDocument(userRef), 
                   existingSnap.exists,
                   let data = existingSnap.data(),
                   let oldRaw = data["reactionType"] as? String {
                    oldType = ReactionType(rawValue: oldRaw)
                }

                // 2. If same reaction, do nothing
                if let old = oldType, old == type {
                    return nil as Any?
                }

                // 3. Update User Reaction Record
                var reactionData: [String: Any] = [
                    "activityId": activityId,
                    "reactedUserId": currentUserId,
                    "reactionType": type.rawValue,
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                if oldType == nil {
                    reactionData["createdAt"] = FieldValue.serverTimestamp()
                }
                transaction.setData(reactionData, forDocument: userRef, merge: true)

                // 4. Update Activity Stats
                var statsFields: [String: Any] = [:]
                // Increment New
                statsFields["\(type.rawValue)Count"] = FieldValue.increment(Int64(1))
                // Decrement Old
                if let old = oldType {
                    statsFields["\(old.rawValue)Count"] = FieldValue.increment(Int64(-1))
                }
                
                // Update timestamps for specific types
                if type == .sword { statsFields["competitiveTaggedAt"] = FieldValue.serverTimestamp() }
                if type == .shield { statsFields["rivalryTaggedAt"] = FieldValue.serverTimestamp() }

                transaction.setData(statsFields, forDocument: statsRef, merge: true)

                // 5. Update Author Prestige (Fire = Prestige)
                // Logic: Only change if Fire status changes
                var prestigeChange: Int64 = 0
                if type == .fire && oldType != .fire {
                    prestigeChange = 1
                } else if type != .fire && oldType == .fire {
                    prestigeChange = -1
                }

                if prestigeChange != 0 {
                    let authorRef = self.db.collection("users").document(authorId)
                    transaction.setData(["prestige": FieldValue.increment(prestigeChange)], forDocument: authorRef, merge: true)
                }
                
                // Notification handled by Cloud Function (onReactionCreated)
                
                return nil as Any?
            }
        }
 catch {
            print("[Reactions] Failed to persist reaction: \(error)")
        }
        #else
        let record = ActivityReactionRecord(activityId: activityId, reactedUserId: currentUserId, reactionType: type)
        if let existingIndex = localRecords.firstIndex(where: { $0.id == record.id }) {
            // Replace previous reaction locally so UI counts stay consistent offline
            localRecords.remove(at: existingIndex)
        }
        localRecords.append(record)
        persistLocal()
        rebuildStatesFromLocal()
        #endif
    }

    func removeReaction(for activityId: String, authorId: String) async {
        guard let currentUserId = AuthenticationService.shared.userId else { return }

        #if canImport(FirebaseFirestore)
        let statsRef = db.collection("activity_reaction_stats").document(activityId)
        let userRef = db.collection("activity_reactions").document("\(activityId)_\(currentUserId)")

        do {
            _ = try await db.runTransaction { transaction, _ in
                guard let existing = try? transaction.getDocument(userRef),
                      existing.exists,
                      let reactionString = existing.get("reactionType") as? String,
                      let reaction = ReactionType(rawValue: reactionString) else {
                    return nil as Any?
                }

                var fields: [String: Any] = [:]
                switch reaction {
                case .fire:
                    fields["fireCount"] = FieldValue.increment(Int64(-1))
                case .sword:
                    fields["swordCount"] = FieldValue.increment(Int64(-1))
                case .shield:
                    fields["shieldCount"] = FieldValue.increment(Int64(-1))
                }

                transaction.updateData(fields, forDocument: statsRef)
                transaction.deleteDocument(userRef)
                return nil as Any?
            }
        }
 catch {
            print("[Reactions] Failed to remove reaction: \(error)")
        }
        #else
        if let index = localRecords.firstIndex(where: { $0.activityId == activityId && $0.reactedUserId == currentUserId }) {
            localRecords.remove(at: index)
            persistLocal()
            rebuildStatesFromLocal()
        }
        #endif
    }

    func updateLocalState(for activityId: String, state: ActivityReactionState) {
        DispatchQueue.main.async {
            self.reactionStates[activityId] = state
        }
    }

    private func cleanObsoleteListeners(keeping ids: Set<String>) {
        #if canImport(FirebaseFirestore)
        for (key, listener) in statListeners where !ids.contains(key) {
            listener.remove()
            statListeners.removeValue(forKey: key)
        }
        for (key, listener) in userListeners where !ids.contains(key) {
            listener.remove()
            userListeners.removeValue(forKey: key)
        }
        #endif
    }

    private func rebuildStatesFromLocal(only ids: Set<String>? = nil) {
        let filtered = localRecords.filter { ids?.contains($0.activityId) ?? true }
        var states: [String: ActivityReactionState] = [:]
        for record in filtered {
            var state = states[record.activityId] ?? .empty
            switch record.reactionType {
            case .fire: state.fireCount += 1
            case .sword: state.swordCount += 1
            case .shield: state.shieldCount += 1
            }
            if record.reactedUserId == AuthenticationService.shared.userId {
                state.currentUserReaction = record.reactionType
            }
            states[record.activityId] = state
        }
        self.reactionStates.merge(states) { _, new in new }
    }

    private func persistLocal() {
        do {
            try localStore.save(localRecords)
        } catch {
            print("[Reactions] Failed to persist locally: \(error)")
        }
    }
}

#if canImport(FirebaseFirestore)
private struct ReactionStats: Codable {
    let fireCount: Int
    let swordCount: Int
    let shieldCount: Int
}
#endif

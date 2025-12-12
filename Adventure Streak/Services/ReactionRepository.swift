import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif
#endif

final class ReactionRepository: ObservableObject {
    static let shared = ReactionRepository()

    @Published private(set) var reactionStates: [UUID: ActivityReactionState] = [:]

    #if canImport(FirebaseFirestore)
    private var db: Firestore?
    private var statListeners: [UUID: ListenerRegistration] = [:]
    private var userListeners: [UUID: ListenerRegistration] = [:]
    #endif

    private let localStore = JSONStore<ActivityReactionRecord>(filename: "activity_reactions.json")
    private var localRecords: [ActivityReactionRecord] = []

    private init() {
        #if canImport(FirebaseFirestore)
        db = Firestore.firestore()
        #endif
        localRecords = localStore.load()
        rebuildStatesFromLocal()
    }

    func observeActivities(_ activityIds: [UUID]) {
        let set = Set(activityIds)
        DispatchQueue.main.async {
            self.reactionStates = self.reactionStates.filter { set.contains($0.key) }
        }
        #if canImport(FirebaseFirestore)
        cleanObsoleteListeners(keeping: set)
        guard let db else { return }
        for id in set {
            if statListeners[id] == nil {
                let statsRef = db.collection("activity_reaction_stats").document(id.uuidString)
                statListeners[id] = statsRef.addSnapshotListener { [weak self] snapshot, _ in
                    guard let self else { return }
                    let stats = snapshot.flatMap { try? $0.data(as: ReactionStats.self) }
                    var state = self.reactionStates[id] ?? .empty
                    state.fireCount = stats?.fireCount ?? 0
                    state.trophyCount = stats?.trophyCount ?? 0
                    state.devilCount = stats?.devilCount ?? 0
                    DispatchQueue.main.async {
                        self.reactionStates[id] = state
                    }
                }
            }

            if let userId = AuthenticationService.shared.userId, userListeners[id] == nil {
                let userDoc = db.collection("activity_reactions").document("\(id.uuidString)_\(userId)")
                userListeners[id] = userDoc.addSnapshotListener { [weak self] snapshot, _ in
                    guard let self else { return }
                    var state = self.reactionStates[id] ?? .empty
                    if let reaction = snapshot?.get("reactionType") as? String, let type = ReactionType(rawValue: reaction) {
                        state.currentUserReaction = type
                    }
                    DispatchQueue.main.async {
                        self.reactionStates[id] = state
                    }
                }
            }
        }
        #else
        rebuildStatesFromLocal(only: set)
        #endif
    }

    func sendReaction(for activityId: UUID, authorId: String, type: ReactionType) async {
        guard let currentUserId = AuthenticationService.shared.userId else { return }

        #if canImport(FirebaseFirestore)
        guard let db else { return }
        let statsRef = db.collection("activity_reaction_stats").document(activityId.uuidString)
        let userRef = db.collection("activity_reactions").document("\(activityId.uuidString)_\(currentUserId)")

        do {
            try await db.runTransaction { transaction, _ in
                if let existing = try? transaction.getDocument(userRef), existing.exists {
                    return nil
                }

                transaction.setData([
                    "activityId": activityId.uuidString,
                    "reactedUserId": currentUserId,
                    "reactionType": type.rawValue,
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: userRef, merge: true)

                var fields: [String: Any] = [
                    "fireCount": FieldValue.increment(Int64(type == .fire ? 1 : 0)),
                    "trophyCount": FieldValue.increment(Int64(type == .trophy ? 1 : 0)),
                    "devilCount": FieldValue.increment(Int64(type == .devil ? 1 : 0))
                ]
                if type == .trophy { fields["competitiveTaggedAt"] = FieldValue.serverTimestamp() }
                if type == .devil { fields["rivalryTaggedAt"] = FieldValue.serverTimestamp() }

                transaction.setData(fields, forDocument: statsRef, merge: true)

                if type == .fire {
                    let userRef = db.collection("users").document(authorId)
                    transaction.updateData(["prestige": FieldValue.increment(Int64(1))], forDocument: userRef)
                }
                return nil
            }
        } catch {
            print("[Reactions] Failed to persist reaction: \(error)")
        }
        #else
        let record = ActivityReactionRecord(activityId: activityId, reactedUserId: currentUserId, reactionType: type)
        guard !localRecords.contains(record) else { return }
        localRecords.append(record)
        persistLocal()
        rebuildStatesFromLocal()
        #endif
    }

    private func cleanObsoleteListeners(keeping ids: Set<UUID>) {
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

    private func rebuildStatesFromLocal(only ids: Set<UUID>? = nil) {
        let filtered = localRecords.filter { ids?.contains($0.activityId) ?? true }
        var states: [UUID: ActivityReactionState] = [:]
        for record in filtered {
            var state = states[record.activityId] ?? .empty
            switch record.reactionType {
            case .fire: state.fireCount += 1
            case .trophy: state.trophyCount += 1
            case .devil: state.devilCount += 1
            }
            if record.reactedUserId == AuthenticationService.shared.userId {
                state.currentUserReaction = record.reactionType
            }
            states[record.activityId] = state
        }
        DispatchQueue.main.async {
            self.reactionStates.merge(states) { _, new in new }
        }
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
    let trophyCount: Int
    let devilCount: Int
}
#endif

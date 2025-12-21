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

    @Published private(set) var reactionStates: [UUID: ActivityReactionState] = [:]

    #if canImport(FirebaseFirestore)
    nonisolated private let db = Firestore.firestore()
    private var statListeners: [UUID: ListenerRegistration] = [:]
    private var userListeners: [UUID: ListenerRegistration] = [:]
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

    func observeActivities(_ activityIds: [UUID]) {
        let set = Set(activityIds)
        self.reactionStates = self.reactionStates.filter { set.contains($0.key) }
        #if canImport(FirebaseFirestore)
        cleanObsoleteListeners(keeping: set)
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
                    self.reactionStates[id] = state
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
                    self.reactionStates[id] = state
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
        let statsRef = db.collection("activity_reaction_stats").document(activityId.uuidString)
        let userRef = db.collection("activity_reactions").document("\(activityId.uuidString)_\(currentUserId)")

        do {
            _ = try await db.runTransaction { transaction, _ in
                if let existing = try? transaction.getDocument(userRef), existing.exists {
                    return nil as Any?
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
                    let userRef = self.db.collection("users").document(authorId)
                    transaction.updateData(["prestige": FieldValue.increment(Int64(1))], forDocument: userRef)
                }
                
                // Create Notification
                let notificationRef = self.db.collection("notifications").document()
                let senderName = AuthenticationService.shared.userName ?? "Adventurer"
                let senderAvatarURL = AuthenticationService.shared.userAvatarURL
                
                var notificationData: [String: Any] = [
                    "recipientId": authorId,
                    "senderId": currentUserId,
                    "senderName": senderName,
                    "type": "reaction",
                    "reactionType": type.rawValue,
                    "activityId": activityId.uuidString,
                    "timestamp": FieldValue.serverTimestamp(),
                    "isRead": false
                ]
                
                if let senderAvatarURL = senderAvatarURL {
                    notificationData["senderAvatarURL"] = senderAvatarURL
                }
                
                transaction.setData(notificationData, forDocument: notificationRef)
                
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

    func removeReaction(for activityId: UUID, authorId: String) async {
        guard let currentUserId = AuthenticationService.shared.userId else { return }

        #if canImport(FirebaseFirestore)
        let statsRef = db.collection("activity_reaction_stats").document(activityId.uuidString)
        let userRef = db.collection("activity_reactions").document("\(activityId.uuidString)_\(currentUserId)")

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
                case .trophy:
                    fields["trophyCount"] = FieldValue.increment(Int64(-1))
                case .devil:
                    fields["devilCount"] = FieldValue.increment(Int64(-1))
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

    func updateLocalState(for activityId: UUID, state: ActivityReactionState) {
        DispatchQueue.main.async {
            self.reactionStates[activityId] = state
        }
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
    let trophyCount: Int
    let devilCount: Int
}
#endif

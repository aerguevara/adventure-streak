import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif
#endif

/// Firestore representation for activity sessions, including user ownership.
private struct FirestoreActivity: Codable {
    #if canImport(FirebaseFirestoreSwift)
    @DocumentID var id: String?
    #else
    var id: String?
    #endif
    let userId: String
    let startDate: Date
    let endDate: Date
    let activityType: ActivityType
    let distanceMeters: Double
    let durationSeconds: Double
    let route: [RoutePoint]
    let xpBreakdown: XPBreakdown?
    let territoryStats: TerritoryStats?
    let missions: [Mission]?
    let lastUpdatedAt: Date
    
    init(activity: ActivitySession, userId: String) {
        self.id = activity.id.uuidString
        self.userId = userId
        self.startDate = activity.startDate
        self.endDate = activity.endDate
        self.activityType = activity.activityType
        self.distanceMeters = activity.distanceMeters
        self.durationSeconds = activity.durationSeconds
        self.route = activity.route
        self.xpBreakdown = activity.xpBreakdown
        self.territoryStats = activity.territoryStats
        self.missions = activity.missions
        self.lastUpdatedAt = Date()
    }
}

final class ActivityRepository {
    static let shared = ActivityRepository()
    
    #if canImport(FirebaseFirestore)
    private let db: Firestore
    #endif
    
    private init() {
        #if canImport(FirebaseFirestore)
        self.db = Firestore.firestore()
        #endif
    }
    
    /// Saves or updates an activity in the top-level `activities` collection keyed by user.
    func saveActivity(_ activity: ActivitySession, userId: String) async {
        #if canImport(FirebaseFirestore)
        let docId = activity.id.uuidString
        let maxBytes = 950_000 // safety margin under 1MB Firestore limit
        
        // Build candidate variants from most to least detailed
        var candidates: [(ActivitySession, String)] = []
        candidates.append((activity, "full"))
        
        // Downsample progressively
        let thresholds = [500, 200, 50]
        for maxPoints in thresholds {
            if activity.route.count > maxPoints {
                let trimmed = downsampleRoute(activity.route, maxPoints: maxPoints)
                let trimmedActivity = ActivitySession(
                    id: activity.id,
                    startDate: activity.startDate,
                    endDate: activity.endDate,
                    activityType: activity.activityType,
                    distanceMeters: activity.distanceMeters,
                    durationSeconds: activity.durationSeconds,
                    route: trimmed,
                    xpBreakdown: activity.xpBreakdown,
                    territoryStats: activity.territoryStats,
                    missions: activity.missions
                )
                candidates.append((trimmedActivity, "trimmed-\(maxPoints)"))
            }
        }
        
        // Last resort: metadata only (no route)
        let metaOnlyActivity = ActivitySession(
            id: activity.id,
            startDate: activity.startDate,
            endDate: activity.endDate,
            activityType: activity.activityType,
            distanceMeters: activity.distanceMeters,
            durationSeconds: activity.durationSeconds,
            route: [],
            xpBreakdown: activity.xpBreakdown,
            territoryStats: activity.territoryStats,
            missions: activity.missions
        )
        candidates.append((metaOnlyActivity, "metadata-only"))
        
        for (candidate, label) in candidates {
            let size = estimatedPayloadSize(activity: candidate, userId: userId)
            if size > maxBytes {
                print("[Activities] Skipping variant \(label) for \(docId) — estimated \(size) bytes (> \(maxBytes))")
                continue
            }
            if await attemptSave(activity: candidate, userId: userId, docId: docId, label: label) {
                return
            }
        }
        
        print("[Activities] Failed to save activity \(docId) after all variants")
        #else
        print("[Activities] Firestore SDK not available; skipping remote save.")
        #endif
    }
    
    /// Internal helper to attempt a save with logging; returns true on success.
    private func attemptSave(activity: ActivitySession, userId: String, docId: String, label: String = "full") async -> Bool {
        #if canImport(FirebaseFirestore)
        let payload = FirestoreActivity(activity: activity, userId: userId)
        do {
            try db.collection("activities")
                .document(docId)
                .setData(from: payload, merge: true)
            print("[Activities] Saved activity \(docId) for user \(userId) (\(label)) with \(activity.route.count) points")
            return true
        } catch {
            print("[Activities] Failed to save activity \(docId) (\(label)): \(error.localizedDescription)")
            return false
        }
        #else
        return false
        #endif
    }
    
    private func estimatedPayloadSize(activity: ActivitySession, userId: String) -> Int {
        let payload = FirestoreActivity(activity: activity, userId: userId)
        do {
            let data = try JSONEncoder().encode(payload)
            return data.count
        } catch {
            print("[Activities] Failed to estimate payload size: \(error)")
            return Int.max
        }
    }
    
    private func downsampleRoute(_ route: [RoutePoint], maxPoints: Int) -> [RoutePoint] {
        guard route.count > maxPoints, maxPoints > 0 else { return route }
        let step = max(1, route.count / maxPoints)
        var sampled: [RoutePoint] = []
        sampled.reserveCapacity(maxPoints)
        for (index, point) in route.enumerated() where index % step == 0 {
            sampled.append(point)
            if sampled.count >= maxPoints { break }
        }
        // Ensure last point is included
        if let last = route.last, sampled.last?.id != last.id {
            sampled.append(last)
        }
        return sampled
    }
    
    /// Batch-save convenience; iterates sequentially to avoid Firestore rate limits on small batches.
    func saveActivities(_ activities: [ActivitySession], userId: String) async {
        for activity in activities {
            await saveActivity(activity, userId: userId)
        }
    }
    
    /// Backfill: push all locally stored activities to Firestore (idempotent via stable UUIDs).
    func syncLocalActivities(activityStore: ActivityStore = .shared, userId: String) async {
        let local = activityStore.fetchAllActivities()
        print("[Activities] Backfilling \(local.count) local activities for user \(userId)")
        await saveActivities(local, userId: userId)
    }
    
    /// Fetch remote activity IDs for the given user (best-effort).
    func fetchRemoteActivityIds(userId: String) async -> Set<String> {
        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await db.collection("activities")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            let ids = snapshot.documents.compactMap { $0.documentID }
            return Set(ids)
        } catch {
            print("[Activities] Failed to fetch remote ids: \(error.localizedDescription)")
            return []
        }
        #else
        return []
        #endif
    }
    
    /// Ensure remote collection contains all local activities; uploads any missing and logs differences.
    func ensureRemoteParity(userId: String, activityStore: ActivityStore = .shared) async {
        let localActivities = activityStore.fetchAllActivities()
        let localIds = Set(localActivities.map { $0.id.uuidString })
        let remoteIds = await fetchRemoteActivityIds(userId: userId)
        
        let missingRemote = localActivities.filter { !remoteIds.contains($0.id.uuidString) }
        let extraRemoteIds = remoteIds.subtracting(localIds)
        
        print("[Activities] Parity check — local: \(localIds.count), remote: \(remoteIds.count), missingRemote: \(missingRemote.count), extraRemote: \(extraRemoteIds.count)")
        
        if !missingRemote.isEmpty {
            print("[Activities] Uploading \(missingRemote.count) missing activities to remote")
            await saveActivities(missingRemote, userId: userId)
        }
        
        if !extraRemoteIds.isEmpty {
            print("[Activities] Remote has \(extraRemoteIds.count) activities not present locally (ids: \(Array(extraRemoteIds.prefix(5)))) — pulling to local")
            let pulled = await fetchRemoteActivities(userId: userId, ids: extraRemoteIds)
            if !pulled.isEmpty {
                DispatchQueue.main.async {
                    activityStore.saveActivities(pulled)
                }
                print("[Activities] Pulled \(pulled.count) remote activities into local store")
            }
        }
    }
    
    /// Fetch remote activities (optionally filtered by ids).
    func fetchRemoteActivities(userId: String, ids: Set<String>? = nil) async -> [ActivitySession] {
        #if canImport(FirebaseFirestore)
        do {
            var query: Query = db.collection("activities").whereField("userId", isEqualTo: userId)
            if let ids = ids, !ids.isEmpty {
                let list = Array(ids.prefix(10)) // Firestore in query limitation; fetch individually if more
                query = query.whereField(FieldPath.documentID(), in: list)
            }
            
            let snapshot = try await query.getDocuments()
            
            let activities: [ActivitySession] = snapshot.documents.compactMap { doc in
                do {
                    let remote = try doc.data(as: FirestoreActivity.self)
                    return ActivitySession(
                        id: UUID(uuidString: remote.id ?? doc.documentID) ?? UUID(),
                        startDate: remote.startDate,
                        endDate: remote.endDate,
                        activityType: remote.activityType,
                        distanceMeters: remote.distanceMeters,
                        durationSeconds: remote.durationSeconds,
                        route: remote.route,
                        xpBreakdown: remote.xpBreakdown,
                        territoryStats: remote.territoryStats,
                        missions: remote.missions
                    )
                } catch {
                    print("[Activities] Failed to decode activity \(doc.documentID): \(error)")
                    return nil
                }
            }
            
            // If there were more than 10 ids, fetch the rest individually
            if let ids = ids, ids.count > 10 {
                let remaining = ids.subtracting(Set(snapshot.documents.map { $0.documentID }))
                if !remaining.isEmpty {
                    let extra = try await fetchActivitiesIndividually(ids: remaining)
                    return activities + extra
                }
            }
            
            return activities
        } catch {
            print("[Activities] Failed to fetch remote activities: \(error.localizedDescription)")
            return []
        }
        #else
        return []
        #endif
    }
    
    #if canImport(FirebaseFirestore)
    private func fetchActivitiesIndividually(ids: Set<String>) async throws -> [ActivitySession] {
        var results: [ActivitySession] = []
        for id in ids {
            let doc = try await db.collection("activities").document(id).getDocument()
            if let data = doc.data() {
                do {
                    let remote = try doc.data(as: FirestoreActivity.self)
                    let session = ActivitySession(
                        id: UUID(uuidString: remote.id ?? doc.documentID) ?? UUID(),
                        startDate: remote.startDate,
                        endDate: remote.endDate,
                        activityType: remote.activityType,
                        distanceMeters: remote.distanceMeters,
                        durationSeconds: remote.durationSeconds,
                        route: remote.route,
                        xpBreakdown: remote.xpBreakdown,
                        territoryStats: remote.territoryStats,
                        missions: remote.missions
                    )
                    results.append(session)
                } catch {
                    print("[Activities] Failed to decode activity \(doc.documentID): \(error)")
                }
            }
        }
        return results
    }
    #endif
}

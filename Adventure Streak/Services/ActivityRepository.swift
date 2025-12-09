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
    let workoutName: String?
    // Route is now stored in subcollection "routes" to avoid 1MB limit.
    // Keep optional for backward compatibility if older docs had the full route.
    let route: [RoutePoint]?
    let xpBreakdown: XPBreakdown?
    let territoryStats: TerritoryStats?
    let missions: [Mission]?
    let routePointsCount: Int?
    let routeChunkCount: Int?
    let territoryPointsCount: Int?
    let territoryChunkCount: Int?
    let lastUpdatedAt: Date
    
    init(activity: ActivitySession, userId: String, routeChunkCount: Int, territoryChunkCount: Int) {
        self.id = activity.id.uuidString
        self.userId = userId
        self.startDate = activity.startDate
        self.endDate = activity.endDate
        self.activityType = activity.activityType
        self.distanceMeters = activity.distanceMeters
        self.durationSeconds = activity.durationSeconds
        self.workoutName = activity.workoutName
        self.route = nil // store route in subcollection
        self.xpBreakdown = activity.xpBreakdown
        self.territoryStats = activity.territoryStats
        self.missions = activity.missions
        self.routePointsCount = activity.route.count
        self.routeChunkCount = routeChunkCount
        self.territoryPointsCount = nil
        self.territoryChunkCount = territoryChunkCount
        self.lastUpdatedAt = Date()
    }
}

private struct FirestoreRouteChunk: Codable {
    let order: Int
    let points: [RoutePoint]
    let pointCount: Int
    
    init(order: Int, points: [RoutePoint]) {
        self.order = order
        self.points = points
        self.pointCount = points.count
    }
}

private struct FirestoreTerritoryChunk: Codable {
    let order: Int
    let cells: [TerritoryCell]
    let cellCount: Int
    
    init(order: Int, cells: [TerritoryCell]) {
        self.order = order
        self.cells = cells
        self.cellCount = cells.count
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
    func saveActivity(_ activity: ActivitySession, territories: [TerritoryCell]? = nil, userId: String) async {
        #if canImport(FirebaseFirestore)
        let docId = activity.id.uuidString
        
        let chunkSize = 500
        let chunks = chunkRoute(activity.route, size: chunkSize)
        let territoryChunks = chunkTerritories(territories ?? [], size: 200)
        
        // 1) Save metadata doc (without route)
        let meta = FirestoreActivity(activity: activity, userId: userId, routeChunkCount: chunks.count, territoryChunkCount: territoryChunks.count)
        do {
            try db.collection("activities")
                .document(docId)
                .setData(from: meta, merge: true)
            print("[Activities] Saved metadata for \(docId) with \(chunks.count) route chunks (\(activity.route.count) pts) and \(territoryChunks.count) territory chunks")
        } catch {
            print("[Activities] Failed to save metadata for \(docId): \(error.localizedDescription)")
            return
        }
        
        // 2) Save route chunks in subcollection
        for (index, points) in chunks.enumerated() {
            let chunkPayload = FirestoreRouteChunk(order: index, points: points)
            do {
                try db.collection("activities")
                    .document(docId)
                    .collection("routes")
                    .document("chunk_\(index)")
                    .setData(from: chunkPayload, merge: true)
                print("[Activities] Saved route chunk \(index + 1)/\(chunks.count) for \(docId) with \(points.count) pts")
            } catch {
                print("[Activities] Failed to save route chunk \(index) for \(docId): \(error.localizedDescription)")
            }
        }
        
        // 3) Save territory chunks in subcollection
        for (index, cells) in territoryChunks.enumerated() {
            let chunkPayload = FirestoreTerritoryChunk(order: index, cells: cells)
            do {
                try db.collection("activities")
                    .document(docId)
                    .collection("territories")
                    .document("chunk_\(index)")
                    .setData(from: chunkPayload, merge: true)
            } catch {
                print("[Activities] Failed to save territory chunk \(index) for \(docId): \(error.localizedDescription)")
            }
        }
        #else
        print("[Activities] Firestore SDK not available; skipping remote save.")
        #endif
    }
    
    private func chunkRoute(_ route: [RoutePoint], size: Int) -> [[RoutePoint]] {
        guard size > 0, !route.isEmpty else { return [] }
        var chunks: [[RoutePoint]] = []
        var index = 0
        while index < route.count {
            let end = min(index + size, route.count)
            let slice = Array(route[index..<end])
            chunks.append(slice)
            index = end
        }
        return chunks
    }
    
    private func chunkTerritories(_ cells: [TerritoryCell], size: Int) -> [[TerritoryCell]] {
        guard size > 0, !cells.isEmpty else { return [] }
        var chunks: [[TerritoryCell]] = []
        var index = 0
        while index < cells.count {
            let end = min(index + size, cells.count)
            let slice = Array(cells[index..<end])
            chunks.append(slice)
            index = end
        }
        return chunks
    }
    private func fetchRouteChunks(activityId: String, expectedCount: Int, fallbackRoute: [RoutePoint]?) async -> [RoutePoint] {
        #if canImport(FirebaseFirestore)
        if expectedCount == 0, let fallbackRoute = fallbackRoute {
            return fallbackRoute
        }
        
        let routesRef = db.collection("activities").document(activityId).collection("routes")
        var points: [RoutePoint] = []
        
        if expectedCount > 0 {
            for order in 0..<expectedCount {
                do {
                    let doc = try await routesRef.document("chunk_\(order)").getDocument()
                    if doc.exists {
                        let chunk = try doc.data(as: FirestoreRouteChunk.self)
                        points.append(contentsOf: chunk.points)
                    }
                } catch {
                    print("[Activities] Failed to fetch chunk \(order) for \(activityId): \(error)")
                }
            }
        } else {
            do {
                let snapshot = try await routesRef.getDocuments()
                let sorted = snapshot.documents.sorted { $0.documentID < $1.documentID }
                for doc in sorted {
                    do {
                        let chunk = try doc.data(as: FirestoreRouteChunk.self)
                        points.append(contentsOf: chunk.points)
                    } catch {
                        print("[Activities] Failed to decode chunk \(doc.documentID) for \(activityId): \(error)")
                    }
                }
            } catch {
                print("[Activities] Failed to fetch chunks for \(activityId): \(error)")
            }
        }
        
        return points
        #else
        return fallbackRoute ?? []
        #endif
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
    
    func activityExists(activityId: UUID, userId: String) async -> Bool {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("activities").document(activityId.uuidString).getDocument()
            if let data = doc.data(),
               let storedUser = data["userId"] as? String,
               storedUser == userId {
                return true
            }
        } catch {
            print("[Activities] Failed to check existence for \(activityId): \(error.localizedDescription)")
        }
        return false
        #else
        return false
        #endif
    }
    
    private func fetchTerritoryChunks(activityId: String, expectedCount: Int?) async -> [TerritoryCell] {
        #if canImport(FirebaseFirestore)
        let territoriesRef = db.collection("activities").document(activityId).collection("territories")
        var cells: [TerritoryCell] = []
        
        if let expected = expectedCount, expected > 0 {
            for order in 0..<expected {
                do {
                    let doc = try await territoriesRef.document("chunk_\(order)").getDocument()
                    if doc.exists {
                        let chunk = try doc.data(as: FirestoreTerritoryChunk.self)
                        cells.append(contentsOf: chunk.cells)
                    }
                } catch {
                    print("[Activities] Failed to fetch territory chunk \(order) for \(activityId): \(error)")
                }
            }
        } else {
            do {
                let snapshot = try await territoriesRef.getDocuments()
                let sorted = snapshot.documents.sorted { $0.documentID < $1.documentID }
                for doc in sorted {
                    do {
                        let chunk = try doc.data(as: FirestoreTerritoryChunk.self)
                        cells.append(contentsOf: chunk.cells)
                    } catch {
                        print("[Activities] Failed to decode territory chunk \(doc.documentID) for \(activityId): \(error)")
                    }
                }
            } catch {
                print("[Activities] Failed to fetch territory chunks for \(activityId): \(error)")
            }
        }
        
        return cells
        #else
        return []
        #endif
    }
    
    /// Ensure remote collection contains all local activities; uploads any missing and logs differences.
    func ensureRemoteParity(userId: String, activityStore: ActivityStore = .shared, territoryStore: TerritoryStore? = nil) async {
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
                await MainActor.run {
                    activityStore.saveActivities(pulled)
                }
                print("[Activities] Pulled \(pulled.count) remote activities into local store")
                
                if let territoryStore = territoryStore {
                    for activity in pulled {
                        let cells = await fetchTerritoryChunks(activityId: activity.id.uuidString, expectedCount: nil)
                        if !cells.isEmpty {
                            await MainActor.run {
                                territoryStore.upsertCells(cells)
                            }
                        }
                    }
                }
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
            
            var activities: [ActivitySession] = []
            for doc in snapshot.documents {
                do {
                    let remote = try doc.data(as: FirestoreActivity.self)
                    let route = await fetchRouteChunks(activityId: doc.documentID, expectedCount: remote.routeChunkCount ?? 0, fallbackRoute: remote.route)
                    
                    let session = ActivitySession(
                        id: UUID(uuidString: remote.id ?? doc.documentID) ?? UUID(),
                        startDate: remote.startDate,
                        endDate: remote.endDate,
                        activityType: remote.activityType,
                        distanceMeters: remote.distanceMeters,
                        durationSeconds: remote.durationSeconds,
                        workoutName: remote.workoutName,
                        route: route,
                        xpBreakdown: remote.xpBreakdown,
                        territoryStats: remote.territoryStats,
                        missions: remote.missions
                    )
                    activities.append(session)
                } catch {
                    print("[Activities] Failed to decode activity \(doc.documentID): \(error)")
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

    func fetchActivity(activityId: UUID, userId: String) async -> ActivitySession? {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("activities").document(activityId.uuidString).getDocument()
            guard doc.exists else { return nil }
            let remote = try doc.data(as: FirestoreActivity.self)
            guard remote.userId == userId else { return nil }
            let route = await fetchRouteChunks(activityId: doc.documentID, expectedCount: remote.routeChunkCount ?? 0, fallbackRoute: remote.route)
            
            return ActivitySession(
                id: UUID(uuidString: remote.id ?? doc.documentID) ?? activityId,
                startDate: remote.startDate,
                endDate: remote.endDate,
                activityType: remote.activityType,
                distanceMeters: remote.distanceMeters,
                durationSeconds: remote.durationSeconds,
                workoutName: remote.workoutName,
                route: route,
                xpBreakdown: remote.xpBreakdown,
                territoryStats: remote.territoryStats,
                missions: remote.missions
            )
        } catch {
            print("[Activities] Failed to fetch activity \(activityId): \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }
    
    #if canImport(FirebaseFirestore)
    private func fetchActivitiesIndividually(ids: Set<String>) async throws -> [ActivitySession] {
        var results: [ActivitySession] = []
        for id in ids {
            let doc = try await db.collection("activities").document(id).getDocument()
            if doc.data() == nil { continue }
            do {
                let remote = try doc.data(as: FirestoreActivity.self)
                let route = await fetchRouteChunks(activityId: doc.documentID, expectedCount: remote.routeChunkCount ?? 0, fallbackRoute: remote.route)
                let session = ActivitySession(
                    id: UUID(uuidString: remote.id ?? doc.documentID) ?? UUID(),
                    startDate: remote.startDate,
                    endDate: remote.endDate,
                    activityType: remote.activityType,
                    distanceMeters: remote.distanceMeters,
                    durationSeconds: remote.durationSeconds,
                    workoutName: remote.workoutName,
                    route: route,
                    xpBreakdown: remote.xpBreakdown,
                    territoryStats: remote.territoryStats,
                    missions: remote.missions
                )
                results.append(session)
            } catch {
                print("[Activities] Failed to decode activity \(doc.documentID): \(error)")
            }
        }
        return results
    }
    #endif
}

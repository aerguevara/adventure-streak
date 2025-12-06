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
        let payload = FirestoreActivity(activity: activity, userId: userId)
        let docId = payload.id ?? "\(userId)-\(activity.id.uuidString)"
        
        do {
            try db.collection("activities")
                .document(docId)
                .setData(from: payload, merge: true)
            print("[Activities] Saved activity \(docId) for user \(userId)")
        } catch {
            print("[Activities] Failed to save activity \(docId): \(error.localizedDescription)")
        }
        #else
        print("[Activities] Firestore SDK not available; skipping remote save.")
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
    
    /// Ensure remote collection contains all local activities; uploads any missing and logs differences.
    func ensureRemoteParity(userId: String, activityStore: ActivityStore = .shared) async {
        let localActivities = activityStore.fetchAllActivities()
        let localIds = Set(localActivities.map { $0.id.uuidString })
        let remoteIds = await fetchRemoteActivityIds(userId: userId)
        
        let missingRemote = localActivities.filter { !remoteIds.contains($0.id.uuidString) }
        let extraRemote = remoteIds.subtracting(localIds)
        
        print("[Activities] Parity check — local: \(localIds.count), remote: \(remoteIds.count), missingRemote: \(missingRemote.count), extraRemote: \(extraRemote.count)")
        
        if !missingRemote.isEmpty {
            print("[Activities] Uploading \(missingRemote.count) missing activities to remote")
            await saveActivities(missingRemote, userId: userId)
        }
        
        if !extraRemote.isEmpty {
            print("[Activities] Remote has \(extraRemote.count) activities not present locally (ids: \(Array(extraRemote.prefix(5))))")
        }
    }
}

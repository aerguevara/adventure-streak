import Foundation

enum PendingRouteStatus: String, Codable {
    case missingRoute
    case fetchError
}

struct PendingRouteImport: Identifiable, Codable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let activityType: ActivityType
    let distanceMeters: Double
    let durationSeconds: Double
    let workoutName: String?
    
    let sourceBundleId: String
    let sourceName: String
    
    let status: PendingRouteStatus
    let lastErrorDescription: String?
    let retryCount: Int
    let lastAttemptAt: Date
}

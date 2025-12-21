import Foundation
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif

enum NotificationType: String, Codable {
    case reaction
    case follow
    case achievement
}

struct AppNotification: Identifiable, Codable {
    @DocumentID var id: String?
    let recipientId: String
    let senderId: String
    let senderName: String
    let senderAvatarURL: String?
    let type: NotificationType
    let reactionType: String? // e.g. "fire", "trophy"
    let activityId: String?
    let timestamp: Date
    var isRead: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case recipientId
        case senderId
        case senderName
        case senderAvatarURL
        case type
        case reactionType
        case activityId
        case timestamp
        case isRead
    }
}

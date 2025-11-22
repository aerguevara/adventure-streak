import Foundation

enum BadgeCategory: String, Codable {
    case territory
    case streak
    case distance
    case activity
    case misc
}

struct Badge: Identifiable, Codable {
    let id: String
    let name: String
    let shortDescription: String
    let longDescription: String
    var isUnlocked: Bool
    var unlockedAt: Date?
    let iconSystemName: String
    let category: BadgeCategory
    
    // Helper to create a locked version of a badge definition
    static func definition(id: String, name: String, shortDescription: String, longDescription: String, icon: String, category: BadgeCategory) -> Badge {
        return Badge(id: id, name: name, shortDescription: shortDescription, longDescription: longDescription, isUnlocked: false, unlockedAt: nil, iconSystemName: icon, category: category)
    }
}

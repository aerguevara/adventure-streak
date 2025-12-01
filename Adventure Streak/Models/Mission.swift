import Foundation

enum MissionCategory: String, Codable {
    case territorial
    case physicalEffort
    case progression
    case social
    case dynamic
}

enum MissionRarity: String, Codable {
    case common
    case rare
    case epic
    case legendary
}

struct Mission: Identifiable, Codable {
    let id: String
    let userId: String
    let category: MissionCategory
    let name: String
    let description: String
    let rarity: MissionRarity
    
    // Simplified - no complex nested objects that might cause serialization issues
    // The activity itself already has territoryStats and xpBreakdown
    
    init(id: String = UUID().uuidString,
         userId: String,
         category: MissionCategory,
         name: String,
         description: String,
         rarity: MissionRarity) {
        self.id = id
        self.userId = userId
        self.category = category
        self.name = name
        self.description = description
        self.rarity = rarity
    }
}

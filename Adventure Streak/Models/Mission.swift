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

struct Mission: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let category: MissionCategory
    let name: String
    let description: String
    let rarity: MissionRarity
    
    enum CodingKeys: String, CodingKey {
        case id, userId, category, name, description, rarity
    }
    
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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.userId = try container.decode(String.self, forKey: .userId)
        self.category = try container.decode(MissionCategory.self, forKey: .category)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.rarity = try container.decode(MissionRarity.self, forKey: .rarity)
    }
}

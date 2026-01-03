import Foundation

enum BadgeCategory: String, Codable {
    case aggressive
    case social
    case training
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

import SwiftUI

/// Defines the visual properties of a Badge
struct BadgeDefinition: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String // Emoji or Asset Name
    let color: Color
}

/// Helper to access Badge Definitions
struct BadgeSystem {
    
    static func getDefinition(for id: String) -> BadgeDefinition {
        // Default fallback
        let fallback = BadgeDefinition(
            id: id,
            name: "Unknown Badge",
            description: "Achievement",
            icon: "🏆",
            color: .gray
        )
        
        return definitions[id] ?? fallback
    }
    
    static let definitions: [String: BadgeDefinition] = [
        // --- Aggressive ---
        "shadow_hunter": BadgeDefinition(id: "shadow_hunter", name: "Cazador de Sombras", description: "Robar 5 celdas a un mismo usuario en una sola actividad", icon: "🥷", color: Color(hex: "FF3B30")),
        "chaos_lord": BadgeDefinition(id: "chaos_lord", name: "Señor del Caos", description: "Robar territorios a 3 usuarios diferentes en un mismo día", icon: "😈", color: Color(hex: "FF3B30")),
        "takeover": BadgeDefinition(id: "takeover", name: "Toma de Posesión", description: "Robar una celda defendida hace menos de 24 horas", icon: "🏰", color: Color(hex: "FF3B30")),
        "reconquest_king": BadgeDefinition(id: "reconquest_king", name: "Rey de la Reconquista", description: "Acumular 100 XP solo reconquistando", icon: "👑", color: Color(hex: "FF3B30")),
        "uninvited": BadgeDefinition(id: "uninvited", name: "Sin Invitación", description: "Robar un territorio en una actividad de >10km", icon: "🚪", color: Color(hex: "FF3B30")),
        "streak_breaker": BadgeDefinition(id: "streak_breaker", name: "Interrupción de Racha", description: "Robar a un usuario con racha > 4 semanas", icon: "💔", color: Color(hex: "FF3B30")),
        "white_glove": BadgeDefinition(id: "white_glove", name: "Ladrón de Guante Blanco", description: "Robar una celda épica (>30 días)", icon: "🧤", color: Color(hex: "FF3B30")),
        "summit_looter": BadgeDefinition(id: "summit_looter", name: "Saqueador de Cumbres", description: "Robar en actividad con >200m desnivel", icon: "🏔️", color: Color(hex: "FF3B30")),
         "human_boomerang": BadgeDefinition(id: "human_boomerang", name: "Búmeran Humano", description: "Reconquistar una celda menos de 1 hora después de haberla perdido", icon: "🪃", color: Color(hex: "FF3B30")),
         "invader_silent": BadgeDefinition(id: "invader_silent", name: "Invasor Silencioso", description: "Conquistar 10 celdas de usuarios de nivel superior", icon: "🤫", color: Color(hex: "FF3B30")),
         "lightning_counter": BadgeDefinition(id: "lightning_counter", name: "Contraataque Relámpago", description: "Recuperar territorio perdido inmediatamente", icon: "⚡", color: Color(hex: "FF3B30")),
        
        // --- Social ---
        "steel_influencer": BadgeDefinition(id: "steel_influencer", name: "Influencer de Acero", description: "Recibir 50 reacciones en un post", icon: "📸", color: Color(hex: "5856D6")),
        "war_correspondent": BadgeDefinition(id: "war_correspondent", name: "Corresponsal de Guerra", description: "Publicar actividad con 3 robos", icon: "📰", color: Color(hex: "5856D6")),
        "sports_spirit": BadgeDefinition(id: "sports_spirit", name: "Espíritu Deportivo", description: "Reaccionar a 10 actividades de rivales", icon: "🤝", color: Color(hex: "5856D6")),
        "community_voice": BadgeDefinition(id: "community_voice", name: "Voz de la Comunidad", description: "Ser el primero en reaccionar a 20 actividades", icon: "🗣️", color: Color(hex: "5856D6")),
        "trust_circle": BadgeDefinition(id: "trust_circle", name: "Círculo de Confianza", description: "Seguir a 5 usuarios que te sigan", icon: "⭕", color: Color(hex: "5856D6")),

        
        // --- Training ---
        "xp_machine": BadgeDefinition(id: "xp_machine", name: "Máquina de XP", description: "Cap de 300 XP base 3 días seguidos", icon: "🤖", color: Color(hex: "32D74B")),
        "early_bird": BadgeDefinition(id: "early_bird", name: "Madrugador", description: "Entrenamiento >5km antes de las 7:00 AM", icon: "🌅", color: Color(hex: "32D74B")),
        "iron_stamina": BadgeDefinition(id: "iron_stamina", name: "Resistencia de Hierro", description: "Indoor > 90 minutos", icon: "🏋️", color: Color(hex: "32D74B")),
        "elite_sprinter": BadgeDefinition(id: "elite_sprinter", name: "Velocista de Élite", description: "Ritmo < 4:30 min/km en 5km", icon: "🐆", color: Color(hex: "32D74B")),
        "km_eater": BadgeDefinition(id: "km_eater", name: "Devora Kilómetros", description: "Superar récord semanal por >10km", icon: "🍽️", color: Color(hex: "32D74B")),
        "pure_consistency": BadgeDefinition(id: "pure_consistency", name: "Constancia Pura", description: "Racha activa de 12 semanas", icon: "📅", color: Color(hex: "32D74B")),
        "triathlete": BadgeDefinition(id: "triathlete", name: "Triatleta en Ciernes", description: "Registrar Carrera, Ciclismo y Otros en una semana", icon: "🏊", color: Color(hex: "32D74B")),
        "max_efficiency": BadgeDefinition(id: "max_efficiency", name: "Eficiencia Máxima", description: "Ganar >500 XP en una actividad", icon: "⚡", color: Color(hex: "32D74B")),
        "deep_explorer": BadgeDefinition(id: "deep_explorer", name: "Explorador de Fondo", description: "Conquistar 30 celdas nuevas en >15km", icon: "🧭", color: Color(hex: "32D74B")),
        "level_10_express": BadgeDefinition(id: "level_10_express", name: "Nivel 10 Express", description: "Nivel 10 en <30 días", icon: "🚀", color: Color(hex: "32D74B"))
    ]
}

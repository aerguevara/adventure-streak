import Foundation
import Combine

struct Season: Equatable {
    let id: String
    let name: String
    let subtitle: String
    let startDate: Date
    let endDate: Date
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endDate)
        return max(0, components.day ?? 0)
    }
}

@MainActor
class SeasonManager: ObservableObject {
    static let shared = SeasonManager()
    
    @Published private(set) var currentSeason: Season
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Initialize with default/calculated season
        self.currentSeason = Self.calculateSeason(config: GameConfigService.shared.config)
        
        // Observe config changes to update season reactively
        GameConfigService.shared.$config
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshSeason()
            }
            .store(in: &cancellables)
    }
    
    func refreshSeason() {
        self.currentSeason = Self.calculateSeason(config: GameConfigService.shared.config)
    }
    
    func getCurrentSeason() -> Season {
        return currentSeason
    }
    
    private static func calculateSeason(config: GameConfig) -> Season {
        // 1. If backend provides a specific season, prioritize it!
        if let dynamicId = config.currentSeasonId {
            return Season(
                id: dynamicId,
                name: config.currentSeasonName ?? "Nueva Temporada",
                subtitle: config.currentSeasonSubtitle ?? "Enero 2026",
                startDate: config.globalResetDate ?? Date(),
                // Default to 90 days if no end date in config
                endDate: Calendar.current.date(byAdding: .day, value: 90, to: config.globalResetDate ?? Date()) ?? Date()
            )
        }
        
        // 2. Fallback to automatic date-based logic
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now) // 1-12
        
        // Match backend logic: 4 quarters per year
        let quarter = ((month - 1) / 3) + 1
        let seasonId = "T\(quarter)_\(year)"
        let seasonName = "Temporada \(quarter)"
        
        // Start of quarter
        var startComponents = DateComponents()
        startComponents.year = year
        startComponents.month = ((quarter - 1) * 3) + 1
        startComponents.day = 1
        let startDate = calendar.date(from: startComponents) ?? now
        
        // End of quarter (Start of next quarter - 1 day)
        var endComponents = DateComponents()
        if quarter == 4 {
            endComponents.year = year + 1
            endComponents.month = 1
        } else {
            endComponents.year = year
            endComponents.month = (quarter * 3) + 1
        }
        endComponents.day = 1
        let endDate = calendar.date(from: endComponents) ?? now
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "LLLL yyyy"
        let subtitle = formatter.string(from: now).capitalized
        
        return Season(id: seasonId, name: seasonName, subtitle: subtitle, startDate: startDate, endDate: endDate)
    }
}

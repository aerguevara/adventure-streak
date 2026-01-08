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
    @Published var isResetAcknowledgmentPending: Bool = false
    @Published var isProfileLoaded: Bool = false
    @Published var isConfigLoaded: Bool = false
    @Published var canStartSync: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Initialize with default/calculated season
        self.currentSeason = Self.calculateSeason(config: GameConfigService.shared.config)
        self.isConfigLoaded = GameConfigService.shared.isLoaded
        
        // Setup observer for sync readiness
        Publishers.CombineLatest3($isProfileLoaded, $isConfigLoaded, $isResetAcknowledgmentPending)
            .map { profile, config, resetPending in
                profile && config && !resetPending
            }
            .assign(to: &$canStartSync)
        
        // Observe config changes to update season and sync status reactively
        GameConfigService.shared.$config
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshSeason()
                self?.isConfigLoaded = GameConfigService.shared.isLoaded
            }
            .store(in: &cancellables)
    }
    
    func reset() {
        self.isProfileLoaded = false
        self.isResetAcknowledgmentPending = false
        // isConfigLoaded stays since it's global
    }
    
    func evaluateResetStatus(user: User?, config: GameConfig) {
        guard let user = user else {
            self.isProfileLoaded = false
            self.isResetAcknowledgmentPending = false
            return
        }
        
        self.isConfigLoaded = true // If we have a config object passed here
        
        // 1. Check Season ID Mismatch
        let currentSeasonId = SeasonManager.calculateSeason(config: config).id
        let lastAckId = user.lastAcknowledgeSeasonId
        let seasonChanged = lastAckId != currentSeasonId
        
        // 2. Check Reset Date Mismatch
        var resetDateTrigger = false
        if let serverResetDate = user.lastSeasonReset {
            if let lastAckDate = user.lastAcknowledgedResetAt {
                resetDateTrigger = serverResetDate > lastAckDate.addingTimeInterval(1)
            } else {
                resetDateTrigger = true
            }
        }
        
        // 3. Special case: New user with no data should not see modal
        var isNewUserNoData = false
        if user.lastAcknowledgeSeasonId == nil && (user.totalActivities ?? 0) == 0 && (user.totalCellsOwned ?? 0) == 0 {
            isNewUserNoData = true
        }
        
        self.isResetAcknowledgmentPending = (seasonChanged || resetDateTrigger) && !isNewUserNoData
        
        // FINAL: Set profile loaded last to avoid race conditions with canStartSync
        self.isProfileLoaded = true
        
        print("🌍 [SeasonManager] Reset Evaluation: SeasonChanged=\(seasonChanged), DateTrigger=\(resetDateTrigger), isNew=\(isNewUserNoData) -> Pending=\(isResetAcknowledgmentPending)")
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

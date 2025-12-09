import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct GameConfig: Equatable {
    var loadHistoricalWorkouts: Bool
    var workoutLookbackDays: Int
    var territoryExpirationDays: Int
    
    static let `default` = GameConfig(
        loadHistoricalWorkouts: true,
        workoutLookbackDays: 7,
        territoryExpirationDays: 7
    )
    
    var clampedLookbackDays: Int {
        max(1, min(workoutLookbackDays, 60))
    }
    
    var clampedTerritoryExpiration: Int {
        max(1, min(territoryExpirationDays, 60))
    }
    
    func sanitized() -> GameConfig {
        GameConfig(
            loadHistoricalWorkouts: loadHistoricalWorkouts,
            workoutLookbackDays: clampedLookbackDays,
            territoryExpirationDays: clampedTerritoryExpiration
        )
    }
}

@MainActor
final class GameConfigService: ObservableObject {
    static let shared = GameConfigService()
    
    @Published private(set) var config: GameConfig = .default
    @Published private(set) var isLoaded = false
    
    private var loadTask: Task<GameConfig, Never>?
    
    private init() {}
    
    func loadConfigIfNeeded() async {
        if isLoaded {
            print("[Config] Already loaded. Historical: \(config.loadHistoricalWorkouts), Lookback days: \(config.clampedLookbackDays)")
            return
        }
        
        if let loadTask = loadTask {
            print("[Config] Awaiting in-flight load task")
            let config = await loadTask.value
            apply(config)
            return
        }
        
        print("[Config] Loading config (first pass)...")
        let task = Task { await self.fetchRemoteConfig() ?? GameConfig.default }
        loadTask = task
        let config = await task.value
        apply(config)
        loadTask = nil
    }
    
    func refresh() async {
        print("[Config] Refreshing config...")
        let task = Task { await self.fetchRemoteConfig() ?? GameConfig.default }
        loadTask = task
        let config = await task.value
        apply(config)
        loadTask = nil
    }
    
    private func apply(_ config: GameConfig) {
        let sanitized = config.sanitized()
        self.config = sanitized
        self.isLoaded = true
        print("[Config] Applied config. Historical: \(sanitized.loadHistoricalWorkouts), Lookback days: \(sanitized.clampedLookbackDays)")
    }
    
    func cutoffDate(from reference: Date = Date()) -> Date {
        Calendar.current.date(
            byAdding: .day,
            value: -config.clampedLookbackDays,
            to: reference
        ) ?? reference
    }
    
    private func fetchRemoteConfig() async -> GameConfig? {
        var loaded = config
        
        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await Firestore.firestore()
                .collection("config")
                .document("gameplay")
                .getDocument()
            
            if let data = snapshot.data() {
                print("[Config] Remote data received: \(data)")
                let loadHistorical = data["loadHistoricalWorkouts"] as? Bool
                    ?? data["importHistoricalWorkouts"] as? Bool
                    ?? loaded.loadHistoricalWorkouts
                
                let lookbackSource = data["workoutLookbackDays"] ?? data["lookbackDays"]
                let lookback = (lookbackSource as? Int)
                    ?? (lookbackSource as? NSNumber)?.intValue
                    ?? loaded.workoutLookbackDays
                
                let expirationSource = data["territoryExpirationDays"]
                let expiration = (expirationSource as? Int)
                    ?? (expirationSource as? NSNumber)?.intValue
                    ?? loaded.territoryExpirationDays
                
                loaded = GameConfig(
                    loadHistoricalWorkouts: loadHistorical,
                    workoutLookbackDays: lookback,
                    territoryExpirationDays: expiration
                )
            }
        } catch {
            print("[Config] Error fetching remote config: \(error.localizedDescription)")
        }
        #endif
        
        return loaded
    }
}

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct GameConfig: Equatable {
    var loadHistoricalWorkouts: Bool
    var workoutLookbackDays: Int
    
    static let `default` = GameConfig(
        loadHistoricalWorkouts: true,
        workoutLookbackDays: 7
    )
    
    var clampedLookbackDays: Int {
        max(1, min(workoutLookbackDays, 60))
    }
    
    func sanitized() -> GameConfig {
        GameConfig(
            loadHistoricalWorkouts: loadHistoricalWorkouts,
            workoutLookbackDays: clampedLookbackDays
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
        if isLoaded { return }
        
        if let loadTask = loadTask {
            let config = await loadTask.value
            apply(config)
            return
        }
        
        let task = Task { await self.fetchRemoteConfig() ?? GameConfig.default }
        loadTask = task
        let config = await task.value
        apply(config)
        loadTask = nil
    }
    
    func refresh() async {
        let task = Task { await self.fetchRemoteConfig() ?? GameConfig.default }
        loadTask = task
        let config = await task.value
        apply(config)
        loadTask = nil
    }
    
    private func apply(_ config: GameConfig) {
        self.config = config.sanitized()
        self.isLoaded = true
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
                let loadHistorical = data["loadHistoricalWorkouts"] as? Bool
                    ?? data["importHistoricalWorkouts"] as? Bool
                    ?? loaded.loadHistoricalWorkouts
                
                let lookbackSource = data["workoutLookbackDays"] ?? data["lookbackDays"]
                let lookback = (lookbackSource as? Int)
                    ?? (lookbackSource as? NSNumber)?.intValue
                    ?? loaded.workoutLookbackDays
                
                loaded = GameConfig(
                    loadHistoricalWorkouts: loadHistorical,
                    workoutLookbackDays: lookback
                )
            }
        } catch {
            print("[Config] Error fetching remote config: \(error.localizedDescription)")
        }
        #endif
        
        return loaded
    }
}

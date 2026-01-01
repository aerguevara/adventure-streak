import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct GameConfig: Equatable {
    var loadHistoricalWorkouts: Bool
    var workoutLookbackDays: Int
    var territoryExpirationDays: Int
    var routeExpectedBundles: [String]
    var routeOptionalBundles: [String]
    var onboardingImportLimit: Int
    var globalResetDate: Date? // Managed from Firebase
    
    static let `default`: GameConfig = {
        let mainId = Bundle.main.bundleIdentifier ?? "com.adventurestreak"
        let watchId = "\(mainId).watchkitapp.watchkitextension"
        return GameConfig(
            loadHistoricalWorkouts: true,
            workoutLookbackDays: 7,
            territoryExpirationDays: 7,
            routeExpectedBundles: ["com.apple.", mainId, watchId],
            routeOptionalBundles: [],
            onboardingImportLimit: 10,
            globalResetDate: nil
        )
    }()
    
    var clampedLookbackDays: Int {
        max(0, min(workoutLookbackDays, 60))
    }
    
    var clampedTerritoryExpiration: Int {
        max(1, min(territoryExpirationDays, 60))
    }
    
    func sanitized() -> GameConfig {
        GameConfig(
            loadHistoricalWorkouts: loadHistoricalWorkouts,
            workoutLookbackDays: clampedLookbackDays,
            territoryExpirationDays: clampedTerritoryExpiration,
            routeExpectedBundles: routeExpectedBundles,
            routeOptionalBundles: routeOptionalBundles,
            onboardingImportLimit: onboardingImportLimit,
            globalResetDate: globalResetDate
        )
    }
    
    func requiresRoute(for bundleId: String) -> Bool {
        routeExpectedBundles.contains(where: { bundleId == $0 || bundleId.hasPrefix($0) })
    }
    
    func isOptionalRouteSource(_ bundleId: String) -> Bool {
        routeOptionalBundles.contains(where: { bundleId == $0 || bundleId.hasPrefix($0) })
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
        // PURE & SIMPLE: Lookback X days from today.
        // No floors, no onboarding locks. If Firebase says 28 days, we fetch 28 days.
        let days = config.clampedLookbackDays
        let lookbackDate = Calendar.current.date(
            byAdding: .day,
            value: -days,
            to: reference
        ) ?? reference
        
        print("⚙️ [Config] Simple Cutoff: \(days) days lookback -> \(lookbackDate)")
        return lookbackDate
    }
    
    private func fetchRemoteConfig() async -> GameConfig? {
        var loaded = config
        
        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await Firestore.shared
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
                
                let expectedBundles = data["routeExpectedBundles"] as? [String]
                    ?? loaded.routeExpectedBundles
                let optionalBundles = data["routeOptionalBundles"] as? [String]
                    ?? loaded.routeOptionalBundles
                
                let importLimitSource = data["onboardingImportLimit"]
                let importLimit = (importLimitSource as? Int)
                    ?? (importLimitSource as? NSNumber)?.intValue
                    ?? loaded.onboardingImportLimit
                
                let resetTimestamp = data["globalResetDate"] as? Timestamp
                let resetDate = resetTimestamp?.dateValue()
                
                loaded = GameConfig(
                    loadHistoricalWorkouts: loadHistorical,
                    workoutLookbackDays: lookback,
                    territoryExpirationDays: expiration,
                    routeExpectedBundles: expectedBundles,
                    routeOptionalBundles: optionalBundles,
                    onboardingImportLimit: importLimit,
                    globalResetDate: resetDate
                )
            }
        } catch {
            print("[Config] Error fetching remote config: \(error.localizedDescription)")
        }
        #endif
        
        return loaded
    }
}

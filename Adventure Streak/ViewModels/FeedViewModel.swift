import Foundation
import Combine

@MainActor
class FeedViewModel: ObservableObject {
    @Published var events: [FeedEvent] = []
    @Published var weeklySummary: WeeklySummaryViewData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let repository: FeedRepositoryProtocol
    private let activityStore: ActivityStore
    private let territoryStore: TerritoryStore
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: FeedRepositoryProtocol? = nil,
         activityStore: ActivityStore,
         territoryStore: TerritoryStore) {
        self.repository = repository ?? FeedRepository.shared
        self.activityStore = activityStore
        self.territoryStore = territoryStore
        setupBindings()
    }
    
    private func setupBindings() {
        // ... (existing binding code)
        if let repo = repository as? FeedRepository {
            repo.$events
                .receive(on: RunLoop.main)
                .assign(to: &$events)
        }
    }
    
    func loadFeed() async {
        isLoading = true
        errorMessage = nil
        if let repo = repository as? FeedRepository {
            await repo.fetchLatest()
            repo.observeFeed() // keep live updates from Firebase only
        } else {
            repository.observeFeed()
        }
        calculateWeeklySummary()
        isLoading = false
    }
    
    private func calculateWeeklySummary() {
        let calendar = Calendar.current
        let now = Date()
        
        // Get start of current week (Monday)
        // Assuming week starts on Monday for this locale, or use user's locale
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        components.weekday = 2 // Monday
        let startOfWeek = calendar.date(from: components) ?? now.addingTimeInterval(-7*24*3600)
        
        // 1. Total Distance (This Week)
        let weeklyActivities = activityStore.activities.filter { $0.startDate >= startOfWeek }
        let totalDistanceMeters = weeklyActivities.reduce(0) { $0 + $1.distanceMeters }
        let totalDistanceKm = totalDistanceMeters / 1000.0
        
        // 2. Territories Conquered (This Week)
        // We check 'lastConqueredAt'
        let weeklyTerritories = territoryStore.fetchAllCells().filter { $0.lastConqueredAt >= startOfWeek }
        let conqueredCount = weeklyTerritories.count
        
        // 3. Streak
        // let streak = activityStore.calculateCurrentStreak() // DEPRECATED: Use server stats
        let streak = 0 // Placeholder
        
        // 4. Lost / Rival (Placeholder for now as we don't track history of losses locally)
        let lostCount = 0 
        let rivalName: String? = nil
        
        self.weeklySummary = WeeklySummaryViewData(
            totalDistance: totalDistanceKm,
            territoriesConquered: conqueredCount,
            territoriesLost: lostCount,
            currentStreakWeeks: streak,
            rivalName: rivalName
        )
    }
    
    func refresh() async {
        await loadFeed()
    }
}

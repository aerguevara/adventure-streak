import Foundation
import SwiftUI
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class RivalryViewModel: ObservableObject {
    @Published var targetRanking: RankingEntry? = nil
    @Published var viewerRanking: RankingEntry? = nil
    @Published var rivalry: RivalryRelationship? = nil
    @Published var isLoading: Bool = false
    
    // NEW: Activity history state
    @Published var activities: [ActivitySession] = []
    @Published var isLoadingActivities: Bool = false
    @Published var canLoadMore: Bool = true
    private var lastDoc: QueryDocumentSnapshot? = nil
    private let pageSize = 15
    
    private let targetUserId: String
    private let viewerId: String?
    private var cancellables = Set<AnyCancellable>()
    
    init(targetUserId: String) {
        self.targetUserId = targetUserId
        self.viewerId = AuthenticationService.shared.userId
        
        loadComparisonData()
        fetchActivities()
    }
    
    func loadComparisonData() {
        guard let viewerId = viewerId else { return }
        isLoading = true
        
        Task {
            // 1. Fetch Ranking Entries
            GamificationRepository.shared.fetchWeeklyRanking(limit: 100) { [weak self] entries in
                guard let self = self else { return }
                Task { @MainActor in
                    self.targetRanking = entries.first(where: { $0.userId == self.targetUserId })
                    self.viewerRanking = entries.first(where: { $0.userId == viewerId })
                    self.isLoading = false
                }
            }
            
            // 2. Fetch User Object to calculate Rivalry from interaction lists
            // We use the viewer's user object because it contains the counts against others
            if let viewer = await UserRepository.shared.getUser(userId: viewerId) {
                let userScore = viewer.recentTheftVictims?.first(where: { $0.userId == targetUserId })?.count ?? 0
                let rivalScore = viewer.recentThieves?.first(where: { $0.userId == targetUserId })?.count ?? 0
                let lastDate = [
                    viewer.recentTheftVictims?.first(where: { $0.userId == targetUserId })?.lastInteractionAt,
                    viewer.recentThieves?.first(where: { $0.userId == targetUserId })?.lastInteractionAt
                ].compactMap { $0 }.max() ?? Date.distantPast
                
                if userScore > 0 || rivalScore > 0 {
                    let trend: RankingTrend = userScore > rivalScore ? .up : (userScore < rivalScore ? .down : .neutral)
                    
                    self.rivalry = RivalryRelationship(
                        userId: targetUserId,
                        displayName: "", // This will be handled by the view
                        avatarURL: nil,
                        userScore: userScore,
                        rivalScore: rivalScore,
                        lastInteractionAt: lastDate,
                        trend: trend
                    )
                }
            }
        }
    }
    
    // NEW: Fetch activities for the target user
    func fetchActivities() {
        guard !isLoadingActivities else { return }
        isLoadingActivities = true
        
        Task {
            do {
                let result = try await ActivityRepository.shared.fetchActivities(
                    userId: targetUserId,
                    limit: pageSize,
                    lastDoc: nil
                )
                
                self.activities = result.activities
                self.lastDoc = result.lastDoc
                self.canLoadMore = result.activities.count == pageSize
                self.isLoadingActivities = false
                print("DEBUG: [RivalryViewModel] Fetched \(result.activities.count) activities for \(targetUserId)")
            } catch {
                print("ERROR: [RivalryViewModel] Failed to fetch activities: \(error.localizedDescription)")
                self.isLoadingActivities = false
            }
        }
    }
    
    func fetchMoreActivities() {
        guard !isLoadingActivities && canLoadMore, let lastDoc = lastDoc else { return }
        isLoadingActivities = true
        
        Task {
            do {
                let result = try await ActivityRepository.shared.fetchActivities(
                    userId: targetUserId,
                    limit: pageSize,
                    lastDoc: lastDoc
                )
                
                self.activities.append(contentsOf: result.activities)
                self.lastDoc = result.lastDoc
                self.canLoadMore = result.activities.count == pageSize
                self.isLoadingActivities = false
                print("DEBUG: [RivalryViewModel] Fetched \(result.activities.count) MORE activities for \(targetUserId)")
            } catch {
                print("ERROR: [RivalryViewModel] Failed to fetch more activities: \(error.localizedDescription)")
                self.isLoadingActivities = false
            }
        }
    }
}


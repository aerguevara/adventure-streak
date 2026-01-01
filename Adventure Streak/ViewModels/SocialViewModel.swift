import Foundation
import Combine

@MainActor
class SocialViewModel: ObservableObject {
    @Published var posts: [SocialPost] = []
    @Published var stories: [UserStory] = []
    @Published var isLoading: Bool = false
    @Published var reactionStates: [String: ActivityReactionState] = [:]

    private let socialService = SocialService.shared
    private let reactionRepository = ReactionRepository.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Subscribe to service posts
        socialService.$posts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] posts in
                self?.posts = posts
                self?.updateStories(from: posts)
                let ids = posts.compactMap { $0.activityId }
                self?.reactionRepository.observeActivities(ids)
            }
            .store(in: &cancellables)

        reactionRepository.$reactionStates
            .receive(on: DispatchQueue.main)
            .assign(to: \.reactionStates, on: self)
            .store(in: &cancellables)

        // Ensure service is observing
        socialService.startObserving()
    }

    func refresh() async {
        isLoading = true
        await socialService.refreshFeed()
        isLoading = false
    }

    var displayPosts: [SocialPost] {
        posts.sorted { lhs, rhs in
            lhs.date > rhs.date
        }
    }

    private func reactionScore(for post: SocialPost) -> Int {
        let state = reactionState(for: post)
        var score = 0
        score += state.swordCount * 3
        score += state.shieldCount * 2
        score += state.fireCount
        return score
    }

    func reactionState(for post: SocialPost) -> ActivityReactionState {
        guard let activityId = post.activityId else { return baseReactionState(from: post) }
        var state = reactionStates[activityId] ?? baseReactionState(from: post)
        
        if state.fireCount == 0 && state.swordCount == 0 && state.shieldCount == 0 {
            let base = baseReactionState(from: post)
            state.fireCount = base.fireCount
            state.swordCount = base.swordCount
            state.shieldCount = base.shieldCount
        }
        
        if state.currentUserReaction == nil {
            state.currentUserReaction = post.activityData.currentUserReaction
        }
        
        // Ensure the user's own reaction shows a count even if remote stats haven't synced yet.
        if state.fireCount == 0 && state.swordCount == 0 && state.shieldCount == 0,
           let selfReaction = state.currentUserReaction {
            switch selfReaction {
            case .fire: state.fireCount = 1
            case .sword: state.swordCount = 1
            case .shield: state.shieldCount = 1
            }
        }
        return state
    }

    func react(to post: SocialPost, with reaction: ReactionType) {
        guard let activityId = post.activityId else { return }

        var state = reactionState(for: post)
        let previous = state.currentUserReaction
        
        if previous == reaction {
            switch reaction {
            case .fire: state.fireCount = max(0, state.fireCount - 1)
            case .sword: state.swordCount = max(0, state.swordCount - 1)
            case .shield: state.shieldCount = max(0, state.shieldCount - 1)
            }
            state.currentUserReaction = nil
            reactionRepository.updateLocalState(for: activityId, state: state)
            Task {
                await reactionRepository.removeReaction(for: activityId, authorId: post.userId)
            }
            return
        }

        if let previous {
            switch previous {
            case .fire: state.fireCount = max(0, state.fireCount - 1)
            case .sword: state.swordCount = max(0, state.swordCount - 1)
            case .shield: state.shieldCount = max(0, state.shieldCount - 1)
            }
        }

        switch reaction {
        case .fire: state.fireCount += 1
        case .sword: state.swordCount += 1
        case .shield: state.shieldCount += 1
        }

        state.currentUserReaction = reaction
        reactionRepository.updateLocalState(for: activityId, state: state)

        Task {
            await reactionRepository.sendReaction(for: activityId, authorId: post.userId, type: reaction)
        }
    }

    private func baseReactionState(from post: SocialPost) -> ActivityReactionState {
        ActivityReactionState(
            swordCount: post.activityData.swordCount,
            shieldCount: post.activityData.shieldCount,
            fireCount: post.activityData.fireCount,
            currentUserReaction: post.activityData.currentUserReaction
        )
    }

    private func updateStories(from posts: [SocialPost]) {
        let now = Date()
        let twentyFourHoursAgo = now.addingTimeInterval(-24 * 3600)
        
        let territoryEvents = posts.filter { post in
            post.date >= twentyFourHoursAgo && post.hasTerritoryImpact
        }
        
        let grouped = Dictionary(grouping: territoryEvents) { $0.userId }
        
        self.stories = grouped.compactMap { (userId, activities) -> UserStory? in
            guard let firstActivity = activities.first else { return nil }
            return UserStory(user: firstActivity.user, activities: activities.sorted(by: { $0.date < $1.date }))
        }.sorted(by: { $0.latestDate < $1.latestDate })
    }
}

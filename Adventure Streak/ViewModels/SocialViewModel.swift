import Foundation
import Combine

@MainActor
class SocialViewModel: ObservableObject {
    @Published var posts: [SocialPost] = []
    @Published var isLoading: Bool = false
    @Published var reactionStates: [UUID: ActivityReactionState] = [:]

    private let socialService = SocialService.shared
    private let reactionRepository = ReactionRepository.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Subscribe to service posts
        socialService.$posts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] posts in
                self?.posts = posts
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
        socialService.startObserving()
    }

    var displayPosts: [SocialPost] {
        posts.sorted { lhs, rhs in
            lhs.date > rhs.date
        }
    }

    private func reactionScore(for post: SocialPost) -> Int {
        let state = reactionState(for: post)
        var score = 0
        score += state.trophyCount * 3
        score += state.devilCount * 2
        score += state.fireCount
        return score
    }

    func reactionState(for post: SocialPost) -> ActivityReactionState {
        guard let activityId = post.activityId else { return baseReactionState(from: post) }
        var state = reactionStates[activityId] ?? baseReactionState(from: post)
        if state.fireCount == 0 && state.trophyCount == 0 && state.devilCount == 0 {
            let base = baseReactionState(from: post)
            state.fireCount = base.fireCount
            state.trophyCount = base.trophyCount
            state.devilCount = base.devilCount
        }
        if state.currentUserReaction == nil {
            state.currentUserReaction = post.activityData.currentUserReaction
        }
        // Ensure the user's own reaction shows a count even if remote stats haven't synced yet.
        if state.fireCount == 0 && state.trophyCount == 0 && state.devilCount == 0,
           let selfReaction = state.currentUserReaction {
            switch selfReaction {
            case .fire: state.fireCount = 1
            case .trophy: state.trophyCount = 1
            case .devil: state.devilCount = 1
            }
        }
        return state
    }

    func react(to post: SocialPost, with reaction: ReactionType) {
        guard let activityId = post.activityId else { return }

        var state = reactionState(for: post)
        let previous = state.currentUserReaction
        if previous == reaction { return }

        if let previous {
            switch previous {
            case .fire: state.fireCount = max(0, state.fireCount - 1)
            case .trophy: state.trophyCount = max(0, state.trophyCount - 1)
            case .devil: state.devilCount = max(0, state.devilCount - 1)
            }
        }

        switch reaction {
        case .fire: state.fireCount += 1
        case .trophy: state.trophyCount += 1
        case .devil: state.devilCount += 1
        }

        state.currentUserReaction = reaction
        reactionRepository.updateLocalState(for: activityId, state: state)

        Task {
            await reactionRepository.sendReaction(for: activityId, authorId: post.userId, type: reaction)
        }
    }

    private func baseReactionState(from post: SocialPost) -> ActivityReactionState {
        ActivityReactionState(
            fireCount: post.activityData.fireCount,
            trophyCount: post.activityData.trophyCount,
            devilCount: post.activityData.devilCount,
            currentUserReaction: post.activityData.currentUserReaction
        )
    }
}

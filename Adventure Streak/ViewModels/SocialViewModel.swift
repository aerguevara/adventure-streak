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
            let lhsScore = reactionScore(for: lhs)
            let rhsScore = reactionScore(for: rhs)
            if lhsScore == rhsScore {
                return lhs.date > rhs.date
            }
            return lhsScore > rhsScore
        }
    }

    private func reactionScore(for post: SocialPost) -> Int {
        guard let id = post.activityId, let state = reactionStates[id] else { return 0 }
        var score = 0
        score += state.trophyCount * 3
        score += state.devilCount * 2
        score += state.fireCount
        return score
    }

    func sendReaction(for post: SocialPost, reaction: ReactionType) {
        guard let activityId = post.activityId else { return }
        Task {
            await reactionRepository.sendReaction(for: activityId, authorId: post.userId, type: reaction)
        }
    }
}

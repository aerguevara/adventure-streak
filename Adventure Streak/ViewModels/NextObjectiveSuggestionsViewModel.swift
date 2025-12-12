import Foundation
import SwiftUI

@MainActor
final class NextObjectiveSuggestionsViewModel: ObservableObject {
    @Published var suggestions: [ActionSuggestion] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let recommendationService: ActionRecommendationService
    private var lastRequestKey: String?

    init(recommendationService: ActionRecommendationService = .shared) {
        self.recommendationService = recommendationService
    }

    func loadSuggestions(userEntry: RankingEntry, rivalEntry: RankingEntry) {
        let key = "\(userEntry.userId)-\(rivalEntry.userId)-\(rivalEntry.weeklyXP)"
        if lastRequestKey == key && !suggestions.isEmpty { return }
        lastRequestKey = key

        guard let userId = AuthenticationService.shared.userId else {
            errorMessage = "No pudimos cargar tu perfil."
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            let results = await recommendationService.recommendations(
                for: userId,
                userXP: userEntry.weeklyXP,
                targetXP: rivalEntry.weeklyXP
            )

            await MainActor.run {
                self.suggestions = results
                self.isLoading = false
                if results.isEmpty {
                    self.errorMessage = "No hay sugerencias disponibles ahora mismo."
                }
            }
        }
    }
}

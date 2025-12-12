import Foundation

@MainActor
final class ActionRecommendationService {
    static let shared = ActionRecommendationService()

    private let activityStore: ActivityStore
    private let gamificationService: GamificationService
    private let repository: GamificationRepository
    private let configService: GameConfigService

    init(activityStore: ActivityStore = .shared,
         gamificationService: GamificationService = .shared,
         repository: GamificationRepository = .shared,
         configService: GameConfigService = .shared) {
        self.activityStore = activityStore
        self.gamificationService = gamificationService
        self.repository = repository
        self.configService = configService
    }

    func recommendations(for userId: String, userXP: Int, targetXP: Int) async -> [ActionSuggestion] {
        let deltaXP = max(1, targetXP - userXP)

        do {
            await configService.loadConfigIfNeeded()
            let context = try await repository.buildXPContext(for: userId)
            let cutoff = configService.cutoffDate()
            let activities = activityStore.fetchAllActivities().filter { $0.startDate >= cutoff }

            let prioritizedTypes = prioritizeTypes(from: activities)
            var suggestions: [ActionSuggestion] = []

            for type in prioritizedTypes {
                guard suggestions.count < 4 else { break }

                let metrics = metrics(for: type, activities: activities)
                let xpRange = try await xpEstimate(for: type, metrics: metrics, context: context)
                let xpLabel = formattedXPLabel(range: xpRange)
                let coverageValue = Double(xpRange.midEstimate) / Double(deltaXP)
                let coverage = min(100, max(0, Int(round(coverageValue * 100))))
                let microcopy = microcopy(for: type, territory: metrics.territory)

                let title = actionTitle(for: type, metrics: metrics)
                let suggestion = ActionSuggestion(
                    title: title,
                    xpLabel: xpLabel,
                    coverageLabel: "Cubre \(coverage)% del objetivo",
                    coverageValue: coverage,
                    xpValue: xpRange.midEstimate,
                    microcopy: microcopy
                )
                suggestions.append(suggestion)
            }

            // Combo suggestion if delta not covered by any single action
            if let strongest = suggestions.first, suggestions.count < 5 {
                let bestCoverage = suggestions.map { $0.coverageValue }.max() ?? 0
                if bestCoverage < 100 {
                    let comboXP = strongest.xpValue * 2
                    let comboCoverage = min(100, Int(round(Double(comboXP) / Double(deltaXP) * 100)))
                    let combo = ActionSuggestion(
                        title: "Repite 2× \(strongest.title)",
                        xpLabel: "≈ \(comboXP) XP",
                        coverageLabel: "Cubre \(comboCoverage)% del objetivo",
                        coverageValue: comboCoverage,
                        xpValue: comboXP,
                        microcopy: strongest.microcopy
                    )
                    suggestions.append(combo)
                }
            }

            return suggestions
        } catch {
            print("[Recommendations] Error generating suggestions: \(error)")
            return []
        }
    }

    private func prioritizeTypes(from activities: [ActivitySession]) -> [ActivityType] {
        var counts: [ActivityType: Int] = [:]
        for activity in activities {
            counts[activity.activityType, default: 0] += 1
        }

        let sorted = counts.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key.rawValue < rhs.key.rawValue
            }
            return lhs.value > rhs.value
        }.map { $0.key }

        var ordered = sorted
        for type in ActivityType.allCases where !ordered.contains(type) {
            ordered.append(type)
        }
        return ordered
    }

    private func metrics(for type: ActivityType, activities: [ActivitySession]) -> (distance: Double, duration: Double, territory: TerritoryStats) {
        let filtered = activities.filter { $0.activityType == type }
        guard !filtered.isEmpty else {
            let baseDistance = XPConfig.minDistanceKm * 2.0 * 1000.0
            let baseDuration = XPConfig.minDurationSeconds * 1.5
            return (
                distance: baseDistance,
                duration: baseDuration,
                territory: TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0)
            )
        }

        let avgDistance = filtered.map { $0.distanceMeters }.average()
        let avgDuration = filtered.map { $0.durationSeconds }.average()

        let territorySamples = filtered.compactMap { $0.territoryStats }
        let territory: TerritoryStats
        if territorySamples.isEmpty {
            territory = TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0)
        } else {
            territory = TerritoryStats(
                newCellsCount: Int(territorySamples.map { Double($0.newCellsCount) }.average().rounded()),
                defendedCellsCount: Int(territorySamples.map { Double($0.defendedCellsCount) }.average().rounded()),
                recapturedCellsCount: Int(territorySamples.map { Double($0.recapturedCellsCount) }.average().rounded())
            )
        }

        return (
            distance: max(avgDistance, XPConfig.minDistanceKm * 1000.0),
            duration: max(avgDuration, XPConfig.minDurationSeconds),
            territory: territory
        )
    }

    private func actionTitle(for type: ActivityType, metrics: (distance: Double, duration: Double, territory: TerritoryStats)) -> String {
        if type == .indoor {
            let minutes = Int(round(metrics.duration / 60))
            return "\(type.displayName) \(minutes) min"
        }

        let distanceKm = metrics.distance / 1000.0
        let formattedDistance = String(format: "%.1f km", distanceKm)
        return "\(type.displayName) \(formattedDistance)"
    }

    private func xpEstimate(for type: ActivityType, metrics: (distance: Double, duration: Double, territory: TerritoryStats), context: XPContext) async throws -> XPRanges {
        let recentActivities = activityStore.fetchAllActivities().filter { $0.activityType == type }
        let historicalTotals = recentActivities.compactMap { $0.xpBreakdown?.total }

        let sampleRoute = route(for: type)
        let baseSession = ActivitySession(
            startDate: Date(),
            endDate: Date().addingTimeInterval(metrics.duration),
            activityType: type,
            distanceMeters: metrics.distance,
            durationSeconds: metrics.duration,
            workoutName: nil,
            route: sampleRoute
        )

        let breakdownWithTerritory = try await gamificationService.computeXP(
            for: baseSession,
            territoryStats: metrics.territory,
            context: context
        ).total

        let breakdownWithoutTerritory = try await gamificationService.computeXP(
            for: baseSession,
            territoryStats: TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0),
            context: context
        ).total

        let minValue = min(breakdownWithTerritory, breakdownWithoutTerritory)
        let maxValue = max(breakdownWithTerritory, breakdownWithoutTerritory)
        let historicalMin = historicalTotals.min()
        let historicalMax = historicalTotals.max()

        let lower = historicalMin ?? minValue
        let upper = historicalMax ?? maxValue
        let mid = (lower + upper) / 2

        return XPRanges(min: lower, max: upper, midEstimate: mid)
    }

    private func route(for type: ActivityType) -> [RoutePoint] {
        guard type.isOutdoor else { return [] }
        let now = Date()
        return [
            RoutePoint(latitude: 37.332, longitude: -122.031, timestamp: now),
            RoutePoint(latitude: 37.333, longitude: -122.032, timestamp: now.addingTimeInterval(600))
        ]
    }

    private func formattedXPLabel(range: XPRanges) -> String {
        if range.min == range.max {
            return "≈ \(range.midEstimate) XP"
        }
        return "≈ \(range.min)–\(range.max) XP"
    }

    private func microcopy(for type: ActivityType, territory: TerritoryStats) -> String? {
        if type.isOutdoor && (territory.newCellsCount > 0 || territory.recapturedCellsCount > 0 || territory.defendedCellsCount > 0) {
            return "Cuenta para conquista"
        }
        if !type.isOutdoor {
            return "No cuenta para territorio"
        }
        return nil
    }

}

private extension Collection where Element == Double {
    func average() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}

private struct XPRanges {
    let min: Int
    let max: Int
    let midEstimate: Int
}


import Foundation
import HealthKit

enum RouteFetchResult {
    case success([RoutePoint])
    case emptySeries
    case error(Error)
}

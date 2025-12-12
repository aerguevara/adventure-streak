import Foundation

struct ActionSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let xpLabel: String
    let coverageLabel: String
    let coverageValue: Int
    let xpValue: Int
    let microcopy: String?
}

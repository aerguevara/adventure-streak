import Foundation

@MainActor
class FeedSeenService: ObservableObject {
    static let shared = FeedSeenService()
    
    private let userDefaults = UserDefaults.standard
    private let seenIdsKey = "com.adventurestreak.social.seenIds"
    
    @Published private(set) var seenIds: Set<String> = []
    
    private init() {
        if let stored = userDefaults.stringArray(forKey: seenIdsKey) {
            self.seenIds = Set(stored)
        }
    }
    
    func isSeen(postId: String) -> Bool {
        return seenIds.contains(postId)
    }
    
    func markAsSeen(postId: String) {
        guard !seenIds.contains(postId) else { return }
        seenIds.insert(postId)
        persist()
    }
    
    func markAsSeen(postIds: Set<String>) {
        let newIds = postIds.subtracting(seenIds)
        guard !newIds.isEmpty else { return }
        seenIds.formUnion(newIds)
        persist()
    }
    
    private func persist() {
        userDefaults.set(Array(seenIds), forKey: seenIdsKey)
    }
}

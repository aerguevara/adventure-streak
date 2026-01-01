import Foundation

/// A simple global cache for map icons to prevent flickering and excessive network calls
class MapIconCacheManager {
    static let shared = MapIconCacheManager()
    
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "cached_map_icons"
    
    // In-memory cache for fast access
    private var iconCache: [String: String] = [:]
    private let queue = DispatchQueue(label: "com.adventurestreak.iconcache", attributes: .concurrent)
    
    private init() {
        // Load existing cache from UserDefaults on initialization
        if let savedCache = userDefaults.dictionary(forKey: cacheKey) as? [String: String] {
            iconCache = savedCache
        }
    }
    
    /// Get an icon for a specific user ID
    func getIcon(for userId: String) -> String? {
        queue.sync {
            return iconCache[userId]
        }
    }
    
    /// Set an icon for a specific user ID and persist it
    func setIcon(_ icon: String, for userId: String) {
        queue.async(flags: .barrier) {
            self.iconCache[userId] = icon
            
            // Persist periodically or immediately? Let's do it immediately for now as icons are small
            self.userDefaults.set(self.iconCache, forKey: self.cacheKey)
        }
    }
    
    /// Clear the cache (e.g. on logout)
    func clear() {
        queue.async(flags: .barrier) {
            self.iconCache.removeAll()
            self.userDefaults.removeObject(forKey: self.cacheKey)
        }
    }
}

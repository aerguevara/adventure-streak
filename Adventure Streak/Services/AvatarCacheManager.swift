import Foundation

final class AvatarCacheManager {
    static let shared = AvatarCacheManager()
    
    private let cache = NSCache<NSString, NSData>()
    private let fileManager = FileManager.default
    private let directory: URL
    
    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        directory = caches.appendingPathComponent("avatar-cache", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    
    func data(for userId: String) -> Data? {
        if let cached = cache.object(forKey: userId as NSString) {
            return cached as Data
        }
        let path = directory.appendingPathComponent("\(userId).jpg")
        if let data = try? Data(contentsOf: path) {
            cache.setObject(data as NSData, forKey: userId as NSString)
            return data
        }
        return nil
    }
    
    func save(data: Data, for userId: String) {
        cache.setObject(data as NSData, forKey: userId as NSString)
        let path = directory.appendingPathComponent("\(userId).jpg")
        try? data.write(to: path, options: .atomic)
    }
    
    func clear(for userId: String) {
        cache.removeObject(forKey: userId as NSString)
        let path = directory.appendingPathComponent("\(userId).jpg")
        try? fileManager.removeItem(at: path)
    }
}

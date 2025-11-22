import Foundation

class JSONStore<T: Codable & Identifiable> {
    private let filename: String
    
    init(filename: String) {
        self.filename = filename
    }
    
    private var fileURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(filename)
    }
    
    func save(_ items: [T]) throws {
        let data = try JSONEncoder().encode(items)
        try data.write(to: fileURL)
    }
    
    func load() -> [T] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([T].self, from: data)
        } catch {
            print("Error loading \(filename): \(error)")
            return []
        }
    }
}

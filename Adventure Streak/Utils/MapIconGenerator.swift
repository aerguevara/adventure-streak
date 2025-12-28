import UIKit

class MapIconGenerator {
    static let shared = MapIconGenerator()
    private var cache: [String: UIImage] = [:]
    
    func icon(for emoji: String, size: CGFloat = 28) -> UIImage? {
        let cacheKey = "\(emoji)_\(size)"
        if let cached = cache[cacheKey] {
            return cached
        }
        
        let label = UILabel()
        label.text = emoji
        label.font = .systemFont(ofSize: size)
        label.textAlignment = .center
        
        // Add padding for shadow
        let padding: CGFloat = 4
        let labelSize = label.intrinsicContentSize
        let frameSize = CGSize(width: labelSize.width + padding * 2, height: labelSize.height + padding * 2)
        label.frame = CGRect(origin: .zero, size: frameSize)
        
        // Setup shadow
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.8
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowRadius = 2
        
        // Render to image
        let renderer = UIGraphicsImageRenderer(size: frameSize)
        let image = renderer.image { context in
             label.layer.render(in: context.cgContext)
        }
        
        cache[cacheKey] = image
        return image
    }
}

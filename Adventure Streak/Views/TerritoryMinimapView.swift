import SwiftUI
import MapKit

struct TerritoryMinimapView: View {
    let territories: [TerritoryCell]
    var tintColor: Color = .green
    
    @State private var snapshotImage: UIImage? = nil
    @State private var lastSnapshotHash: Int = 0
    
    // Simple cache to avoid redundant snapshotting for the same territory set
    private static var snapshotCache = NSCache<NSString, UIImage>()
    
    var body: some View {
        ZStack {
            if let image = snapshotImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .overlay(ProgressView().scaleEffect(0.8))
            }
        }
        .task {
            await generateSnapshot()
        }
        .onChange(of: territories) { oldVal, newVal in
            Task { await generateSnapshot() }
        }
    }
    
    private func generateSnapshot() async {
        guard !territories.isEmpty else { return }
        
        let hash = territories.map { $0.id }.sorted().joined().hashValue
        if lastSnapshotHash == hash && snapshotImage != nil { return }
        
        // Check cache
        let cacheKey = "\(hash)" as NSString
        if let cached = Self.snapshotCache.object(forKey: cacheKey) {
            self.snapshotImage = cached
            self.lastSnapshotHash = hash
            return
        }

        // Calculate region
        let coords = territories.map { $0.centerCoordinate }
        let minLat = coords.map { $0.latitude }.min() ?? 0
        let maxLat = coords.map { $0.latitude }.max() ?? 0
        let minLon = coords.map { $0.longitude }.min() ?? 0
        let maxLon = coords.map { $0.longitude }.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.012, (maxLat - minLat) * 3.5),
            longitudeDelta: max(0.012, (maxLon - minLon) * 3.5)
        )
        
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: center, span: span)
        options.size = CGSize(width: 400, height: 320)
        options.scale = UIScreen.main.scale
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        
        if #available(iOS 17.0, *) {
            let config = MKStandardMapConfiguration(elevationStyle: .flat)
            config.pointOfInterestFilter = .excludingAll
            options.preferredConfiguration = config
        } else {
            options.mapType = .standard
            options.pointOfInterestFilter = .excludingAll
        }
        
        let snapshotter = MKMapSnapshotter(options: options)
        
        do {
            let snapshot = try await snapshotter.start()
            let finalImage = drawPolygons(on: snapshot)
            
            await MainActor.run {
                self.snapshotImage = finalImage
                self.lastSnapshotHash = hash
                Self.snapshotCache.setObject(finalImage, forKey: cacheKey)
            }
        } catch {
            print("❌ Error generating map snapshot: \(error)")
        }
    }
    
    private func drawPolygons(on snapshot: MKMapSnapshotter.Snapshot) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(snapshot.image.size, true, snapshot.image.scale)
        snapshot.image.draw(at: .zero)
        
        guard let context = UIGraphicsGetCurrentContext() else { return snapshot.image }
        
        context.setLineWidth(1.5)
        let uiColor = UIColor(tintColor)
        context.setStrokeColor(uiColor.cgColor)
        context.setFillColor(uiColor.withAlphaComponent(0.4).cgColor)
        
        for cell in territories {
            let points = cell.boundary.map { snapshot.point(for: $0.coordinate) }
            guard points.count >= 3 else { continue }
            
            context.beginPath()
            context.move(to: points[0])
            for i in 1..<points.count {
                context.addLine(to: points[i])
            }
            context.closePath()
            context.drawPath(using: .fillStroke)
        }
        
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? snapshot.image
    }
}

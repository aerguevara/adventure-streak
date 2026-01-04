import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    @ObservedObject var viewModel: MapViewModel
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        
        // Use a simpler 2D configuration to avoid Metal multisample resolve issues on some devices
        if #available(iOS 15.0, *) {
            let config = MKStandardMapConfiguration(elevationStyle: .flat)
            mapView.preferredConfiguration = config
        }
        
        // Set initial region
        mapView.setRegion(viewModel.region, animated: false)
        
        // Auto-follow user only if not explicitly recentering to a territory
        if !viewModel.shouldRecenter {
            mapView.userTrackingMode = .follow
        }
        
        // Request permissions only when the map is actually shown
        viewModel.checkLocationPermissions()
        
        // Tap gesture to detect territory selection
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 1. Update Region
        // Only update if we explicitly want to force a move (e.g. "Focus User" button)
        if viewModel.shouldRecenter {
            mapView.userTrackingMode = .none // Stop following user to allow custom region move
            mapView.setRegion(viewModel.region, animated: true)
            // Reset flag async
            DispatchQueue.main.async {
                viewModel.shouldRecenter = false
            }
        }
        
        // 2. Smart Diffing for Local Territories (Green)
        updateTerritories(mapView: mapView, context: context)
        
        // 3. Smart Diffing for Rival Territories (Orange)
        updateRivals(mapView: mapView, context: context)
        
        // 4. Force refresh of icons if version changed
        if context.coordinator.lastIconVersion != viewModel.iconVersion {
            context.coordinator.lastIconVersion = viewModel.iconVersion
            refreshAllIcons(mapView: mapView)
        }
    }
    
    private func refreshAllIcons(mapView: MKMapView) {
        let annotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        for annotation in annotations {
            if let title = annotation.title as? String, title.hasSuffix("_icon") {
                if let view = mapView.view(for: annotation) {
                    let userId = annotation.subtitle as? String ?? ""
                    let icon = viewModel.userIcons[userId] ?? "🚩"
                    view.image = MapIconGenerator.shared.icon(for: icon, size: 22)
                }
            }
        }
    }
    
    private func updateTerritories(mapView: MKMapView, context: Context) {
        let currentIds = context.coordinator.renderedTerritoryIds
        let newTerritories = viewModel.visibleTerritories
        let newIds = Set(newTerritories.map { $0.id })
        
        // 1. Remove territories that are no longer visible
        let toRemoveIds = currentIds.subtracting(newIds)
        if !toRemoveIds.isEmpty {
            let overlaysToRemove = mapView.overlays.filter { overlay in
                guard let title = overlay.title, let id = title else { return false }
                return toRemoveIds.contains(id)
            }
            mapView.removeOverlays(overlaysToRemove)
        }
        
        // 2. Detect State Changes for Persisting Territories (Local <-> Expired)
        var staleIds = Set<String>()
        // Optimization: Create map for O(1) lookup
        let newTerritoryMap = Dictionary(uniqueKeysWithValues: newTerritories.map { ($0.id, $0) })
        
        for overlay in mapView.overlays {
            if let polygon = overlay as? MKPolygon,
               let id = polygon.title,
               let cell = newTerritoryMap[id] {
                
                let expectedSubtitle = cell.expiresAt < Date() ? "expired" : "local"
                // Only check overlays marked as territories (local/expired), ignore rivals for now
                if (polygon.subtitle == "local" || polygon.subtitle == "expired") && polygon.subtitle != expectedSubtitle {
                    staleIds.insert(id)
                }
            }
        }
        
        // Remove stale overlays to force redraw
        if !staleIds.isEmpty {
            let staleOverlays = mapView.overlays.filter { overlay in
                guard let title = overlay.title, let id = title else { return false }
                return staleIds.contains(id)
            }
            mapView.removeOverlays(staleOverlays)
        }
        
        // 3. Add New or Stale Territories
        // We add if it's new OR if it was stale (removed above)
        let toAddIds = newIds.subtracting(currentIds).union(staleIds)
        
        if !toAddIds.isEmpty {
            let territoriesToAdd = newTerritories.filter { toAddIds.contains($0.id) }
            let newOverlays = territoriesToAdd.compactMap { cell -> MKPolygon? in
                guard cell.boundary.count >= 3 else { return nil }
                let coords = cell.boundary.map { $0.coordinate }
                
                let polygon = MKPolygon(coordinates: coords, count: coords.count)
                polygon.title = cell.id // ID stored in title
                
                // Check for expiration
                if cell.expiresAt < Date() {
                    polygon.subtitle = "expired"
                } else {
                    polygon.subtitle = "local"
                }
                return polygon
            }
            mapView.addOverlays(newOverlays)
        }
        
        context.coordinator.renderedTerritoryIds = newIds
        
        // Update Local Icons
        updateLocalAnnotations(mapView: mapView, context: context)
    }
    
    private func updateLocalAnnotations(mapView: MKMapView, context: Context) {
        let currentIds = context.coordinator.renderedLocalIconIds
        let newTerritories = viewModel.visibleTerritories
        let newIds = Set(newTerritories.map { $0.id + "_icon" })
        
        let toRemoveIds = currentIds.subtracting(newIds)
        let toAddIds = newIds.subtracting(currentIds)
        
        if !toRemoveIds.isEmpty {
            let annotationsToRemove = mapView.annotations.filter { annotation in
                guard let title = annotation.title, let id = title else { return false }
                return toRemoveIds.contains(id)
            }
            mapView.removeAnnotations(annotationsToRemove)
        }
        
        if !toAddIds.isEmpty {
            let auth = AuthenticationService.shared
            let territoriesToAdd = newTerritories.filter { toAddIds.contains($0.id + "_icon") }
            let newAnnotations = territoriesToAdd.map { cell -> MKPointAnnotation in
                let annotation = MKPointAnnotation()
                annotation.coordinate = cell.centerCoordinate
                annotation.title = cell.id + "_icon"
                annotation.subtitle = cell.ownerUserId ?? auth.userId
                return annotation
            }
            mapView.addAnnotations(newAnnotations)
        }
        
        context.coordinator.renderedLocalIconIds = newIds
    }
    
    private func updateRivals(mapView: MKMapView, context: Context) {
        let currentIds = context.coordinator.renderedRivalIds
        let newRivals = viewModel.otherTerritories
        let newIds = Set(newRivals.map { $0.id ?? "" })
        
        let toRemoveIds = currentIds.subtracting(newIds)
        let toAddIds = newIds.subtracting(currentIds)
        
        if !toRemoveIds.isEmpty {
            let overlaysToRemove = mapView.overlays.filter { overlay in
                guard let title = overlay.title, let id = title else { return false }
                return toRemoveIds.contains(id)
            }
            mapView.removeOverlays(overlaysToRemove)
        }
        
        if !toAddIds.isEmpty {
            let rivalsToAdd = newRivals.filter { toAddIds.contains($0.id ?? "") }
            let newOverlays = rivalsToAdd.compactMap { territory -> MKPolygon? in
                guard territory.boundary.count >= 3 else { return nil }
                let coords = territory.boundary.map { $0.coordinate }
                
                // Ensure closure - REVERTED
                
                let polygon = MKPolygon(coordinates: coords, count: coords.count)
                polygon.title = territory.id // ID stored in title
                polygon.subtitle = "rival" // Tag as rival
                return polygon
            }
            mapView.addOverlays(newOverlays)
        }
        
        
        context.coordinator.renderedRivalIds = newIds
        
        // 3. Update Rival Annotations (Icons)
        updateRivalAnnotations(mapView: mapView, context: context)
    }
    
    private func updateRivalAnnotations(mapView: MKMapView, context: Context) {
        let currentIds = context.coordinator.renderedRivalIconIds
        let newRivals = viewModel.otherTerritories
        let newIds = Set(newRivals.map { ($0.id ?? "") + "_icon" })
        
        let toRemoveIds = currentIds.subtracting(newIds)
        let toAddIds = newIds.subtracting(currentIds)
        
        if !toRemoveIds.isEmpty {
            let annotationsToRemove = mapView.annotations.filter { annotation in
                guard let title = annotation.title, let id = title else { return false }
                return toRemoveIds.contains(id)
            }
            mapView.removeAnnotations(annotationsToRemove)
        }
        
        if !toAddIds.isEmpty {
            let rivalsToAdd = newRivals.filter { toAddIds.contains(($0.id ?? "") + "_icon") }
            let newAnnotations = rivalsToAdd.map { territory -> MKPointAnnotation in
                let annotation = MKPointAnnotation()
                annotation.coordinate = territory.centerCoordinate
                annotation.title = (territory.id ?? "") + "_icon"
                annotation.subtitle = territory.userId // Store userId in subtitle for icon lookup
                return annotation
            }
            mapView.addAnnotations(newAnnotations)
        }
        
        context.coordinator.renderedRivalIconIds = newIds
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        var renderedTerritoryIds: Set<String> = []
        var renderedLocalIconIds: Set<String> = []
        var renderedRivalIds: Set<String> = []
        var renderedRivalIconIds: Set<String> = []
        var lastIconVersion: Int = 0
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            let mapPoint = MKMapPoint(coordinate)
            
            for overlay in mapView.overlays {
                guard let polygon = overlay as? MKPolygon,
                      let renderer = mapView.renderer(for: polygon) as? MKPolygonRenderer else { continue }
                
                let polygonPoint = renderer.point(for: mapPoint)
                if renderer.path.contains(polygonPoint) {
                    let id = polygon.title ?? ""
                    // Owner lookup: local store first, then rivals
                    var ownerName: String? = nil
                    var ownerId: String? = nil
                    if let cell = parent.viewModel.territoryStore.conqueredCells[id] {
                        let auth = AuthenticationService.shared
                        ownerId = cell.ownerUserId ?? auth.userId
                        ownerName = cell.ownerDisplayName
                            ?? (ownerId == auth.userId ? auth.resolvedUserName() : cell.ownerUserId)
                    } else if let rival = parent.viewModel.otherTerritories.first(where: { $0.id == id }) {
                        ownerName = nil // evitamos mostrar el id mientras llega el perfil remoto
                        ownerId = rival.userId
                    }
                    parent.viewModel.selectTerritory(id: id, ownerName: ownerName, ownerUserId: ownerId)
                    break
                }
            }
            
            // If no overlay matched, clear selection
            if parent.viewModel.selectedTerritoryId == nil {
                parent.viewModel.selectTerritory(id: nil, ownerName: nil, ownerUserId: nil)
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                
                let id = polygon.title ?? ""
                
                if polygon.subtitle == "rival" {
                    // Check for "Aura Dorada" (Target > 15 days)
                    let firstConq = parent.viewModel.otherTerritories.first(where: { $0.id == id })?.firstConqueredAt
                    let isAncient = firstConq.map { Date().timeIntervalSince($0) > 15 * 24 * 3600 } ?? false
                    
                    if isAncient {
                        renderer.strokeColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Gold
                        renderer.fillColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.4)
                        renderer.lineWidth = 3
                    } else {
                        renderer.strokeColor = .orange
                        renderer.fillColor = UIColor.orange.withAlphaComponent(0.3)
                        renderer.lineWidth = 1
                    }
                } else if polygon.subtitle == "expired" {
                    renderer.strokeColor = .gray
                    renderer.fillColor = UIColor.gray.withAlphaComponent(0.4)
                    renderer.lineWidth = 1
                } else {
                    // Local / Defended
                    let cell = parent.viewModel.territoryStore.conqueredCells[id]
                    let defenseCount = cell?.defenseCount ?? 0
                    
                    renderer.strokeColor = .green
                    renderer.fillColor = UIColor.green.withAlphaComponent(0.5)
                    
                    // Visual "Wall" reinforcement based on defenses
                    renderer.lineWidth = CGFloat(1 + min(defenseCount, 4))
                }
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Defer published state changes to avoid modifying state during view updates
            DispatchQueue.main.async {
                self.parent.viewModel.updateVisibleRegion(mapView.region)
            }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            // Handle Individual Rival Icons
            let identifier = "RivalIcon"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
                // Disable clustering to show all icons individually as requested
                annotationView?.clusteringIdentifier = nil 
                annotationView?.displayPriority = .required
            } else {
                annotationView?.annotation = annotation
            }
            
            if let title = annotation.title as? String, title.hasSuffix("_icon") {
                let userId = annotation.subtitle as? String ?? ""
                let icon = parent.viewModel.userIcons[userId] ?? "🚩"
                
                // Clear any existing subviews
                annotationView?.subviews.forEach { $0.removeFromSuperview() }
                
                // Use rasterized image
                annotationView?.image = MapIconGenerator.shared.icon(for: icon, size: 22)
            }
            
            return annotationView
        }
    }
}

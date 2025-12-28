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
        
        // Auto-follow user
        mapView.userTrackingMode = .follow
        
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
            mapView.setRegion(viewModel.region, animated: true)
            // Reset flag async
            DispatchQueue.main.async {
                viewModel.shouldRecenter = false
            }
        }
        
        // 2. Smart Diffing for Local Territories (Green)
        updateTerritories(mapView: mapView, context: context)
        
        // 2. Smart Diffing for Rival Territories (Orange)
        updateRivals(mapView: mapView, context: context)
    }
    
    private func updateTerritories(mapView: MKMapView, context: Context) {
        let currentIds = context.coordinator.renderedTerritoryIds
        let newTerritories = viewModel.visibleTerritories
        let newIds = Set(newTerritories.map { $0.id })
        
        print("DEBUG: MapView updating territories. Current: \(currentIds.count), New: \(newIds.count)")
        
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
            let territoriesToAdd = newTerritories.filter { toAddIds.contains($0.id) }
            let newOverlays = territoriesToAdd.compactMap { cell -> MKPolygon? in
                guard cell.boundary.count >= 3 else { return nil }
                var coords = cell.boundary.map { $0.coordinate }
                
                // Ensure closure - REVERTED
                
                let polygon = MKPolygon(coordinates: coords, count: coords.count)
                polygon.title = cell.id // ID stored in title
                polygon.subtitle = "local" // Tag as local
                return polygon
            }
            mapView.addOverlays(newOverlays)
        }
        
        context.coordinator.renderedTerritoryIds = newIds
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
                var coords = territory.boundary.map { $0.coordinate }
                
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
        var renderedRivalIds: Set<String> = []
        var renderedRivalIconIds: Set<String> = []
        
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
                
                if polygon.subtitle == "rival" {
                    renderer.strokeColor = .orange
                    renderer.fillColor = UIColor.orange.withAlphaComponent(0.3)
                } else {
                    renderer.strokeColor = .green
                    renderer.fillColor = UIColor.green.withAlphaComponent(0.5)
                }
                renderer.lineWidth = 1
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

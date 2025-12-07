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
                let coords = cell.boundary.map { $0.coordinate }
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
                let coords = territory.boundary.map { $0.coordinate }
                let polygon = MKPolygon(coordinates: coords, count: coords.count)
                polygon.title = territory.id // ID stored in title
                polygon.subtitle = "rival" // Tag as rival
                return polygon
            }
            mapView.addOverlays(newOverlays)
        }
        
        context.coordinator.renderedRivalIds = newIds
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        var renderedTerritoryIds: Set<String> = []
        var renderedRivalIds: Set<String> = []
        
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
                        ownerName = cell.ownerDisplayName ?? cell.ownerUserId
                        ownerId = cell.ownerUserId
                    } else if let rival = parent.viewModel.otherTerritories.first(where: { $0.id == id }) {
                        ownerName = rival.userId
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
            parent.viewModel.updateVisibleRegion(mapView.region)
            parent.viewModel.selectTerritory(id: nil, ownerName: nil, ownerUserId: nil)
        }
    }
}

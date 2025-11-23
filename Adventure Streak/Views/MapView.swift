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
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 1. Update Region
        // Since MapViewModel only updates region ONCE (initial location), it is safe to update here without fighting user.
        let currentRegion = mapView.region
        let targetRegion = viewModel.region
        
        // Only update if significantly different (to avoid minor floating point loops)
        if abs(currentRegion.center.latitude - targetRegion.center.latitude) > 0.0001 ||
           abs(currentRegion.center.longitude - targetRegion.center.longitude) > 0.0001 {
            mapView.setRegion(viewModel.region, animated: true)
        }
        
        // 1. Smart Diffing for Local Territories (Green)
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
        }
    }
}

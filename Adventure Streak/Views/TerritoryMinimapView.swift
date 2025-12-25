import SwiftUI
import MapKit

struct TerritoryMinimapView: UIViewRepresentable {
    let territories: [TerritoryCell]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isUserInteractionEnabled = false
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        
        if #available(iOS 15.0, *) {
            mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
        }
        
        updateOverlays(mapView)
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        updateOverlays(uiView)
    }
    
    private func updateOverlays(_ mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)
        
        let overlays = territories.compactMap { cell -> MKPolygon? in
            guard cell.boundary.count >= 3 else { return nil }
            let coords = cell.boundary.map { $0.coordinate }
            return MKPolygon(coordinates: coords, count: coords.count)
        }
        
        mapView.addOverlays(overlays)
        
        if !territories.isEmpty {
            // Calculate a region that covers all territories
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
                latitudeDelta: max(0.015, (maxLat - minLat) * 3.0),
                longitudeDelta: max(0.015, (maxLon - minLon) * 3.0)
            )
            
            let region = MKCoordinateRegion(center: center, span: span)
            mapView.setRegion(region, animated: false)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.green.withAlphaComponent(0.6)
                renderer.strokeColor = .green
                renderer.lineWidth = 1
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}


import SwiftUI
import MapKit
import FirebaseStorage

struct StolenTerritoriesModal: View {
    let items: [TerritoryInventoryItem]
    let onDismiss: () -> Void
    
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedItem: TerritoryInventoryItem?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Cabecera Premium
                headerSection
                
                // Mapa de la zona robada
                mapSection
                    .frame(height: 300)
                    .cornerRadius(24)
                    .padding()
                
                // Lista de robos
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(items) { item in
                            StolenItemRow(item: item, isSelected: selectedItem?.id == item.id)
                                .onTapGesture {
                                    withAnimation {
                                        selectedItem = item
                                        updateCamera(for: item)
                                    }
                                }
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                // Botón de acción
                Button(action: onDismiss) {
                    Text("Entendido, iré a por ellos")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(16)
                        .shadow(color: .red.opacity(0.4), radius: 10, y: 5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            if let first = items.first {
                selectedItem = first
                updateCamera(for: first)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(.trailing, 20)
                .padding(.top, 20)
            }
            
            Image(systemName: "bolt.shield.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
                .shadow(color: .red.opacity(0.5), radius: 10)
            
            Text("¡TERRITORIO BAJO ATAQUE!")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(.white)
            
            Text("Han robado algunas de tus conquistas mientras no estabas.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 10)
    }
    
    private var mapSection: some View {
        Map(position: $position) {
            ForEach(items) { item in
                ForEach(item.territories) { cell in
                    let coords = cell.boundary.map { $0.coordinate }
                    if coords.count >= 3 {
                        MapPolygon(coordinates: coords)
                            .stroke(.red, lineWidth: 2)
                            .foregroundStyle(.red.opacity(0.4))
                    }
                }
            }
        }
        .mapStyle(.standard(emphasis: .muted))
    }
    
    private func updateCamera(for item: TerritoryInventoryItem) {
        let allCoords = item.territories.flatMap { $0.boundary.map { $0.coordinate } }
        guard !allCoords.isEmpty else { return }
        
        let lats = allCoords.map { $0.latitude }
        let lons = allCoords.map { $0.longitude }
        
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLon = lons.min()!
        let maxLon = lons.max()!
        
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2.0,
                                            longitude: (minLon + maxLon) / 2.0)
        let latDelta = (maxLat - minLat) * 2.5
        let lonDelta = (maxLon - minLon) * 2.5
        
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: max(0.005, latDelta), longitudeDelta: max(0.005, lonDelta)))
        
        withAnimation {
            position = .region(region)
        }
    }
}

struct StolenItemRow: View {
    let item: TerritoryInventoryItem
    let isSelected: Bool
    
    @State private var avatarData: Data?
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar del ladrón real
            ZStack {
                if let data = avatarData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "person.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            .task {
                await loadAvatar()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.thieveryData?.thiefName ?? "Alguien")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(item.locationLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let stolenAt = item.thieveryData?.stolenAt {
                    Text(stolenAt.timeAgo())
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.8))
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("-\(item.territories.count)")
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundColor(.red)
                Text("CELDAS")
                    .font(.system(size: 8).bold())
                    .foregroundColor(.red.opacity(0.6))
            }
        }
        .padding()
        .background(isSelected ? Color.red.opacity(0.1) : Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
    
    private func loadAvatar() async {
        guard let thiefId = item.thieveryData?.thiefId else { return }
        
        // 1. Try cache
        if let cached = AvatarCacheManager.shared.data(for: thiefId) {
            self.avatarData = cached
            return
        }
        
        // 2. Fetch from Storage
        let storageRef = Storage.storage().reference().child("users/\(thiefId)/avatar.jpg")
        do {
            let url = try await storageRef.downloadURL()
            let (data, _) = try await URLSession.shared.data(from: url)
            await MainActor.run {
                self.avatarData = data
                AvatarCacheManager.shared.save(data: data, for: thiefId)
            }
        } catch {
            // Normal fallback if user has no avatar
        }
    }
}

fileprivate extension Date {
    func timeAgo() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "es")
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#if DEBUG
struct StolenTerritoriesModal_Previews: PreviewProvider {
    static var previews: some View {
        StolenTerritoriesModal(items: [], onDismiss: {})
    }
}
#endif

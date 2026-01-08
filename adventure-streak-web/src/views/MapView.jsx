import React, { useState, useEffect } from 'react';
import { MapContainer, TileLayer, Polygon, Popup, useMap } from 'react-leaflet';
import { db } from '../firebase';
import { collection, query, limit, getDocs } from "firebase/firestore";
import 'leaflet/dist/leaflet.css';

// Fix for default Leaflet markers in React
// import L from 'leaflet';
// import icon from 'leaflet/dist/images/marker-icon.png';
// import iconShadow from 'leaflet/dist/images/marker-shadow.png';
// let DefaultIcon = L.icon({
//     iconUrl: icon,
//     shadowUrl: iconShadow,
//     iconSize: [25, 41],
//     iconAnchor: [12, 41]
// });
// L.Marker.prototype.options.icon = DefaultIcon;

const TerritoryMap = () => {
    const [territories, setTerritories] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const fetchTerritories = async () => {
            try {
                // For MVP: Fetching a limited set of territories to avoid overload
                // Ideally this would be filtered by the logged-in user or a viewport
                const q = query(
                    collection(db, "remote_territories"),
                    limit(500) // Safety limit
                );

                const querySnapshot = await getDocs(q);
                const fetchedTerritories = [];

                querySnapshot.forEach((doc) => {
                    const data = doc.data();
                    if (data.boundary) {
                        fetchedTerritories.push({
                            id: doc.id,
                            boundary: data.boundary.map(p => [p.latitude, p.longitude]),
                            center: [data.centerLatitude, data.centerLongitude],
                            ownerId: data.userId,
                            level: data.level || 1
                        });
                    }
                });

                setTerritories(fetchedTerritories);
            } catch (error) {
                console.error("Error fetching territories:", error);
            } finally {
                setLoading(false);
            }
        };

        fetchTerritories();
    }, []);

    // Component to center map on the densest cluster of territories
    const MapRecenter = ({ territories }) => {
        const map = useMap();

        useEffect(() => {
            if (territories.length > 0) {
                // Find the territory with the most neighbors within ~5km (0.05 degrees)
                let maxNeighbors = -1;
                let bestCenter = territories[0].center;
                const radius = 0.05;

                // Simple O(N^2) check - acceptable for N=500
                for (let i = 0; i < territories.length; i++) {
                    const current = territories[i];
                    let neighbors = 0;

                    for (let j = 0; j < territories.length; j++) {
                        if (i === j) continue;
                        const target = territories[j];
                        const dLat = Math.abs(current.center[0] - target.center[0]);
                        const dLng = Math.abs(current.center[1] - target.center[1]);

                        if (dLat < radius && dLng < radius) {
                            neighbors++;
                        }
                    }

                    if (neighbors > maxNeighbors) {
                        maxNeighbors = neighbors;
                        bestCenter = current.center;
                    }
                }

                map.setView(bestCenter, 14);
            }
        }, [territories, map]);
        return null;
    };

    return (
        <div className="h-screen w-full relative z-0">
            {loading && (
                <div className="absolute inset-0 flex items-center justify-center z-[1000] bg-adventure-dark/80 backdrop-blur-sm text-white">
                    <div className="text-center">
                        <div className="text-2xl animate-pulse mb-2">🗺️</div>
                        <div>Cargando el mundo...</div>
                    </div>
                </div>
            )}

            <MapContainer
                center={[40.4168, -3.7038]} // Default to Madrid
                zoom={13}
                style={{ height: '100%', width: '100%' }}
                className="z-0"
            >
                <TileLayer
                    attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>'
                    url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
                />

                {territories.map((t) => (
                    <Polygon
                        key={t.id}
                        positions={t.boundary}
                        pathOptions={{
                            color: '#ef4444', // Adventure Red
                            fillColor: '#ef4444',
                            fillOpacity: 0.7, // Higher density
                            stroke: false,
                        }}
                    >
                        <Popup className="text-black">
                            <strong>Territorio Conquistado</strong><br />
                            ID: {t.id}
                        </Popup>
                    </Polygon>
                ))}

                <MapRecenter territories={territories} />
            </MapContainer>

            <div className="absolute bottom-8 left-1/2 -translate-x-1/2 z-[400] glass-card px-6 py-3 rounded-full flex items-center gap-3">
                <div className="w-3 h-3 rounded-full bg-adventure-blue"></div>
                <span className="text-sm font-bold text-white/80">Territorios Activos ({territories.length})</span>
            </div>
        </div >
    );
};

export default TerritoryMap;

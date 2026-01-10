import React, { useState, useEffect, useRef } from 'react';
import { MapContainer, TileLayer, Polygon, Circle, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

// Componente auxiliar para forzar el re-render del mapa
function MapRefresher() {
    const map = useMap();
    useEffect(() => {
        setTimeout(() => {
            map.invalidateSize();
        }, 500);
    }, [map]);
    return null;
}

const MapSnippet = () => {
    // Coordenadas exactas en el centro de Madrid (Puerta del Sol y alrededores)
    // Aseguramos que el zoom 14 las capture perfectamente
    const redZones = [
        {
            id: 'zone1',
            center: [40.4168, -3.7038],
            radius: 200,
            path: [
                [40.4180, -3.7050],
                [40.4190, -3.7050],
                [40.4190, -3.7030],
                [40.4180, -3.7030]
            ]
        },
        {
            id: 'zone2',
            center: [40.4150, -3.7010],
            radius: 150,
            path: [
                [40.4140, -3.7020],
                [40.4160, -3.7020],
                [40.4160, -3.7000],
                [40.4140, -3.7000]
            ]
        }
    ];

    return (
        <div className="w-full h-[400px] md:h-[500px] rounded-2xl overflow-hidden border border-white/10 shadow-2xl relative mb-4">
            <style dangerouslySetInnerHTML={{
                __html: `
                .leaflet-container { background: #0b0f1a !important; }
                .leaflet-v-layer { z-index: 1000 !important; }
            `}} />

            <MapContainer
                center={[40.4168, -3.7038]}
                zoom={14}
                style={{ height: '100%', width: '100%' }}
                zoomControl={false}
                attributionControl={false}
                scrollWheelZoom={false}
                dragging={false}
            >
                <TileLayer
                    url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
                />

                <MapRefresher />

                {redZones.map((zone) => (
                    <React.Fragment key={zone.id}>
                        {/* Dibujamos un círculo y un polígono para asegurar que al menos uno se vea */}
                        <Circle
                            center={zone.center}
                            radius={zone.radius}
                            pathOptions={{
                                color: '#ff0000',
                                fillColor: '#ff0000',
                                fillOpacity: 0.8,
                                weight: 3
                            }}
                        />
                        <Polygon
                            positions={zone.path}
                            pathOptions={{
                                color: '#ff0000',
                                fillColor: '#ff0000',
                                fillOpacity: 0.4,
                                weight: 2
                            }}
                        />
                    </React.Fragment>
                ))}
            </MapContainer>

            {/* Overlay estético */}
            <div className="absolute inset-0 z-[1001] bg-gradient-to-t from-black/40 to-transparent pointer-events-none"></div>

            <div className="absolute top-4 right-4 z-[1002] bg-red-600/90 backdrop-blur-md px-3 py-1.5 rounded-full border border-white/20 flex items-center gap-2 shadow-lg">
                <span className="relative flex h-2 w-2">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-white opacity-75"></span>
                    <span className="relative inline-flex rounded-full h-2 w-2 bg-white"></span>
                </span>
                <span className="text-[10px] font-bold uppercase tracking-widest text-white">Batalla en Vivo</span>
            </div>
        </div>
    );
};

export default MapSnippet;

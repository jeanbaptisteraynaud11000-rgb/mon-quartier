'use client';

import { MapContainer, TileLayer, GeoJSON, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

// Icône personnalisée (cercle corail) plutôt que le pin par défaut de
// Leaflet, dont les images cassent systématiquement avec les bundlers
// modernes (Webpack/Next) sans configuration supplémentaire.
const neighborIcon = L.divIcon({
  className: '',
  html: '<div style="width:16px;height:16px;border-radius:50%;background:#FF5A5F;border:2px solid white;box-shadow:0 1px 4px rgba(0,0,0,0.3);"></div>',
  iconSize: [16, 16],
  iconAnchor: [8, 8],
});

const boundaryStyle = {
  color: '#FF5A5F',
  weight: 2,
  fillColor: '#FF5A5F',
  fillOpacity: 0.05,
};

export default function NeighborhoodMap({ centerLat, centerLng, boundary, points }) {
  return (
    <MapContainer
      center={[centerLat, centerLng]}
      zoom={15}
      scrollWheelZoom={false}
      style={{ height: '280px', width: '100%', borderRadius: '1rem' }}
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />

      {boundary && <GeoJSON data={boundary} style={boundaryStyle} />}

      {points.map((point) => (
        <Marker key={point.user_id} position={[point.lat, point.lng]} icon={neighborIcon}>
          <Popup>{point.display_name || 'Voisin'}</Popup>
        </Marker>
      ))}
    </MapContainer>
  );
}


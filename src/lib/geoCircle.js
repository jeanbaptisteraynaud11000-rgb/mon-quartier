// Génère un polygone GeoJSON approximant un cercle de `radiusMeters` autour
// d'un point — utilisé pour dessiner le périmètre ajustable sur la carte
// (MapLibre n'a pas de primitive "cercle géographique" native).

export function createCircleGeoJSON(centerLat, centerLng, radiusMeters, points = 64) {
  const coords = [];
  const earthRadius = 6371000; // mètres

  for (let i = 0; i <= points; i++) {
    const angle = (i / points) * 2 * Math.PI;
    const dx = radiusMeters * Math.cos(angle);
    const dy = radiusMeters * Math.sin(angle);

    const dLat = dy / earthRadius;
    const dLng = dx / (earthRadius * Math.cos((centerLat * Math.PI) / 180));

    const lat = centerLat + (dLat * 180) / Math.PI;
    const lng = centerLng + (dLng * 180) / Math.PI;

    coords.push([lng, lat]);
  }

  return {
    type: 'Feature',
    geometry: { type: 'Polygon', coordinates: [coords] },
    properties: {},
  };
}


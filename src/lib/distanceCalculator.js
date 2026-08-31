// Calcul de distance entre deux points GPS (formule de Haversine).
// Utilisé pour trier les commerces par proximité — à partir de la
// géolocalisation LIVE du navigateur (jamais stockée), pas des coordonnées
// de résidence de l'utilisateur qu'on ne conserve plus.

export function calculateDistance(lat1, lon1, lat2, lon2) {
  if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
    return Infinity;
  }
  const R = 6371; // rayon de la Terre en km
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRadians(degrees) {
  return degrees * (Math.PI / 180);
}

export function formatDistance(distanceKm) {
  if (!isFinite(distanceKm)) return null;
  if (distanceKm < 0.1) return 'À proximité';
  if (distanceKm < 1) return `${Math.round(distanceKm * 1000)} m`;
  return `${distanceKm.toFixed(1)} km`;
}

// Trie une liste d'éléments {lat, lng, ...} par distance croissante à
// partir d'une position donnée. Les éléments sans coordonnées passent en
// dernier plutôt que d'être exclus.
export function sortByDistance(items, userLat, userLng) {
  if (userLat == null || userLng == null) return items;
  return [...items]
    .map((item) => ({ ...item, _distance: calculateDistance(userLat, userLng, item.lat, item.lng) }))
    .sort((a, b) => a._distance - b._distance);
}


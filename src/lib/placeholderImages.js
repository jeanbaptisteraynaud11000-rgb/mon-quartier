// Illustration générique affichée automatiquement quand une annonce ou une
// activité n'a pas de vraie photo — évite les cases vides.
//
// Les 5 catégories d'annonces (don, entraide, covoiturage, cherche, alerte)
// utilisent de vraies photos fournies (JPEG) ; les catégories d'activités
// et de commerces utilisent des illustrations vectorielles simples (PNG).

const JPEG_TYPES = new Set(['don', 'entraide', 'covoiturage', 'cherche', 'alerte']);

export function getPlaceholderImage(type) {
  const ext = JPEG_TYPES.has(type) ? 'jpg' : 'png';
  return `/placeholders/${type}.${ext}`;
}


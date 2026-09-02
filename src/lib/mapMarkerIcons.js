// Génère une image (ImageData) pour un marqueur de carte : cercle coloré +
// emoji centré. Dessiné sur un <canvas> local, donc aucune dépendance à une
// police externe/glyphes serveur — contourne complètement le bug de
// glyphes rencontré avec les couches "symbol" à texte MapLibre classiques.

export function createEmojiMarkerImage(emoji, bgColor, size = 64) {
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d');

  // Cercle de fond avec léger contour blanc.
  ctx.beginPath();
  ctx.arc(size / 2, size / 2, size / 2 - 3, 0, Math.PI * 2);
  ctx.fillStyle = bgColor;
  ctx.fill();
  ctx.lineWidth = 3;
  ctx.strokeStyle = '#FFFFFF';
  ctx.stroke();

  // Emoji centré (le rendu de police système gère nativement les emoji
  // dans un <canvas>, contrairement aux couches de texte MapLibre).
  ctx.font = `${Math.round(size * 0.5)}px sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(emoji, size / 2, size / 2 + 2);

  return ctx.getImageData(0, 0, size, size);
}

export const CATEGORY_EMOJI = {
  // Annonces
  don: { emoji: '🎁', color: '#FF5A5F' },
  entraide: { emoji: '🤝', color: '#00A699' },
  covoiturage: { emoji: '🚗', color: '#FF5A5F' },
  cherche: { emoji: '🔍', color: '#00A699' },
  achat_groupe: { emoji: '🛒', color: '#00A699' },
  alerte: { emoji: '⚠️', color: '#DC2626' },
  // Activités
  sortie: { emoji: '📍', color: '#8B5CF6' },
  musee: { emoji: '🏛️', color: '#8B5CF6' },
  sport: { emoji: '🏃', color: '#8B5CF6' },
  jeux_de_societe: { emoji: '🎲', color: '#8B5CF6' },
  // Commerces (les catégories "autre" et "sortie"/"jeux_de_societe" ne se
  // chevauchent pas dans les données réelles car kind différencie déjà
  // annonces/activités/commerces en amont).
  commerce: { emoji: '🛍️', color: '#475569' },
  restaurant: { emoji: '🍽️', color: '#475569' },
  sante: { emoji: '💊', color: '#475569' },
  loisirs: { emoji: '🎨', color: '#475569' },
  service: { emoji: '🔧', color: '#475569' },
  site_touristique: { emoji: '🏛️', color: '#475569' },
  autre: { emoji: '✨', color: '#94A3B8' },
};


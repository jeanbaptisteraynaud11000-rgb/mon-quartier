// Illustration générique affichée automatiquement quand une annonce ou une
// activité n'a pas de vraie photo — évite les cases vides.

export function getPlaceholderImage(type) {
  return `/placeholders/${type}.png`;
}


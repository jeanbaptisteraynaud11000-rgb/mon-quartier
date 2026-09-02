// Constantes partagées entre /annonces, /new et /annonces/[id] pour garder
// les libellés et emojis cohérents partout dans l'app.

import { Gift, Handshake, Car, Search, AlertTriangle, ShoppingCart } from 'lucide-react';

export const POST_TYPES = [
  { type: 'don', label: 'Prêt / Don', icon: Gift },
  { type: 'entraide', label: 'Entraide', icon: Handshake },
  { type: 'covoiturage', label: 'Covoiturage', icon: Car },
  { type: 'cherche', label: 'Je cherche', icon: Search },
  { type: 'achat_groupe', label: 'Achat groupé', icon: ShoppingCart },
  { type: 'alerte', label: 'Alerte quartier', icon: AlertTriangle },
];

export function getPostTypeInfo(type) {
  return POST_TYPES.find((t) => t.type === type) || { label: type, icon: Search };
}

// Formatage relatif simple en français, sans dépendance externe.
export function formatRelativeTime(dateString) {
  const date = new Date(dateString);
  const diffMs = Date.now() - date.getTime();
  const diffMin = Math.floor(diffMs / 60000);

  if (diffMin < 1) return "à l'instant";
  if (diffMin < 60) return `il y a ${diffMin} min`;
  const diffH = Math.floor(diffMin / 60);
  if (diffH < 24) return `il y a ${diffH} h`;
  const diffJ = Math.floor(diffH / 24);
  if (diffJ < 7) return `il y a ${diffJ} j`;
  return date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' });
}


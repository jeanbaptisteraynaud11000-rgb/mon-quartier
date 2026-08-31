import { MapPin, Landmark, Dumbbell, Dices, Sparkles } from 'lucide-react';

export const EVENT_CATEGORIES = [
  { category: 'sortie', label: 'Sortie', icon: MapPin },
  { category: 'musee', label: 'Musée / Culture', icon: Landmark },
  { category: 'sport', label: 'Sport', icon: Dumbbell },
  { category: 'jeux_de_societe', label: 'Jeux de société', icon: Dices },
  { category: 'autre', label: 'Autre', icon: Sparkles },
];

export function getEventCategoryInfo(category) {
  return EVENT_CATEGORIES.find((c) => c.category === category) || { label: category, icon: Sparkles };
}

export function formatEventDate(dateString) {
  const date = new Date(dateString);
  return date.toLocaleDateString('fr-FR', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
}


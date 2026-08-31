import { Store, UtensilsCrossed, Stethoscope, Palette, Wrench, Landmark, MoreHorizontal } from 'lucide-react';

export const PLACE_CATEGORIES = [
  { category: 'commerce', label: 'Commerce', icon: Store },
  { category: 'restaurant', label: 'Restauration', icon: UtensilsCrossed },
  { category: 'sante', label: 'Santé', icon: Stethoscope },
  { category: 'loisirs', label: 'Loisirs', icon: Palette },
  { category: 'service', label: 'Service', icon: Wrench },
  { category: 'site_touristique', label: 'Site touristique', icon: Landmark },
  { category: 'autre', label: 'Autre', icon: MoreHorizontal },
];

export function getPlaceCategoryInfo(category) {
  return PLACE_CATEGORIES.find((c) => c.category === category) || { label: category, icon: MoreHorizontal };
}


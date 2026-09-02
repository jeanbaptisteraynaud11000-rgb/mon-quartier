import { BadgeCheck } from 'lucide-react';

// Coche bleue affichée uniquement si verification_status === 'verified',
// lui-même branché sur la confirmation d'email réelle (migration 032) —
// jamais un badge décoratif sans donnée derrière.
export default function VerifiedBadge({ size = 13 }) {
  return (
    <BadgeCheck
      size={size}
      className="inline-block flex-shrink-0 fill-blue-500 text-white"
      aria-label="Compte vérifié"
    />
  );
}


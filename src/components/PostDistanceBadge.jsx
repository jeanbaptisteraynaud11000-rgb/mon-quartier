'use client';

import { useUserPosition } from '@/lib/useUserPosition';
import { calculateDistance, formatDistance } from '@/lib/distanceCalculator';

export default function PostDistanceBadge({ lat, lng }) {
  const userPosition = useUserPosition();

  if (!userPosition || lat == null || lng == null) return null;

  const distance = calculateDistance(userPosition.lat, userPosition.lng, lat, lng);
  const formatted = formatDistance(distance);
  if (!formatted) return null;

  return (
    <span className="absolute bottom-2 left-2 rounded-pill bg-white/90 px-2 py-0.5 text-[10px] font-medium text-content-primary shadow-soft">
      {formatted}
    </span>
  );
}


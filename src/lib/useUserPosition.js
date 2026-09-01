'use client';

import { useEffect, useState } from 'react';

// Cache au niveau module : si plusieurs cartes demandent la position en
// même temps (ex: une grille de 4 annonces), une seule vraie requête de
// géolocalisation est faite au navigateur, pas une par carte.
let cachedPosition = null;
let pendingRequest = null;

function requestPosition() {
  if (cachedPosition) return Promise.resolve(cachedPosition);
  if (pendingRequest) return pendingRequest;

  pendingRequest = new Promise((resolve) => {
    if (typeof navigator === 'undefined' || !navigator.geolocation) {
      resolve(null);
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        cachedPosition = { lat: pos.coords.latitude, lng: pos.coords.longitude };
        resolve(cachedPosition);
      },
      () => resolve(null),
      { timeout: 5000 }
    );
  });

  return pendingRequest;
}

export function useUserPosition() {
  const [position, setPosition] = useState(cachedPosition);

  useEffect(() => {
    let mounted = true;
    requestPosition().then((pos) => {
      if (mounted) setPosition(pos);
    });
    return () => {
      mounted = false;
    };
  }, []);

  return position;
}


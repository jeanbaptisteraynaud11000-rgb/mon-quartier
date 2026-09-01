'use client';

import { useEffect, useState } from 'react';

// Cache au niveau module : si plusieurs cartes demandent la position en
// même temps (ex: une grille de 4 annonces), une seule vraie requête de
// géolocalisation est faite au navigateur, pas une par carte.
let cachedPosition = null;
let cachedStatus = 'idle'; // idle | loading | granted | denied | unavailable | timeout
let pendingRequest = null;

function requestPosition() {
  if (cachedPosition) return Promise.resolve({ position: cachedPosition, status: 'granted' });
  if (pendingRequest) return pendingRequest;

  cachedStatus = 'loading';

  pendingRequest = new Promise((resolve) => {
    if (typeof navigator === 'undefined' || !navigator.geolocation) {
      cachedStatus = 'unavailable';
      resolve({ position: null, status: 'unavailable' });
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        cachedPosition = { lat: pos.coords.latitude, lng: pos.coords.longitude };
        cachedStatus = 'granted';
        resolve({ position: cachedPosition, status: 'granted' });
      },
      (err) => {
        cachedStatus = err.code === 1 ? 'denied' : err.code === 3 ? 'timeout' : 'unavailable';
        resolve({ position: null, status: cachedStatus });
      },
      { timeout: 8000 }
    );
  });

  return pendingRequest;
}

export function useUserPosition() {
  const [position, setPosition] = useState(cachedPosition);
  const [status, setStatus] = useState(cachedStatus);

  useEffect(() => {
    let mounted = true;
    setStatus((s) => (s === 'idle' ? 'loading' : s));
    requestPosition().then((result) => {
      if (!mounted) return;
      setPosition(result.position);
      setStatus(result.status);
    });
    return () => {
      mounted = false;
    };
  }, []);

  return position;
}

// Variante qui expose aussi le statut, utile pour afficher un message
// explicite (plutôt qu'un point bleu qui n'apparaît jamais sans
// explication).
export function useUserPositionWithStatus() {
  const [position, setPosition] = useState(cachedPosition);
  const [status, setStatus] = useState(cachedStatus);

  useEffect(() => {
    let mounted = true;
    setStatus((s) => (s === 'idle' ? 'loading' : s));
    requestPosition().then((result) => {
      if (!mounted) return;
      setPosition(result.position);
      setStatus(result.status);
    });
    return () => {
      mounted = false;
    };
  }, []);

  return { position, status };
}


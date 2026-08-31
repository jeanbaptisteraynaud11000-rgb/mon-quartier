'use client';

import { useEffect } from 'react';

export default function ServiceWorkerRegistration() {
  useEffect(() => {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('/sw.js').catch(() => {
        // Échec silencieux : l'app reste utilisable normalement en ligne,
        // seul le mode hors-ligne minimal ne sera pas disponible.
      });
    }
  }, []);

  return null;
}


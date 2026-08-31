// Service worker minimal : met en cache la page d'accueil et les assets
// statiques essentiels, pour qu'un minimum de l'app reste consultable hors
// connexion. Ce n'est PAS une stratégie offline complète (section 51 du
// prompt maître) — les données dynamiques (annonces, messages) nécessitent
// une vraie connexion, ce cache ne sert qu'à éviter un écran totalement
// blanc si le réseau coupe.

const CACHE_NAME = 'mon-quartier-v1';
const SHELL_URLS = ['/', '/offline'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(SHELL_URLS))
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  // Seules les requêtes de NAVIGATION (changement de page) ont un fallback
  // offline dédié. Les appels API Supabase passent toujours par le réseau.
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request).catch(() => caches.match('/offline'))
    );
  }
});


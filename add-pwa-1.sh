#!/usr/bin/env bash
set -e
echo "Ajout PWA (1/3) : manifest, icones, service worker..."

mkdir -p "public"
cat > "public/manifest.json" << 'MQEOF_PUBLIC_MANIFEST_JSON'
{
  "name": "Mon Quartier",
  "short_name": "Mon Quartier",
  "description": "L'application quotidienne de votre voisinage",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#FFFFFF",
  "theme_color": "#FF5A5F",
  "orientation": "portrait",
  "icons": [
    {
      "src": "/icons/icon-192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/icons/icon-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "any maskable"
    }
  ]
}

MQEOF_PUBLIC_MANIFEST_JSON

mkdir -p "public"
cat > "public/sw.js" << 'MQEOF_PUBLIC_SW_JS'
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

MQEOF_PUBLIC_SW_JS

mkdir -p "src/components"
cat > "src/components/ServiceWorkerRegistration.jsx" << 'MQEOF_SRC_COMPONENTS_SERVICEWORKERREGISTRATION_JSX'
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

MQEOF_SRC_COMPONENTS_SERVICEWORKERREGISTRATION_JSX

mkdir -p "src/app/offline"
cat > "src/app/offline/page.jsx" << 'MQEOF_SRC_APP_OFFLINE_PAGE_JSX'
export default function OfflinePage() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center p-6 text-center">
      <div className="text-4xl">📡</div>
      <h1 className="mt-4 text-xl font-semibold text-content-primary">
        Vous êtes hors connexion
      </h1>
      <p className="mt-2 text-sm text-content-secondary">
        Reconnecte-toi pour retrouver Mon Quartier. Rien de ce que tu ferais ici ne serait
        envoyé tant que la connexion n'est pas rétablie.
      </p>
    </div>
  );
}

MQEOF_SRC_APP_OFFLINE_PAGE_JSX

mkdir -p "src/app"
cat > "src/app/layout.jsx" << 'MQEOF_SRC_APP_LAYOUT_JSX'
import './globals.css';
import Header from '@/components/layout/Header';
import BottomNav from '@/components/layout/BottomNav';
import ServiceWorkerRegistration from '@/components/ServiceWorkerRegistration';

export const metadata = {
  title: 'Mon Quartier',
  description: "L'application quotidienne de votre voisinage : entraide, prêt, covoiturage et vie de quartier.",
  manifest: '/manifest.json',
  icons: {
    icon: '/icons/icon-192.png',
    apple: '/icons/icon-192.png',
  },
};

export const viewport = {
  themeColor: '#FFFFFF',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
};

export default function RootLayout({ children }) {
  return (
    <html lang="fr">
      <body className="font-sans text-content-primary">
        <ServiceWorkerRegistration />
        <Header />
        {/* pb-nav-h + marge : laisse la place à la nav basse fixe */}
        <main className="mx-auto min-h-screen max-w-lg pb-[calc(theme(spacing.nav-h)+1rem)]">
          {children}
        </main>
        <BottomNav />
      </body>
    </html>
  );
}

MQEOF_SRC_APP_LAYOUT_JSX

mkdir -p "src"
cat > "src/middleware.js" << 'MQEOF_SRC_MIDDLEWARE_JS'
// Middleware exécuté sur (presque) chaque requête.
//
// Rôle exact et volontairement limité pour ce chantier #3a :
//   1. rafraîchir la session Supabase (voir lib/supabase/middleware.js)
//   2. rediriger vers /login les visiteurs NON connectés qui tentent
//      d'accéder à une route protégée (avec ?next= pour revenir après login)
//   3. rediriger vers / les visiteurs DÉJÀ connectés qui vont sur /login
//      ou /register
//
// Ce que ce middleware NE fait PAS encore (viendra au chantier #3b / #4) :
//   - vérifier le statut de la demande d'adhésion (pending/approved)
//   - restreindre les fonctionnalités sensibles pour un compte "pending"
//     (recherche de voisins, messagerie...) — cette logique doit de toute
//     façon être également garantie par les policies RLS, jamais par le
//     seul middleware.

import { NextResponse } from 'next/server';
import { updateSession } from '@/lib/supabase/middleware';

const PUBLIC_ROUTE_PREFIXES = [
  '/login',
  '/register',
  '/forgot-password',
  '/reset-password',
  '/email-confirmation',
  '/auth',
  '/offline',
  '/confidentialite',
  '/cgu',
  '/mentions-legales',
  '/cookies',
];

function isPublicRoute(pathname) {
  return PUBLIC_ROUTE_PREFIXES.some((prefix) => pathname.startsWith(prefix));
}

export async function middleware(request) {
  const { supabaseResponse, user } = await updateSession(request);
  const { pathname } = request.nextUrl;

  if (!user && !isPublicRoute(pathname)) {
    const redirectUrl = new URL('/login', request.url);
    redirectUrl.searchParams.set('next', pathname);
    return NextResponse.redirect(redirectUrl);
  }

  if (user && (pathname.startsWith('/login') || pathname.startsWith('/register'))) {
    return NextResponse.redirect(new URL('/', request.url));
  }

  return supabaseResponse;
}

export const config = {
  matcher: [
    // Exclut les assets statiques et les images pour ne pas ralentir leur
    // chargement inutilement avec une vérification de session.
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
};

MQEOF_SRC_MIDDLEWARE_JS

mkdir -p "public/icons"
base64 -d > "public/icons/icon-192.png" << 'MQB64EOF_PUBLIC_ICONS_ICON-192_PNG'
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
MQB64EOF_PUBLIC_ICONS_ICON-192_PNG

mkdir -p "public/icons"
base64 -d > "public/icons/icon-512.png" << 'MQB64EOF_PUBLIC_ICONS_ICON-512_PNG'
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AABgFAEAAKMIAAAYRQAAwCgCAABGEQAAMIoAAIBRBAAAjCIAAGAUAQAAowgAABhFAADAKAIAAEYRAAAwigAAgFEEAACMIgAAYBQBAACjCAAAGEUAAMAoAgAARhEAADCKAACAUQQAAIwiAABgFAEAAKMIAAAYRQAAwCgCAABGEQAAMIoAAIBRBAAAjCIAAGAUAQAAowgAABhFAADAKAIAAEYRAAAwigAAgFEEAACMIgAAYBQBAACjCAAAGEUAAMAoAgAARhEAADCKAACAUQQAAIwiAABgFAEAAKMIAAAYRQAAwCgCAABGEQAAMIoAAIBRBAAAjCIAAGAUAQAAowgAABhFAADAKAIAAEYRAAAwigAAgFEEAACMIgAAYBQBAACjCAAAGEUAAMAoAgAARhEAADCKAACAUQQAAIwiAABgFAEAAKMIAAAYRQAAwCgCAABGEQAAMIoAAIBRBAAAjCIAAGAUAQAAowgAABhFAADAKAIAAEYRAAAwigAAgFEEAACMIgAAYBQBAACjCAAAGEUAAMAoAgAARhEAADCKAACAUQQAAIwiAABgFAEAAKMIAAAYRQAAwCgCAABGEQAAMIoAAIBRBAAAjCIAAGAUAQAAowgAABhFAADAKAIAAEYRAAAwigAAgFEEAACMIgAAYBQBAACjCAAAGEUAAMAoAgAARhEAADCKAACAUQQAAIwiAABgFAEAAKMIAAAYRQAAwKj/B4SZMb3c8IVDAAAAAElFTkSuQmCC
MQB64EOF_PUBLIC_ICONS_ICON-512_PNG

echo "PWA (1/3) ajoutee avec succes."
echo "npm run dev pour tester, puis on enchainera avec la suite."
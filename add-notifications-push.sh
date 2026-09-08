#!/usr/bin/env bash
set -e
echo "Notifications push : service worker + abonnement navigateur..."

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

// --- Notifications push --------------------------------------------------
// Reçoit le push envoyé par l'Edge Function Supabase et l'affiche comme
// notification système, même si Hoody n'est pas ouvert à ce moment-là.
self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch {
    data = { title: 'Hoody', body: event.data ? event.data.text() : '' };
  }

  const title = data.title || 'Hoody';
  const options = {
    body: data.body || '',
    icon: '/icons/icon-192.png',
    badge: '/icons/icon-192.png',
    data: { url: data.url || '/' },
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

// Clic sur la notification : ramène au premier plan un onglet Hoody déjà
// ouvert s'il y en a un, sinon en ouvre un nouveau sur la bonne page.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl = event.notification.data?.url || '/';

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ('focus' in client) {
          client.navigate(targetUrl);
          return client.focus();
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(targetUrl);
      }
    })
  );
});

MQEOF_PUBLIC_SW_JS

mkdir -p "src/lib"
cat > "src/lib/pushNotifications.js" << 'MQEOF_SRC_LIB_PUSHNOTIFICATIONS_JS'
// Clé publique VAPID — publique par nature (elle sert uniquement à ce que
// le navigateur identifie le bon service d'envoi), pas besoin de la garder
// secrète ni de la mettre en variable d'environnement séparée. La clé
// PRIVÉE, elle, ne vit jamais ici — uniquement dans les secrets de l'Edge
// Function Supabase.
export const VAPID_PUBLIC_KEY = 'BLxtj0dyHvizSYgp7Lve_W6XBnubiJE6W-uPgnG1tAJoeM3yAZJQ2KJoORFLO-kRe5O2rmgtvrP3jpSpwsc9xYk';

function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const rawData = window.atob(base64);
  return Uint8Array.from([...rawData].map((char) => char.charCodeAt(0)));
}

export function isPushSupported() {
  return typeof window !== 'undefined' && 'serviceWorker' in navigator && 'PushManager' in window;
}

export async function subscribeToPush(supabase, userId) {
  const permission = await Notification.requestPermission();
  if (permission !== 'granted') {
    throw new Error('permission_denied');
  }

  const registration = await navigator.serviceWorker.ready;

  let subscription = await registration.pushManager.getSubscription();
  if (!subscription) {
    subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY),
    });
  }

  const json = subscription.toJSON();

  const { error } = await supabase.from('push_subscriptions').upsert(
    {
      user_id: userId,
      endpoint: json.endpoint,
      p256dh: json.keys.p256dh,
      auth_key: json.keys.auth,
    },
    { onConflict: 'endpoint' }
  );

  if (error) throw error;
}

export async function unsubscribeFromPush(supabase) {
  const registration = await navigator.serviceWorker.ready;
  const subscription = await registration.pushManager.getSubscription();

  if (subscription) {
    await supabase.from('push_subscriptions').delete().eq('endpoint', subscription.endpoint);
    await subscription.unsubscribe();
  }
}

export async function getCurrentPushSubscription() {
  if (!isPushSupported()) return null;
  const registration = await navigator.serviceWorker.ready;
  return registration.pushManager.getSubscription();
}

MQEOF_SRC_LIB_PUSHNOTIFICATIONS_JS

mkdir -p "src/components"
cat > "src/components/PushNotificationToggle.jsx" << 'MQEOF_SRC_COMPONENTS_PUSHNOTIFICATIONTOGGLE_JSX'
'use client';

import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabaseClient';
import {
  isPushSupported,
  subscribeToPush,
  unsubscribeFromPush,
  getCurrentPushSubscription,
} from '@/lib/pushNotifications';

export default function PushNotificationToggle() {
  const [supported, setSupported] = useState(true);
  const [subscribed, setSubscribed] = useState(false);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    async function check() {
      if (!isPushSupported()) {
        setSupported(false);
        setLoading(false);
        return;
      }
      const sub = await getCurrentPushSubscription();
      setSubscribed(!!sub);
      setLoading(false);
    }
    check();
  }, []);

  async function handleToggle() {
    setBusy(true);
    setError('');

    try {
      if (subscribed) {
        await unsubscribeFromPush(supabase);
        setSubscribed(false);
      } else {
        const { data: { user } } = await supabase.auth.getUser();
        await subscribeToPush(supabase, user.id);
        setSubscribed(true);
      }
    } catch (err) {
      if (err.message === 'permission_denied') {
        setError("Autorisation refusée. Active les notifications pour ce site dans les réglages de ton navigateur.");
      } else {
        setError("Une erreur est survenue. Réessaie.");
      }
    } finally {
      setBusy(false);
    }
  }

  if (!supported) {
    return (
      <div className="rounded-card border border-border bg-surface-card p-4">
        <h2 className="text-sm font-semibold text-content-primary">Notifications push</h2>
        <p className="mt-1 text-xs text-content-secondary">
          Ton navigateur ne supporte pas les notifications push. Essaie depuis Chrome ou Safari
          récent, ou depuis l'app installée sur ton téléphone.
        </p>
      </div>
    );
  }

  return (
    <div className="rounded-card border border-border bg-surface-card p-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-sm font-semibold text-content-primary">Notifications push</h2>
          <p className="mt-0.5 text-xs text-content-secondary">
            Reçois une alerte même quand Hoody est fermé.
          </p>
        </div>
        <button
          onClick={handleToggle}
          disabled={loading || busy}
          role="switch"
          aria-checked={subscribed}
          className={`h-6 w-11 flex-shrink-0 rounded-pill transition-fast ${subscribed ? 'bg-vert' : 'bg-border'} disabled:opacity-60`}
        >
          <span
            className={`block h-5 w-5 translate-x-0.5 rounded-pill bg-white shadow-soft transition-fast ${
              subscribed ? 'translate-x-[22px]' : ''
            }`}
          />
        </button>
      </div>
      {error && <p className="mt-2 text-xs text-corail">{error}</p>}
    </div>
  );
}

MQEOF_SRC_COMPONENTS_PUSHNOTIFICATIONTOGGLE_JSX

mkdir -p "src/app/settings"
cat > "src/app/settings/page.jsx" << 'MQEOF_SRC_APP_SETTINGS_PAGE_JSX'
'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import PushNotificationToggle from '@/components/PushNotificationToggle';

export default function SettingsPage() {
  const router = useRouter();
  const [currentEmail, setCurrentEmail] = useState('');

  const [newEmail, setNewEmail] = useState('');
  const [emailSubmitting, setEmailSubmitting] = useState(false);
  const [emailError, setEmailError] = useState('');
  const [emailSuccess, setEmailSuccess] = useState('');

  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [passwordSubmitting, setPasswordSubmitting] = useState(false);
  const [passwordError, setPasswordError] = useState('');
  const [passwordSuccess, setPasswordSuccess] = useState('');

  useEffect(() => {
    async function load() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        router.push('/login');
        return;
      }
      setCurrentEmail(user.email || '');
    }
    load();
  }, [router]);

  async function handleEmailSubmit(e) {
    e.preventDefault();
    setEmailError('');
    setEmailSuccess('');

    if (!newEmail.trim() || newEmail === currentEmail) {
      setEmailError('Indique une nouvelle adresse email différente.');
      return;
    }

    setEmailSubmitting(true);
    const { error } = await supabase.auth.updateUser({ email: newEmail.trim() });
    setEmailSubmitting(false);

    if (error) {
      setEmailError("Impossible de changer l'email. Réessaie.");
      return;
    }

    setEmailSuccess('Vérifie ta nouvelle boîte mail pour confirmer le changement.');
    setNewEmail('');
  }

  async function handlePasswordSubmit(e) {
    e.preventDefault();
    setPasswordError('');
    setPasswordSuccess('');

    if (newPassword.length < 8) {
      setPasswordError('Le mot de passe doit contenir au moins 8 caractères.');
      return;
    }
    if (newPassword !== confirmPassword) {
      setPasswordError('Les deux mots de passe ne correspondent pas.');
      return;
    }

    setPasswordSubmitting(true);
    const { error } = await supabase.auth.updateUser({ password: newPassword });
    setPasswordSubmitting(false);

    if (error) {
      setPasswordError('Impossible de changer le mot de passe. Réessaie.');
      return;
    }

    setPasswordSuccess('Mot de passe mis à jour.');
    setNewPassword('');
    setConfirmPassword('');
  }

  return (
    <div className="flex flex-col gap-6 p-4">
      <div>
        <Link href="/profile" className="text-sm font-medium text-content-secondary">
          ← Profil
        </Link>
        <h1 className="mt-1 text-xl font-semibold text-content-primary">Paramètres</h1>
      </div>

      <section className="rounded-card border border-border bg-surface-card p-4">
        <h2 className="mb-1 text-sm font-semibold text-content-primary">Email</h2>
        <p className="mb-3 text-xs text-content-secondary">Actuel : {currentEmail}</p>

        <form onSubmit={handleEmailSubmit} className="flex flex-col gap-3">
          <input
            type="email"
            value={newEmail}
            onChange={(e) => setNewEmail(e.target.value)}
            placeholder="Nouvelle adresse email"
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
          {emailError && <p className="text-sm text-corail">{emailError}</p>}
          {emailSuccess && <p className="text-sm text-vert">{emailSuccess}</p>}
          <button
            type="submit"
            disabled={emailSubmitting}
            className="h-tap w-full rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface disabled:opacity-60"
          >
            {emailSubmitting ? 'Envoi...' : "Changer l'email"}
          </button>
        </form>
      </section>

      <section className="rounded-card border border-border bg-surface-card p-4">
        <h2 className="mb-3 text-sm font-semibold text-content-primary">Mot de passe</h2>

        <form onSubmit={handlePasswordSubmit} className="flex flex-col gap-3">
          <input
            type="password"
            value={newPassword}
            onChange={(e) => setNewPassword(e.target.value)}
            placeholder="Nouveau mot de passe"
            minLength={8}
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
          <input
            type="password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            placeholder="Confirmer le mot de passe"
            minLength={8}
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
          {passwordError && <p className="text-sm text-corail">{passwordError}</p>}
          {passwordSuccess && <p className="text-sm text-vert">{passwordSuccess}</p>}
          <button
            type="submit"
            disabled={passwordSubmitting}
            className="h-tap w-full rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface disabled:opacity-60"
          >
            {passwordSubmitting ? 'Mise à jour...' : 'Changer le mot de passe'}
          </button>
        </form>
      </section>

      <PushNotificationToggle />

      <Link
        href="/lieux-surveilles"
        className="rounded-card border border-border bg-surface-card p-4 text-center text-sm font-medium text-content-primary hover:bg-surface"
      >
        Lieux surveillés (alertes géolocalisées) →
      </Link>

      <Link
        href="/profile/edit"
        className="rounded-card border border-border bg-surface-card p-4 text-center text-sm font-medium text-content-primary hover:bg-surface"
      >
        Modifier mon profil (nom, bio, photo, confidentialité) →
      </Link>
    </div>
  );
}

MQEOF_SRC_APP_SETTINGS_PAGE_JSX

echo "Code push ajoute avec succes."
echo "Prochaine etape : executer la migration 043, puis suivre les etapes Supabase Dashboard (Edge Function + Webhook), puis git add -A && git commit -m \"notifications push : abonnement navigateur + service worker\" && git push"
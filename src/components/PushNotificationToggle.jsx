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


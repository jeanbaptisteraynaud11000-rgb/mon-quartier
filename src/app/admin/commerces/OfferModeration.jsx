'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';

export default function OfferModeration({ offer }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  async function handleDecision(status) {
    setBusy(true);
    await supabase.from('place_offers').update({ status }).eq('id', offer.id);
    setBusy(false);
    router.refresh();
  }

  return (
    <div className="rounded-card border border-border bg-surface-card p-3">
      <p className="text-sm font-medium text-content-primary">{offer.title}</p>
      <p className="text-xs text-content-secondary">
        {offer.places?.name} · jusqu'au {new Date(offer.ends_at).toLocaleDateString('fr-FR')}
      </p>
      {offer.description && (
        <p className="mt-1 text-sm text-content-secondary">{offer.description}</p>
      )}
      <div className="mt-2 flex gap-2">
        <button
          onClick={() => handleDecision('active')}
          disabled={busy}
          className="rounded-pill bg-vert px-3 py-1.5 text-xs font-medium text-white hover:opacity-90 disabled:opacity-60"
        >
          Activer
        </button>
        <button
          onClick={() => handleDecision('rejected')}
          disabled={busy}
          className="rounded-pill border border-border px-3 py-1.5 text-xs text-content-secondary hover:bg-surface"
        >
          Refuser
        </button>
      </div>
    </div>
  );
}


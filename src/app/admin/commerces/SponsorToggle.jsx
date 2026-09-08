'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { Star } from 'lucide-react';

export default function SponsorToggle({ placeId, isSponsored, sponsoredUntil }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [days, setDays] = useState(30);

  const currentlyActive = isSponsored && (!sponsoredUntil || new Date(sponsoredUntil) >= new Date());

  async function handleActivate() {
    setBusy(true);
    const until = new Date();
    until.setDate(until.getDate() + Number(days));

    await supabase
      .from('places')
      .update({ is_sponsored: true, sponsored_until: until.toISOString() })
      .eq('id', placeId);

    setBusy(false);
    router.refresh();
  }

  async function handleDeactivate() {
    setBusy(true);
    await supabase.from('places').update({ is_sponsored: false }).eq('id', placeId);
    setBusy(false);
    router.refresh();
  }

  if (currentlyActive) {
    return (
      <div className="flex flex-shrink-0 items-center gap-2">
        <span className="flex items-center gap-1 rounded-pill bg-amber-100 px-2 py-1 text-xs font-medium text-amber-700">
          <Star size={11} fill="currentColor" />
          Jusqu'au {new Date(sponsoredUntil).toLocaleDateString('fr-FR')}
        </span>
        <button
          onClick={handleDeactivate}
          disabled={busy}
          className="rounded-pill border border-border px-2 py-1 text-xs text-content-secondary hover:bg-surface"
        >
          Retirer
        </button>
      </div>
    );
  }

  return (
    <div className="flex flex-shrink-0 items-center gap-1.5">
      <select
        value={days}
        onChange={(e) => setDays(e.target.value)}
        className="rounded-card border border-border bg-surface px-2 py-1 text-xs text-content-primary"
      >
        <option value={7}>7 jours</option>
        <option value={30}>30 jours</option>
        <option value={90}>90 jours</option>
      </select>
      <button
        onClick={handleActivate}
        disabled={busy}
        className="rounded-pill bg-amber-500 px-3 py-1 text-xs font-medium text-white hover:bg-amber-600 disabled:opacity-60"
      >
        Sponsoriser
      </button>
    </div>
  );
}


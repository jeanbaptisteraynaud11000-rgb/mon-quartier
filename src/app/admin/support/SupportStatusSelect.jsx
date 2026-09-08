'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';

const STATUS_OPTIONS = [
  { value: 'open', label: 'Ouverte' },
  { value: 'in_progress', label: 'En cours' },
  { value: 'closed', label: 'Fermée' },
];

export default function SupportStatusSelect({ requestId, status }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  async function handleChange(e) {
    setBusy(true);
    await supabase.from('support_requests').update({ status: e.target.value }).eq('id', requestId);
    setBusy(false);
    router.refresh();
  }

  return (
    <select
      value={status}
      onChange={handleChange}
      disabled={busy}
      className="rounded-pill border border-border bg-surface px-2 py-1 text-xs font-medium text-content-primary"
    >
      {STATUS_OPTIONS.map((opt) => (
        <option key={opt.value} value={opt.value}>{opt.label}</option>
      ))}
    </select>
  );
}


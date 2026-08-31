'use client';

import { useState, useRef, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { MoreVertical } from 'lucide-react';
import { supabase } from '@/lib/supabaseClient';

export default function EventCardMenu({ eventId, isOrganizer }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const ref = useRef(null);

  useEffect(() => {
    function handleClickOutside(e) {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false);
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  if (!isOrganizer) return null;

  async function handleCancel(e) {
    e.preventDefault();
    e.stopPropagation();
    if (!confirm("Annuler cette activité ? Les inscrits seront informés.")) return;
    await supabase.rpc('cancel_event', { p_event_id: eventId });
    setOpen(false);
    router.refresh();
  }

  return (
    <div ref={ref} className="relative flex-shrink-0">
      <button
        onClick={(e) => {
          e.preventDefault();
          e.stopPropagation();
          setOpen((v) => !v);
        }}
        aria-label="Options"
        className="flex h-7 w-7 items-center justify-center rounded-pill text-content-secondary hover:bg-surface"
      >
        <MoreVertical size={16} />
      </button>

      {open && (
        <div className="absolute right-0 top-full z-10 mt-1 w-40 overflow-hidden rounded-card border border-border bg-surface shadow-soft">
          <button
            onClick={handleCancel}
            className="block w-full px-4 py-2 text-left text-sm text-corail hover:bg-surface-card"
          >
            Annuler l'activité
          </button>
        </div>
      )}
    </div>
  );
}


'use client';

// Placeholder enrichi le temps du chantier auth — la vraie page profil
// (avatar, bio, badges, stats...) sera construite au chantier dédié (Phase 2).

import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';

export default function ProfilePage() {
  const router = useRouter();

  async function handleLogout() {
    await supabase.auth.signOut();
    router.push('/login');
    router.refresh();
  }

  return (
    <div className="p-4">
      <div className="rounded-card border border-border bg-surface-card p-6 text-center text-sm text-content-secondary">
        Page « /profile » — à construire dans un prochain chantier.
      </div>

      <button
        onClick={handleLogout}
        className="mt-4 h-tap w-full rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface-card"
      >
        Se déconnecter
      </button>
    </div>
  );
}


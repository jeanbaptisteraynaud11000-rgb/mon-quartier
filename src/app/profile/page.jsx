'use client';

// Placeholder enrichi le temps du chantier auth/communauté — la vraie page
// profil (avatar, bio, badges, stats...) sera construite au chantier dédié.

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';

export default function ProfilePage() {
  const router = useRouter();
  const [inviteLink, setInviteLink] = useState('');
  const [generating, setGenerating] = useState(false);
  const [inviteError, setInviteError] = useState('');
  const [copied, setCopied] = useState(false);
  const [role, setRole] = useState(null);

  useEffect(() => {
    async function loadRole() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;
      const { data: profile } = await supabase
        .from('profiles')
        .select('role')
        .eq('user_id', user.id)
        .single();
      setRole(profile?.role);
    }
    loadRole();
  }, []);

  async function handleLogout() {
    await supabase.auth.signOut();
    router.push('/login');
    router.refresh();
  }

  async function handleGenerateInvite() {
    setGenerating(true);
    setInviteError('');

    const { data: { user } } = await supabase.auth.getUser();
    const { data: profile } = await supabase
      .from('profiles')
      .select('quartier_id')
      .eq('user_id', user.id)
      .single();

    if (!profile?.quartier_id) {
      setInviteError("Termine d'abord ton inscription pour pouvoir inviter quelqu'un.");
      setGenerating(false);
      return;
    }

    const { data: invitation, error } = await supabase
      .from('invitations')
      .insert({
        quartier_id: profile.quartier_id,
        invited_by: user.id,
      })
      .select('id')
      .single();

    setGenerating(false);

    if (error || !invitation) {
      setInviteError("Impossible de créer l'invitation pour le moment. Réessaie plus tard.");
      return;
    }

    setInviteLink(`${window.location.origin}/invite/${invitation.id}`);
  }

  async function handleCopyLink() {
    await navigator.clipboard.writeText(inviteLink);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="rounded-card border border-border bg-surface-card p-6 text-center text-sm text-content-secondary">
        Page « /profile » — à construire dans un prochain chantier.
      </div>

      <div className="rounded-card border border-border bg-surface-card p-4">
        <h2 className="font-semibold text-content-primary">Inviter un voisin</h2>
        <p className="mt-1 text-sm text-content-secondary">
          Le lien rattache automatiquement la personne à ton quartier. Valable 30 jours,
          utilisable une seule fois.
        </p>

        {!inviteLink ? (
          <button
            onClick={handleGenerateInvite}
            disabled={generating}
            className="mt-3 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
          >
            {generating ? 'Génération...' : "Générer un lien d'invitation"}
          </button>
        ) : (
          <div className="mt-3 flex flex-col gap-2">
            <div className="truncate rounded-card border border-border bg-surface px-3 py-2 text-xs text-content-secondary">
              {inviteLink}
            </div>
            <button
              onClick={handleCopyLink}
              className="h-tap w-full rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface"
            >
              {copied ? '✓ Copié !' : 'Copier le lien'}
            </button>
          </div>
        )}

        {inviteError && <p className="mt-2 text-sm text-corail">{inviteError}</p>}
      </div>

      {(role === 'quartier_admin' || role === 'super_admin') && (
        <Link
          href="/admin"
          className="block rounded-card border border-corail bg-corail/5 p-4 text-center font-medium text-corail transition-fast hover:bg-corail/10"
        >
          Administration →
        </Link>
      )}

      <button
        onClick={handleLogout}
        className="h-tap w-full rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface-card"
      >
        Se déconnecter
      </button>
    </div>
  );
}


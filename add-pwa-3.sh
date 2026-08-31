#!/usr/bin/env bash
set -e
echo "Ajout PWA (3/3) : liens profil, pages erreur..."

mkdir -p "src/app/profile"
cat > "src/app/profile/page.jsx" << 'MQEOF_SRC_APP_PROFILE_PAGE_JSX'
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

  async function handleDeleteAccount() {
    if (
      !confirm(
        'Supprimer ton compte ? Ton profil sera anonymisé et tu seras déconnecté. Cette action est irréversible.'
      )
    ) {
      return;
    }
    const { error } = await supabase.rpc('request_account_deletion');
    if (!error) {
      await supabase.auth.signOut();
      router.push('/login');
    }
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

      {role === 'super_admin' && (
        <Link
          href="/admin"
          className="block rounded-card border border-corail bg-corail/5 p-4 text-center font-medium text-corail transition-fast hover:bg-corail/10"
        >
          Administration →
        </Link>
      )}

      <div className="flex flex-col gap-1 rounded-card border border-border bg-surface-card p-2">
        <Link href="/help" className="rounded-card px-3 py-2 text-sm text-content-primary hover:bg-surface">
          Aide
        </Link>
        <Link href="/support" className="rounded-card px-3 py-2 text-sm text-content-primary hover:bg-surface">
          Contacter le support
        </Link>
        <Link href="/confidentialite" className="rounded-card px-3 py-2 text-sm text-content-primary hover:bg-surface">
          Confidentialité
        </Link>
        <Link href="/cgu" className="rounded-card px-3 py-2 text-sm text-content-primary hover:bg-surface">
          Conditions d'utilisation
        </Link>
      </div>

      <button
        onClick={handleLogout}
        className="h-tap w-full rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface-card"
      >
        Se déconnecter
      </button>

      <button
        onClick={handleDeleteAccount}
        className="h-tap w-full rounded-pill border border-corail font-medium text-corail transition-fast hover:bg-corail/5"
      >
        Supprimer mon compte
      </button>
    </div>
  );
}

MQEOF_SRC_APP_PROFILE_PAGE_JSX

mkdir -p "src/app"
cat > "src/app/not-found.jsx" << 'MQEOF_SRC_APP_NOT-FOUND_JSX'
import Link from 'next/link';

export default function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center p-6 text-center">
      <div className="text-4xl">🧭</div>
      <h1 className="mt-4 text-xl font-semibold text-content-primary">Page introuvable</h1>
      <p className="mt-2 text-sm text-content-secondary">
        Cette page n'existe pas ou plus.
      </p>
      <Link
        href="/"
        className="mt-6 inline-block h-tap rounded-pill bg-corail px-6 py-3 font-medium text-white transition-fast hover:bg-corail-hover"
      >
        Retour à l'accueil
      </Link>
    </div>
  );
}

MQEOF_SRC_APP_NOT-FOUND_JSX

mkdir -p "src/app"
cat > "src/app/error.jsx" << 'MQEOF_SRC_APP_ERROR_JSX'
'use client';

export default function Error({ reset }) {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center p-6 text-center">
      <div className="text-4xl">😕</div>
      <h1 className="mt-4 text-xl font-semibold text-content-primary">
        Une erreur est survenue
      </h1>
      <p className="mt-2 text-sm text-content-secondary">
        Ce n'est pas ta faute — réessaie dans un instant.
      </p>
      <button
        onClick={reset}
        className="mt-6 h-tap rounded-pill bg-corail px-6 py-3 font-medium text-white transition-fast hover:bg-corail-hover"
      >
        Réessayer
      </button>
    </div>
  );
}

MQEOF_SRC_APP_ERROR_JSX

echo "PWA (3/3) ajoutee avec succes."
echo "Prochaine etape : git add -A && git commit -m \"pwa 3/3 : liens profil + pages erreur\" && git push"
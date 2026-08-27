#!/usr/bin/env bash
set -e
echo "Ajout du chantier #5 (voisins + invitations)..."

mkdir -p "src/app/voisins"
cat > "src/app/voisins/page.jsx" << 'MQEOF_SRC_APP_VOISINS_PAGE_JSX'
// Server Component : annuaire des voisins du quartier.
//
// NOTE SUR LA PORTÉE : la vraie carte géographique interactive (section 7
// du prompt maître) est volontairement laissée pour un chantier dédié —
// elle nécessite une bibliothèque de cartographie (Leaflet/Mapbox) ET de
// stocker les coordonnées approximatives de chaque utilisateur, qu'on ne
// conserve pas encore aujourd'hui (seul le polygone du quartier existe).
// Cette page couvre déjà la partie utile immédiatement : voir qui fait
// partie de son quartier, dans le respect des préférences de vie privée.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';

function memberSince(dateString) {
  const date = new Date(dateString);
  const diffMonths =
    (Date.now() - date.getTime()) / (1000 * 60 * 60 * 24 * 30.44);

  if (diffMonths < 1) return "arrivé(e) ce mois-ci";
  if (diffMonths < 2) return 'membre depuis 1 mois';
  if (diffMonths < 12) return `membre depuis ${Math.floor(diffMonths)} mois`;
  const years = Math.floor(diffMonths / 12);
  return `membre depuis ${years} an${years > 1 ? 's' : ''}`;
}

export default async function VoisinsPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: myProfile } = await supabase
    .from('profiles')
    .select('quartier_id, quartiers(name, city)')
    .eq('user_id', user.id)
    .single();

  if (!myProfile?.quartier_id) {
    return (
      <div className="p-4">
        <div className="rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">
            Termine d'abord ton inscription pour voir tes voisins.
          </p>
          <Link
            href="/onboarding"
            className="mt-4 inline-block h-tap rounded-pill bg-corail px-6 py-3 font-medium text-white transition-fast hover:bg-corail-hover"
          >
            Terminer mon inscription
          </Link>
        </div>
      </div>
    );
  }

  // On respecte map_visibility = 'off' comme un choix général de discrétion,
  // pas seulement pour la carte à venir : quelqu'un qui a explicitement
  // demandé à ne pas apparaître ne doit pas se retrouver listé ici non plus.
  // Limite à 50 : mesure simple anti-scraping (section 83) en attendant une
  // vraie pagination si le quartier grossit.
  const { data: neighbors, error } = await supabase
    .from('profiles')
    .select('user_id, display_name, created_at, map_visibility')
    .eq('quartier_id', myProfile.quartier_id)
    .neq('map_visibility', 'off')
    .order('created_at', { ascending: true })
    .limit(50);

  return (
    <div className="flex flex-col gap-4 p-4">
      <div>
        <h1 className="text-xl font-semibold text-content-primary">Mes voisins</h1>
        <p className="text-sm text-content-secondary">
          {myProfile.quartiers?.name} — {myProfile.quartiers?.city}
        </p>
      </div>

      {error && (
        <p className="text-sm text-corail">Impossible de charger la liste pour le moment.</p>
      )}

      {!error && neighbors?.length === 0 && (
        <div className="rounded-card border border-border bg-surface-card p-6 text-center text-sm text-content-secondary">
          Aucun voisin visible pour l'instant.
        </div>
      )}

      <div className="flex flex-col gap-2">
        {neighbors?.map((neighbor) => {
          const isMe = neighbor.user_id === user.id;
          const initial = (neighbor.display_name || '?').charAt(0).toUpperCase();
          return (
            <div
              key={neighbor.user_id}
              className="flex items-center gap-3 rounded-card border border-border bg-surface-card p-3"
            >
              <div className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-pill bg-corail/10 font-semibold text-corail">
                {initial}
              </div>
              <div className="min-w-0 flex-1">
                <p className="truncate font-medium text-content-primary">
                  {neighbor.display_name || 'Voisin'} {isMe && '(toi)'}
                </p>
                <p className="text-xs text-content-secondary">
                  {memberSince(neighbor.created_at)}
                </p>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

MQEOF_SRC_APP_VOISINS_PAGE_JSX

mkdir -p "src/app/profile"
cat > "src/app/profile/page.jsx" << 'MQEOF_SRC_APP_PROFILE_PAGE_JSX'
'use client';

// Placeholder enrichi le temps du chantier auth/communauté — la vraie page
// profil (avatar, bio, badges, stats...) sera construite au chantier dédié.

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';

export default function ProfilePage() {
  const router = useRouter();
  const [inviteLink, setInviteLink] = useState('');
  const [generating, setGenerating] = useState(false);
  const [inviteError, setInviteError] = useState('');
  const [copied, setCopied] = useState(false);

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

      <button
        onClick={handleLogout}
        className="h-tap w-full rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface-card"
      >
        Se déconnecter
      </button>
    </div>
  );
}

MQEOF_SRC_APP_PROFILE_PAGE_JSX

mkdir -p "src/app/invite/[id]"
cat > "src/app/invite/[id]/page.jsx" << 'MQEOF_SRC_APP_INVITE_ID_PAGE_JSX'
// Server Component. Le middleware redirige déjà automatiquement vers
// /login?next=/invite/[id] si la personne n'est pas connectée (cette route
// n'est pas dans la liste des routes publiques) — pas besoin de le refaire
// ici.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';

const MESSAGES = {
  ok: null, // géré séparément (cas de succès)
  invalid: "Ce lien d'invitation n'existe pas.",
  revoked: 'Cette invitation a été annulée par son émetteur.',
  expired: "Ce lien d'invitation a expiré.",
  exhausted: 'Ce lien a déjà été utilisé.',
  already_member: 'Tu fais déjà partie d\'un quartier — tu ne peux pas en rejoindre un second via ce lien.',
};

export default async function InvitePage({ params }) {
  const { id } = await params;
  const supabase = await createClient();

  const { data, error } = await supabase.rpc('redeem_invitation', {
    p_invitation_id: id,
  });

  const result = data?.[0];

  if (error || !result) {
    return (
      <ScreenMessage emoji="😕" title="Une erreur est survenue">
        Impossible de traiter cette invitation pour le moment. Réessaie plus tard.
      </ScreenMessage>
    );
  }

  if (result.success) {
    return (
      <ScreenMessage emoji="🎉" title="Tu fais maintenant partie du quartier !">
        Ton adhésion à <span className="font-medium text-content-primary">{result.quartier_name}</span> est
        confirmée.
        <div className="mt-6">
          <Link
            href="/voisins"
            className="inline-block h-tap rounded-pill bg-corail px-6 py-3 font-medium text-white transition-fast hover:bg-corail-hover"
          >
            Découvrir mes voisins
          </Link>
        </div>
      </ScreenMessage>
    );
  }

  return (
    <ScreenMessage emoji="😕" title="Cette invitation n'est plus valable">
      {MESSAGES[result.reason] || "Ce lien d'invitation n'est plus valable."}
      <div className="mt-6">
        <Link href="/" className="text-sm font-medium text-corail">
          Retour à l'accueil
        </Link>
      </div>
    </ScreenMessage>
  );
}

function ScreenMessage({ emoji, title, children }) {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center p-6 text-center">
      <div className="mx-auto w-full max-w-sm">
        <div className="mb-4 text-4xl">{emoji}</div>
        <h1 className="mb-2 text-xl font-semibold text-content-primary">{title}</h1>
        <div className="text-sm text-content-secondary">{children}</div>
      </div>
    </div>
  );
}

MQEOF_SRC_APP_INVITE_ID_PAGE_JSX

echo "Chantier #5 ajoute avec succes."
echo "Prochaine etape : git add -A && git commit -m \"chantier 5 : voisins + invitations\" && git push"
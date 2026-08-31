#!/usr/bin/env bash
set -e
echo "Refonte profil selon reference..."

mkdir -p "src/app/profile"
cat > "src/app/profile/page.jsx" << 'MQEOF_SRC_APP_PROFILE_PAGE_JSX'
'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { getLevel } from '@/lib/levels';
import { Settings, Camera, ShieldCheck, Package, CalendarDays, Heart, Store } from 'lucide-react';

function memberSince(dateString) {
  if (!dateString) return '';
  const date = new Date(dateString);
  return `Voisin(e) depuis ${date.toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' })}`;
}

export default function ProfilePage() {
  const router = useRouter();
  const [inviteLink, setInviteLink] = useState('');
  const [generating, setGenerating] = useState(false);
  const [inviteError, setInviteError] = useState('');
  const [copied, setCopied] = useState(false);

  const [loading, setLoading] = useState(true);
  const [role, setRole] = useState(null);
  const [profile, setProfile] = useState(null);
  const [stats, setStats] = useState({ posts: 0, eventsOrganized: 0, eventsJoined: 0 });

  useEffect(() => {
    async function loadProfile() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data: p } = await supabase
        .from('profiles')
        .select('display_name, photo_url, bio, role, points, quartier_id, created_at')
        .eq('user_id', user.id)
        .single();

      setProfile(p);
      setRole(p?.role);

      const [{ count: posts }, { count: eventsOrganized }, { count: eventsJoined }] = await Promise.all([
        supabase.from('posts').select('*', { count: 'exact', head: true }).eq('user_id', user.id).eq('status', 'active'),
        supabase.from('events').select('*', { count: 'exact', head: true }).eq('user_id', user.id).eq('status', 'active'),
        supabase.from('event_attendees').select('*', { count: 'exact', head: true }).eq('user_id', user.id),
      ]);

      setStats({ posts: posts || 0, eventsOrganized: eventsOrganized || 0, eventsJoined: eventsJoined || 0 });
      setLoading(false);
    }
    loadProfile();
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

    if (!profile?.quartier_id) {
      setInviteError("Termine d'abord ton inscription pour pouvoir inviter quelqu'un.");
      setGenerating(false);
      return;
    }

    const { data: invitation, error } = await supabase
      .from('invitations')
      .insert({ quartier_id: profile.quartier_id, invited_by: user.id })
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

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="skeleton h-4 w-40" />
      </div>
    );
  }

  const initial = (profile?.display_name || '?').charAt(0).toUpperCase();
  const points = profile?.points || 0;
  const level = getLevel(points);

  return (
    <div className="flex flex-col gap-4 pb-4">
      {/* Bannière + avatar */}
      <div className="relative">
        <div className="h-28 w-full overflow-hidden">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/profile-banner.png" alt="" className="h-full w-full object-cover" />
        </div>

        <Link
          href="/settings"
          aria-label="Paramètres"
          className="absolute right-4 top-4 flex h-9 w-9 items-center justify-center rounded-pill bg-white/90 text-content-primary shadow-soft"
        >
          <Settings size={17} />
        </Link>

        <div className="relative -mt-12 flex flex-col items-center px-4">
          <div className="relative">
            <div className="flex h-24 w-24 items-center justify-center overflow-hidden rounded-pill border-4 border-surface bg-corail/10 text-2xl font-semibold text-corail shadow-soft">
              {profile?.photo_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={profile.photo_url} alt="" className="h-full w-full object-cover" />
              ) : (
                initial
              )}
            </div>
            <Link
              href="/profile/edit"
              aria-label="Modifier ma photo"
              className="absolute bottom-0 right-0 flex h-8 w-8 items-center justify-center rounded-pill border-2 border-surface bg-corail text-white shadow-soft"
            >
              <Camera size={14} />
            </Link>
          </div>

          <p className="mt-3 text-lg font-semibold text-content-primary">
            {profile?.display_name || 'Voisin'}
          </p>
          <p className="text-xs text-content-secondary">{memberSince(profile?.created_at)}</p>
        </div>
      </div>

      <div className="flex flex-col gap-4 px-4">
        {/* Niveau — remplace la note/avis qu'on n'a pas */}
        <div className="flex items-center gap-4 rounded-card border border-border bg-surface-card p-4 shadow-soft">
          <div className="flex h-14 w-14 flex-shrink-0 items-center justify-center rounded-pill bg-vert/10 text-vert">
            <ShieldCheck size={26} />
          </div>
          <div>
            <p className="font-semibold text-content-primary">{level.label}</p>
            <p className="text-xs text-content-secondary">
              {points} point{points > 1 ? 's' : ''} de contribution
            </p>
          </div>
        </div>

        {/* Statistiques réelles */}
        <div className="grid grid-cols-3 gap-2">
          <StatBlock value={stats.posts} label="Annonces" href="/mes-annonces" />
          <StatBlock value={stats.eventsOrganized} label="Activités créées" href="/activites" />
          <StatBlock value={stats.eventsJoined} label="Participations" href="/activites" />
        </div>

        {/* Actions rapides */}
        <div>
          <h2 className="mb-2 text-sm font-semibold text-content-primary">Mes actions rapides</h2>
          <div className="grid grid-cols-2 gap-2">
            <QuickAction href="/mes-annonces" icon={Package} label="Mes annonces" />
            <QuickAction href="/activites" icon={CalendarDays} label="Mes activités" />
            <QuickAction href="/favoris" icon={Heart} label="Mes favoris" />
            <QuickAction href="/commerces" icon={Store} label="Commerces" />
          </div>
        </div>

        {profile?.bio && (
          <p className="rounded-card border border-border bg-surface-card p-4 text-sm text-content-primary">
            {profile.bio}
          </p>
        )}

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
          <Link href="/voisins" className="rounded-card px-3 py-2 text-sm text-content-primary hover:bg-surface">
            Mes voisins
          </Link>
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
    </div>
  );
}

function StatBlock({ value, label, href }) {
  return (
    <Link
      href={href}
      className="flex flex-col items-center gap-0.5 rounded-card border border-border bg-surface-card p-3 text-center shadow-soft hover:bg-border/20"
    >
      <span className="text-lg font-semibold text-content-primary">{value}</span>
      <span className="text-[11px] text-content-secondary">{label}</span>
    </Link>
  );
}

function QuickAction({ href, icon: Icon, label }) {
  return (
    <Link
      href={href}
      className="flex items-center gap-2 rounded-card border border-border bg-surface-card p-3 text-sm font-medium text-content-primary shadow-soft transition-fast hover:bg-border/20"
    >
      <span className="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-pill bg-surface text-content-secondary">
        <Icon size={15} />
      </span>
      {label}
    </Link>
  );
}

MQEOF_SRC_APP_PROFILE_PAGE_JSX

mkdir -p "public"
base64 -d > "public/profile-banner.png" << 'MQB64EOF_PUBLIC_PROFILE-BANNER_PNG'
iVBORw0KGgoAAAANSUhEUgAAAyAAAAEsCAIAAAC0T0BtAAAGUUlEQVR4nO3dPW6TQRRAUYK8EHZEzwLp07ETKCPRUEay6FNEAhTJMpGuPT/fOQuwpvPV8/jNw9Pv8wcAADofRx8AAGA3AgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABiAgsAICawAABip9EHgE18evw6+giBp89fRh8BYAcmWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMZvcAYB7m/b1i+pBCxMsAICYwAIAiAksAICYwAIAiAksAICYwAIAiAksAICYwAIAiAksAIDY5pvc51kUW22GBQDmZ4IFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABDbfJM7wFXzPPnwh7cfYHUmWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMZvcmcWE27Rf2akNwBtXv7NMsAAAYgILACAmsAAAYgILACAmsAAAYgILACAmsAAAYgILACAmsAAAYja5A7CqaV+AuMTLEMdhggUAEBNYAAAxgQUAEBNYAAAxl9yBd1vlZrELxcAoJlgAADGBBQAQE1gAADGBBQAQO61yWfUNd1cBgGmZYAEAxAQWAEBMYAEAxAQWAEDMJneAVS36L6X/4Z9MrM4ECwAgJrAAAGICCwAgJrAAAGICCwAgJrAAAGICCwAgJrAAAGICCwAgZpM7AMxl6R39tvC/MsECAIgJLACAmMACAIgJLACAmEvuc1n6YuMlLjwCcDQmWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABATWAAAMYEFABA7jT4AAMAsfpyfk88RWADAzVXhsgqBBQBkjhZSlwgsABhAiOxNYAHAnYiq4xBYAExHiLA6axoAAGImWACTMsWBdQksgOlIK1idwAK2JVOAUdzBAgCImWABfxn5ACRMsCCgSwD4lwkWXCGeAHgvgcXNCRQAjsZPhAAAMROsOzHFAYDjMMECAIitOsEyEAIApmWCBQAQE1gAADGBBQAQE1gAADGBBQAQE1gAADGBBQAQE1gAADGBBQAQE1gAADGBBQAQE1gAADGBBQAQE1gAADGBBQAQE1gAALGHb79+jj4DAMBWTLAAAGICCwAgJrAAAGICCwAgdhp9AABgf9/Pz6OPcFcCCwAGOFpwHI3AAmAKgoOdCCyASQkOWJfAApYhOIBVCCxYmOAAmJPAYiuCA4AZCKzNCQ4AuL/DBZbgAABu7SQ4AABansoBAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIgJLACAmMACAIi9APUlbpibi20gAAAAAElFTkSuQmCC
MQB64EOF_PUBLIC_PROFILE-BANNER_PNG

echo "Profil refondu avec succes."
echo "Prochaine etape : git add -A && git commit -m \"profil selon reference : banniere, niveau, actions rapides\" && git push"
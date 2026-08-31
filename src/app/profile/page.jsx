'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { getLevel } from '@/lib/levels';
import { Settings, Pencil } from 'lucide-react';

function memberSince(dateString) {
  if (!dateString) return '';
  const date = new Date(dateString);
  const diffMonths = (Date.now() - date.getTime()) / (1000 * 60 * 60 * 24 * 30.44);
  if (diffMonths < 1) return "arrivé(e) ce mois-ci";
  if (diffMonths < 12) return `membre depuis ${Math.max(1, Math.floor(diffMonths))} mois`;
  const years = Math.floor(diffMonths / 12);
  return `membre depuis ${years} an${years > 1 ? 's' : ''}`;
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

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="skeleton h-4 w-40" />
      </div>
    );
  }

  const initial = (profile?.display_name || '?').charAt(0).toUpperCase();
  const points = profile?.points || 0;

  return (
    <div className="flex flex-col gap-4 p-4">
      {/* En-tête profil */}
      <div className="flex items-center gap-4 rounded-card border border-border bg-surface-card p-4 shadow-soft">
        {profile?.photo_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={profile.photo_url} alt="" className="h-16 w-16 flex-shrink-0 rounded-pill object-cover" />
        ) : (
          <div className="flex h-16 w-16 flex-shrink-0 items-center justify-center rounded-pill bg-corail/10 text-xl font-semibold text-corail">
            {initial}
          </div>
        )}
        <div className="min-w-0 flex-1">
          <p className="truncate text-lg font-semibold text-content-primary">
            {profile?.display_name || 'Voisin'}
          </p>
          <p className="text-xs text-content-secondary">{memberSince(profile?.created_at)}</p>
          <p className="mt-1 text-xs font-medium text-corail">{getLevel(points).label}</p>
        </div>
        <Link
          href="/profile/edit"
          aria-label="Modifier mon profil"
          className="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-pill border border-border text-content-secondary hover:bg-surface"
        >
          <Pencil size={15} />
        </Link>
      </div>

      {profile?.bio && (
        <p className="rounded-card border border-border bg-surface-card p-4 text-sm text-content-primary">
          {profile.bio}
        </p>
      )}

      {/* Statistiques factuelles — jamais de score opaque (section 73) */}
      <div className="grid grid-cols-3 gap-2">
        <StatBlock value={stats.posts} label="annonces" href="/mes-annonces" />
        <StatBlock value={stats.eventsOrganized} label="activités créées" href="/activites" />
        <StatBlock value={stats.eventsJoined} label="participations" href="/activites" />
      </div>

      <div className="grid grid-cols-2 gap-2">
        <Link
          href="/mes-annonces"
          className="rounded-card border border-border bg-surface-card p-3 text-center text-sm font-medium text-content-primary shadow-soft hover:bg-border/20"
        >
          Mes annonces
        </Link>
        <Link
          href="/settings"
          className="flex items-center justify-center gap-1.5 rounded-card border border-border bg-surface-card p-3 text-center text-sm font-medium text-content-primary shadow-soft hover:bg-border/20"
        >
          <Settings size={15} /> Paramètres
        </Link>
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
        <Link href="/commerces" className="rounded-card px-3 py-2 text-sm text-content-primary hover:bg-surface">
          Commerces & lieux du quartier
        </Link>
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


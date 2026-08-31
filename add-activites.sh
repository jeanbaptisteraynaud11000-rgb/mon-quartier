#!/usr/bin/env bash
set -e
echo "Ajout du systeme activites..."

mkdir -p "src/lib"
cat > "src/lib/eventCategories.js" << 'MQEOF_SRC_LIB_EVENTCATEGORIES_JS'
import { MapPin, Landmark, Dumbbell, Dices, Sparkles } from 'lucide-react';

export const EVENT_CATEGORIES = [
  { category: 'sortie', label: 'Sortie', icon: MapPin },
  { category: 'musee', label: 'Musée / Culture', icon: Landmark },
  { category: 'sport', label: 'Sport', icon: Dumbbell },
  { category: 'jeux_de_societe', label: 'Jeux de société', icon: Dices },
  { category: 'autre', label: 'Autre', icon: Sparkles },
];

export function getEventCategoryInfo(category) {
  return EVENT_CATEGORIES.find((c) => c.category === category) || { label: category, icon: Sparkles };
}

export function formatEventDate(dateString) {
  const date = new Date(dateString);
  return date.toLocaleDateString('fr-FR', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
}

MQEOF_SRC_LIB_EVENTCATEGORIES_JS

mkdir -p "src/components/layout"
cat > "src/components/layout/BottomNav.jsx" << 'MQEOF_SRC_COMPONENTS_LAYOUT_BOTTOMNAV_JSX'
'use client';

import { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Home, Grid3x3, Plus, Calendar, CircleUserRound } from 'lucide-react';
import CreateSheet from './CreateSheet';

const NAV_ITEMS = [
  { href: '/', label: 'Accueil', icon: Home },
  { href: '/annonces', label: 'Annonces', icon: Grid3x3 },
  // Le bouton central "+" est géré séparément (voir ci-dessous)
  { href: '/activites', label: 'Activités', icon: Calendar },
  { href: '/profile', label: 'Profil', icon: CircleUserRound },
];

function isActive(pathname, href) {
  if (href === '/') return pathname === '/';
  return pathname.startsWith(href);
}

export default function BottomNav() {
  const pathname = usePathname();
  const [sheetOpen, setSheetOpen] = useState(false);

  const [left, right] = [NAV_ITEMS.slice(0, 2), NAV_ITEMS.slice(2)];

  return (
    <>
      <nav className="safe-bottom fixed bottom-0 left-0 right-0 z-30 border-t border-border bg-surface/95 backdrop-blur">
        <div className="relative mx-auto flex h-nav-h max-w-lg items-center justify-between px-4">
          {left.map((item) => (
            <NavLink key={item.href} item={item} active={isActive(pathname, item.href)} />
          ))}

          {/* Bouton central "+" — surélevé, toujours identifiable */}
          <div className="flex w-16 justify-center">
            <button
              aria-label="Créer une publication"
              onClick={() => setSheetOpen(true)}
              className="-mt-8 flex h-14 w-14 items-center justify-center rounded-pill bg-corail text-white shadow-soft transition-fast hover:bg-corail-hover active:scale-95"
            >
              <Plus size={26} strokeWidth={2.2} />
            </button>
          </div>

          {right.map((item) => (
            <NavLink key={item.href} item={item} active={isActive(pathname, item.href)} />
          ))}
        </div>
      </nav>

      <CreateSheet open={sheetOpen} onClose={() => setSheetOpen(false)} />
    </>
  );
}

function NavLink({ item, active }) {
  const Icon = item.icon;
  return (
    <Link
      href={item.href}
      className="flex w-16 flex-col items-center gap-1 py-2 text-[11px] transition-fast"
    >
      <Icon
        size={22}
        strokeWidth={active ? 2.2 : 1.8}
        className={active ? 'text-corail' : 'text-content-secondary'}
      />
      <span className={active ? 'font-medium text-corail' : 'text-content-secondary'}>
        {item.label}
      </span>
    </Link>
  );
}

MQEOF_SRC_COMPONENTS_LAYOUT_BOTTOMNAV_JSX

mkdir -p "src/components/layout"
cat > "src/components/layout/CreateSheet.jsx" << 'MQEOF_SRC_COMPONENTS_LAYOUT_CREATESHEET_JSX'
'use client';

import { useEffect } from 'react';
import Link from 'next/link';
import { X, CalendarPlus } from 'lucide-react';
import { POST_TYPES } from '@/lib/postTypes';

export default function CreateSheet({ open, onClose }) {
  // Empêche le scroll du fond quand la sheet est ouverte
  useEffect(() => {
    if (open) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = '';
    }
    return () => {
      document.body.style.overflow = '';
    };
  }, [open]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50" role="dialog" aria-modal="true" aria-label="Créer une publication">
      {/* Overlay */}
      <button
        aria-label="Fermer"
        onClick={onClose}
        className="absolute inset-0 bg-black/40 transition-fast"
      />

      {/* Sheet */}
      <div className="safe-bottom absolute bottom-0 left-0 right-0 animate-in slide-in-from-bottom rounded-t-sheet bg-surface p-6 shadow-sheet">
        <div className="mx-auto mb-4 h-1 w-10 rounded-pill bg-border" />

        <div className="mb-5 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-content-primary">
            Que souhaitez-vous partager ?
          </h2>
          <button
            aria-label="Fermer"
            onClick={onClose}
            className="flex h-tap w-tap items-center justify-center rounded-pill text-content-secondary hover:bg-surface-card"
          >
            <X size={20} />
          </button>
        </div>

        <div className="flex flex-col gap-2">
          {POST_TYPES.map((option) => {
            const Icon = option.icon;
            return (
              <Link
                key={option.type}
                href={`/new?type=${option.type}`}
                onClick={onClose}
                className="flex items-center gap-4 rounded-card bg-surface-card px-4 py-4 transition-fast hover:bg-border/60 active:scale-[0.98]"
              >
                <span className="flex h-10 w-10 items-center justify-center rounded-pill bg-surface text-content-primary" aria-hidden="true">
                  <Icon size={20} />
                </span>
                <span className="text-base font-medium text-content-primary">
                  {option.label}
                </span>
              </Link>
            );
          })}

          <Link
            href="/activites/new"
            onClick={onClose}
            className="flex items-center gap-4 rounded-card bg-surface-card px-4 py-4 transition-fast hover:bg-border/60 active:scale-[0.98]"
          >
            <span className="flex h-10 w-10 items-center justify-center rounded-pill bg-surface text-content-primary" aria-hidden="true">
              <CalendarPlus size={20} />
            </span>
            <span className="text-base font-medium text-content-primary">
              Organiser une activité
            </span>
          </Link>
        </div>
      </div>
    </div>
  );
}

MQEOF_SRC_COMPONENTS_LAYOUT_CREATESHEET_JSX

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

MQEOF_SRC_APP_PROFILE_PAGE_JSX

mkdir -p "src/app/activites"
cat > "src/app/activites/page.jsx" << 'MQEOF_SRC_APP_ACTIVITES_PAGE_JSX'
// Server Component : activités à venir du quartier, triées par date.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { getEventCategoryInfo, formatEventDate } from '@/lib/eventCategories';

export default async function ActivitesPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: profile } = await supabase
    .from('profiles')
    .select('quartier_id')
    .eq('user_id', user.id)
    .single();

  if (!profile?.quartier_id) {
    return (
      <div className="p-4">
        <div className="rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">
            Termine d'abord ton inscription pour voir les activités de ton quartier.
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

  const { data: events, error } = await supabase
    .from('events')
    .select('id, category, title, location, event_date, max_attendees, user_id')
    .eq('quartier_id', profile.quartier_id)
    .eq('status', 'active')
    .gte('event_date', new Date().toISOString())
    .order('event_date', { ascending: true })
    .limit(30);

  let attendeeCounts = {};
  if (events?.length > 0) {
    const { data: attendees } = await supabase
      .from('event_attendees')
      .select('event_id')
      .in('event_id', events.map((e) => e.id));
    for (const a of attendees || []) {
      attendeeCounts[a.event_id] = (attendeeCounts[a.event_id] || 0) + 1;
    }
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-content-primary">Activités</h1>
        <Link
          href="/activites/new"
          className="rounded-pill bg-corail px-4 py-2 text-sm font-medium text-white transition-fast hover:bg-corail-hover"
        >
          Organiser
        </Link>
      </div>

      {error && (
        <p className="text-sm text-corail">Impossible de charger les activités pour le moment.</p>
      )}

      {!error && events?.length === 0 && (
        <div className="rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">Aucune activité prévue pour l'instant.</p>
          <p className="mt-1 text-sm text-content-secondary">
            Sortie, sport, jeux de société... lance la première !
          </p>
          <Link
            href="/activites/new"
            className="mt-4 inline-block h-tap rounded-pill bg-corail px-6 py-3 font-medium text-white transition-fast hover:bg-corail-hover"
          >
            Organiser une activité
          </Link>
        </div>
      )}

      <div className="flex flex-col gap-3">
        {events?.map((event) => {
          const catInfo = getEventCategoryInfo(event.category);
          const Icon = catInfo.icon;
          const count = attendeeCounts[event.id] || 0;
          const isFull = count >= event.max_attendees;
          return (
            <Link
              key={event.id}
              href={`/activites/${event.id}`}
              className="flex gap-3 rounded-card border border-border bg-surface-card p-4 shadow-soft transition-fast hover:bg-border/20 active:scale-[0.99]"
            >
              <div className="flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-pill bg-vert/10 text-vert">
                <Icon size={22} />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-xs font-medium text-content-secondary">
                  {formatEventDate(event.event_date)} · {catInfo.label}
                </p>
                <p className="mt-0.5 font-semibold text-content-primary">{event.title}</p>
                {event.location && (
                  <p className="mt-0.5 truncate text-sm text-content-secondary">{event.location}</p>
                )}
                <p className={`mt-1 text-xs font-medium ${isFull ? 'text-corail' : 'text-content-secondary'}`}>
                  {isFull ? 'Complet' : `${count} / ${event.max_attendees} places`}
                </p>
              </div>
            </Link>
          );
        })}
      </div>
    </div>
  );
}

MQEOF_SRC_APP_ACTIVITES_PAGE_JSX

mkdir -p "src/app/activites/[id]"
cat > "src/app/activites/[id]/page.jsx" << 'MQEOF_SRC_APP_ACTIVITES_ID_PAGE_JSX'
'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';
import { getEventCategoryInfo, formatEventDate } from '@/lib/eventCategories';

const JOIN_ERROR_MESSAGES = {
  invalid: "Cette activité n'existe plus.",
  past: 'Cette activité est déjà passée.',
  wrong_quartier: "Tu dois faire partie de ce quartier pour t'inscrire.",
  already_joined: 'Tu es déjà inscrit(e).',
  full: "C'est complet.",
};

export default function ActivityDetailPage() {
  const { id } = useParams();
  const router = useRouter();

  const [currentUserId, setCurrentUserId] = useState(null);
  const [event, setEvent] = useState(null);
  const [organizerName, setOrganizerName] = useState('Voisin');
  const [attendees, setAttendees] = useState([]);
  const [loading, setLoading] = useState(true);
  const [notFoundState, setNotFoundState] = useState(false);
  const [actionError, setActionError] = useState('');
  const [busy, setBusy] = useState(false);

  async function load() {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      router.push('/login');
      return;
    }
    setCurrentUserId(user.id);

    const { data: ev, error } = await supabase
      .from('events')
      .select('id, category, title, description, location, event_date, max_attendees, status, user_id')
      .eq('id', id)
      .single();

    if (error || !ev) {
      setNotFoundState(true);
      setLoading(false);
      return;
    }
    setEvent(ev);

    const { data: organizerProfile } = await supabase
      .from('profiles')
      .select('display_name')
      .eq('user_id', ev.user_id)
      .single();
    setOrganizerName(organizerProfile?.display_name || 'Voisin');

    const { data: attendeeRows } = await supabase
      .from('event_attendees')
      .select('user_id, joined_at')
      .eq('event_id', id)
      .order('joined_at', { ascending: true });

    const userIds = (attendeeRows || []).map((a) => a.user_id);
    const { data: attendeeProfiles } = await supabase
      .from('profiles')
      .select('user_id, display_name')
      .in('user_id', userIds.length > 0 ? userIds : ['00000000-0000-0000-0000-000000000000']);

    const nameByUserId = Object.fromEntries((attendeeProfiles || []).map((p) => [p.user_id, p.display_name]));
    setAttendees((attendeeRows || []).map((a) => ({ ...a, name: nameByUserId[a.user_id] || 'Voisin' })));

    setLoading(false);
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  async function handleJoin() {
    setBusy(true);
    setActionError('');
    const { data, error } = await supabase.rpc('join_event', { p_event_id: id });
    setBusy(false);

    const result = data?.[0];
    if (error || !result?.success) {
      setActionError(JOIN_ERROR_MESSAGES[result?.reason] || 'Impossible de rejoindre pour le moment.');
      return;
    }
    load();
  }

  async function handleLeave() {
    setBusy(true);
    await supabase.from('event_attendees').delete().eq('event_id', id).eq('user_id', currentUserId);
    setBusy(false);
    load();
  }

  async function handleCancel() {
    if (!confirm('Annuler cette activité ? Les inscrits seront informés que ça n\'a plus lieu.')) return;
    setBusy(true);
    await supabase.rpc('cancel_event', { p_event_id: id });
    setBusy(false);
    load();
  }

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="skeleton h-4 w-40" />
      </div>
    );
  }

  if (notFoundState) {
    return (
      <div className="p-6 text-center text-content-secondary">
        Cette activité n'existe pas.
      </div>
    );
  }

  const catInfo = getEventCategoryInfo(event.category);
  const Icon = catInfo.icon;
  const isOrganizer = event.user_id === currentUserId;
  const alreadyJoined = attendees.some((a) => a.user_id === currentUserId);
  const isFull = attendees.length >= event.max_attendees;
  const isCancelled = event.status === 'cancelled';

  return (
    <div className="flex flex-col gap-5 p-4">
      <Link href="/activites" className="text-sm font-medium text-content-secondary">
        ← Retour aux activités
      </Link>

      <div className="rounded-card border border-border bg-surface-card p-5">
        {isCancelled && (
          <div className="mb-3 rounded-card bg-corail/10 px-3 py-2 text-sm font-medium text-corail">
            Cette activité a été annulée
          </div>
        )}

        <div className="flex items-center gap-2">
          <span className="flex h-8 w-8 items-center justify-center rounded-pill bg-vert/10 text-vert">
            <Icon size={16} />
          </span>
          <span className="text-sm font-medium text-content-secondary">{catInfo.label}</span>
        </div>

        <h1 className="mt-3 text-xl font-semibold text-content-primary">{event.title}</h1>

        <p className="mt-2 text-sm text-content-secondary">
          Organisé par {organizerName} · {formatEventDate(event.event_date)}
        </p>

        {event.location && (
          <p className="mt-3 text-sm text-content-secondary">
            <span className="font-medium text-content-primary">Lieu : </span>
            {event.location}
          </p>
        )}

        {event.description && (
          <p className="mt-3 whitespace-pre-wrap text-content-primary">{event.description}</p>
        )}

        <p className="mt-3 text-sm font-medium text-content-secondary">
          {attendees.length} / {event.max_attendees} places
        </p>
      </div>

      {actionError && <p className="text-sm text-corail">{actionError}</p>}

      {!isCancelled && !isOrganizer && (
        <button
          onClick={alreadyJoined ? handleLeave : handleJoin}
          disabled={busy || (!alreadyJoined && isFull)}
          className={`h-tap w-full rounded-pill font-medium transition-fast disabled:opacity-60 ${
            alreadyJoined
              ? 'border border-border text-content-primary hover:bg-surface-card'
              : 'bg-corail text-white hover:bg-corail-hover'
          }`}
        >
          {alreadyJoined ? 'Se désinscrire' : isFull ? 'Complet' : 'Je participe'}
        </button>
      )}

      {isOrganizer && !isCancelled && (
        <button
          onClick={handleCancel}
          disabled={busy}
          className="h-tap w-full rounded-pill border border-corail font-medium text-corail transition-fast hover:bg-corail/5 disabled:opacity-60"
        >
          Annuler l'activité
        </button>
      )}

      {attendees.length > 0 && (
        <div>
          <h2 className="mb-2 text-sm font-medium text-content-secondary">Participants</h2>
          <div className="flex flex-col gap-2">
            {attendees.map((a) => (
              <div key={a.user_id} className="rounded-card border border-border bg-surface-card p-3 text-sm text-content-primary">
                {a.name} {a.user_id === currentUserId && '(toi)'}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

MQEOF_SRC_APP_ACTIVITES_ID_PAGE_JSX

mkdir -p "src/app/activites/new"
cat > "src/app/activites/new/page.jsx" << 'MQEOF_SRC_APP_ACTIVITES_NEW_PAGE_JSX'
'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { EVENT_CATEGORIES } from '@/lib/eventCategories';

export default function NewActivityPage() {
  const router = useRouter();

  const [quartierId, setQuartierId] = useState(null);
  const [loadingProfile, setLoadingProfile] = useState(true);

  const [category, setCategory] = useState('sortie');
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [location, setLocation] = useState('');
  const [eventDate, setEventDate] = useState('');
  const [maxAttendees, setMaxAttendees] = useState(10);

  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const hasSubmittedRef = useRef(false);

  useEffect(() => {
    async function loadProfile() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        router.push('/login');
        return;
      }
      const { data: profile } = await supabase
        .from('profiles')
        .select('quartier_id')
        .eq('user_id', user.id)
        .single();

      if (!profile?.quartier_id) {
        router.push('/onboarding');
        return;
      }

      setQuartierId(profile.quartier_id);
      setLoadingProfile(false);
    }
    loadProfile();
  }, [router]);

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');

    if (hasSubmittedRef.current) return;

    if (!title.trim()) {
      setError('Le titre est obligatoire.');
      return;
    }
    if (!eventDate) {
      setError('La date est obligatoire.');
      return;
    }

    const isoDate = new Date(eventDate).toISOString();
    if (new Date(isoDate) <= new Date()) {
      setError("La date doit être dans le futur.");
      return;
    }

    hasSubmittedRef.current = true;
    setSubmitting(true);

    const { data: { user } } = await supabase.auth.getUser();

    const { data: newEvent, error: insertError } = await supabase
      .from('events')
      .insert({
        user_id: user.id,
        quartier_id: quartierId,
        category,
        title: title.trim(),
        description: description.trim() || null,
        location: location.trim() || null,
        event_date: isoDate,
        max_attendees: maxAttendees,
        status: 'active',
      })
      .select('id')
      .single();

    setSubmitting(false);

    if (insertError || !newEvent) {
      hasSubmittedRef.current = false;
      setError("Une erreur est survenue lors de la création. Réessaie.");
      return;
    }

    router.push(`/activites/${newEvent.id}`);
  }

  if (loadingProfile) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="skeleton h-4 w-40" />
      </div>
    );
  }

  return (
    <div className="p-6">
      <h1 className="mb-6 text-xl font-semibold text-content-primary">Organiser une activité</h1>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <div>
          <label className="mb-1 block text-sm font-medium text-content-primary">Catégorie</label>
          <div className="grid grid-cols-2 gap-2">
            {EVENT_CATEGORIES.map((cat) => {
              const Icon = cat.icon;
              return (
                <button
                  key={cat.category}
                  type="button"
                  onClick={() => setCategory(cat.category)}
                  className={`flex items-center gap-2 rounded-card border px-3 py-3 text-sm font-medium transition-fast ${
                    category === cat.category
                      ? 'border-corail bg-corail/5 text-corail'
                      : 'border-border bg-surface text-content-primary hover:bg-surface-card'
                  }`}
                >
                  <Icon size={16} /> {cat.label}
                </button>
              );
            })}
          </div>
        </div>

        <div>
          <label htmlFor="title" className="mb-1 block text-sm font-medium text-content-primary">
            Titre
          </label>
          <input
            id="title"
            type="text"
            required
            maxLength={100}
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Ex : Partie de belote entre voisins"
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        <div>
          <label htmlFor="description" className="mb-1 block text-sm font-medium text-content-primary">
            Description <span className="text-content-secondary">(optionnel)</span>
          </label>
          <textarea
            id="description"
            rows={3}
            maxLength={1000}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            className="w-full resize-none rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        <div>
          <label htmlFor="location" className="mb-1 block text-sm font-medium text-content-primary">
            Lieu <span className="text-content-secondary">(optionnel)</span>
          </label>
          <input
            id="location"
            type="text"
            maxLength={150}
            value={location}
            onChange={(e) => setLocation(e.target.value)}
            placeholder="Ex : Parc Olbius Riquier, devant l'entrée"
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        <div>
          <label htmlFor="eventDate" className="mb-1 block text-sm font-medium text-content-primary">
            Date et heure
          </label>
          <input
            id="eventDate"
            type="datetime-local"
            required
            value={eventDate}
            onChange={(e) => setEventDate(e.target.value)}
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        <div>
          <label htmlFor="maxAttendees" className="mb-1 block text-sm font-medium text-content-primary">
            Nombre de places
          </label>
          <input
            id="maxAttendees"
            type="number"
            required
            min={1}
            max={500}
            value={maxAttendees}
            onChange={(e) => setMaxAttendees(parseInt(e.target.value, 10) || 1)}
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        {error && <p className="text-sm text-corail">{error}</p>}

        <button
          type="submit"
          disabled={submitting}
          className="mt-2 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
        >
          {submitting ? 'Création...' : "Créer l'activité"}
        </button>
      </form>
    </div>
  );
}

MQEOF_SRC_APP_ACTIVITES_NEW_PAGE_JSX

echo "Activites ajoutees avec succes."
echo "Prochaine etape : executer la migration 016, puis git add -A && git commit -m \"activites : sorties, sport, jeux avec places limitees\" && git push"
#!/usr/bin/env bash
set -e
echo "Ajout : verification, achat groupe, sondages, lieux surveilles..."

mkdir -p "src/lib"
cat > "src/lib/postTypes.js" << 'MQEOF_SRC_LIB_POSTTYPES_JS'
// Constantes partagées entre /annonces, /new et /annonces/[id] pour garder
// les libellés et emojis cohérents partout dans l'app.

import { Gift, Handshake, Car, Search, AlertTriangle, ShoppingCart } from 'lucide-react';

export const POST_TYPES = [
  { type: 'don', label: 'Prêt / Don', icon: Gift },
  { type: 'entraide', label: 'Entraide', icon: Handshake },
  { type: 'covoiturage', label: 'Covoiturage', icon: Car },
  { type: 'cherche', label: 'Je cherche', icon: Search },
  { type: 'achat_groupe', label: 'Achat groupé', icon: ShoppingCart },
  { type: 'alerte', label: 'Alerte quartier', icon: AlertTriangle },
];

export function getPostTypeInfo(type) {
  return POST_TYPES.find((t) => t.type === type) || { label: type, icon: Search };
}

// Formatage relatif simple en français, sans dépendance externe.
export function formatRelativeTime(dateString) {
  const date = new Date(dateString);
  const diffMs = Date.now() - date.getTime();
  const diffMin = Math.floor(diffMs / 60000);

  if (diffMin < 1) return "à l'instant";
  if (diffMin < 60) return `il y a ${diffMin} min`;
  const diffH = Math.floor(diffMin / 60);
  if (diffH < 24) return `il y a ${diffH} h`;
  const diffJ = Math.floor(diffH / 24);
  if (diffJ < 7) return `il y a ${diffJ} j`;
  return date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' });
}

MQEOF_SRC_LIB_POSTTYPES_JS

mkdir -p "src/lib"
cat > "src/lib/mapMarkerIcons.js" << 'MQEOF_SRC_LIB_MAPMARKERICONS_JS'
// Génère une image (ImageData) pour un marqueur de carte : cercle coloré +
// emoji centré. Dessiné sur un <canvas> local, donc aucune dépendance à une
// police externe/glyphes serveur — contourne complètement le bug de
// glyphes rencontré avec les couches "symbol" à texte MapLibre classiques.

export function createEmojiMarkerImage(emoji, bgColor, size = 64) {
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d');

  // Cercle de fond avec léger contour blanc.
  ctx.beginPath();
  ctx.arc(size / 2, size / 2, size / 2 - 3, 0, Math.PI * 2);
  ctx.fillStyle = bgColor;
  ctx.fill();
  ctx.lineWidth = 3;
  ctx.strokeStyle = '#FFFFFF';
  ctx.stroke();

  // Emoji centré (le rendu de police système gère nativement les emoji
  // dans un <canvas>, contrairement aux couches de texte MapLibre).
  ctx.font = `${Math.round(size * 0.5)}px sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(emoji, size / 2, size / 2 + 2);

  return ctx.getImageData(0, 0, size, size);
}

export const CATEGORY_EMOJI = {
  // Annonces
  don: { emoji: '🎁', color: '#FF5A5F' },
  entraide: { emoji: '🤝', color: '#00A699' },
  covoiturage: { emoji: '🚗', color: '#FF5A5F' },
  cherche: { emoji: '🔍', color: '#00A699' },
  achat_groupe: { emoji: '🛒', color: '#00A699' },
  alerte: { emoji: '⚠️', color: '#DC2626' },
  // Activités
  sortie: { emoji: '📍', color: '#8B5CF6' },
  musee: { emoji: '🏛️', color: '#8B5CF6' },
  sport: { emoji: '🏃', color: '#8B5CF6' },
  jeux_de_societe: { emoji: '🎲', color: '#8B5CF6' },
  // Commerces (les catégories "autre" et "sortie"/"jeux_de_societe" ne se
  // chevauchent pas dans les données réelles car kind différencie déjà
  // annonces/activités/commerces en amont).
  commerce: { emoji: '🛍️', color: '#475569' },
  restaurant: { emoji: '🍽️', color: '#475569' },
  sante: { emoji: '💊', color: '#475569' },
  loisirs: { emoji: '🎨', color: '#475569' },
  service: { emoji: '🔧', color: '#475569' },
  site_touristique: { emoji: '🏛️', color: '#475569' },
  autre: { emoji: '✨', color: '#94A3B8' },
};

MQEOF_SRC_LIB_MAPMARKERICONS_JS

mkdir -p "src/components"
cat > "src/components/VerifiedBadge.jsx" << 'MQEOF_SRC_COMPONENTS_VERIFIEDBADGE_JSX'
import { BadgeCheck } from 'lucide-react';

// Coche bleue affichée uniquement si verification_status === 'verified',
// lui-même branché sur la confirmation d'email réelle (migration 032) —
// jamais un badge décoratif sans donnée derrière.
export default function VerifiedBadge({ size = 13 }) {
  return (
    <BadgeCheck
      size={size}
      className="inline-block flex-shrink-0 fill-blue-500 text-white"
      aria-label="Compte vérifié"
    />
  );
}

MQEOF_SRC_COMPONENTS_VERIFIEDBADGE_JSX

mkdir -p "src/components"
cat > "src/components/PostCard.jsx" << 'MQEOF_SRC_COMPONENTS_POSTCARD_JSX'
import Link from 'next/link';
import { MessageCircle } from 'lucide-react';
import { getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';
import { getPlaceholderImage } from '@/lib/placeholderImages';
import FavoriteHeartButton from './FavoriteHeartButton';
import PostDistanceBadge from './PostDistanceBadge';
import VerifiedBadge from './VerifiedBadge';
import PostCardMenu from '@/app/annonces/PostCardMenu';

// Composant serveur : pas d'état, juste de l'affichage. Le cœur favori et
// le menu ⋮ sont des petits composants client importés séparément.

export default function PostCard({ post, thumbnail, author, msgCount = 0, isOwnPost, showMenu = false }) {
  const typeInfo = getPostTypeInfo(post.type);
  const image = thumbnail || getPlaceholderImage(post.type);

  return (
    <div className="overflow-hidden rounded-card bg-surface-card p-2 shadow-soft">
      <Link href={`/annonces/${post.id}`} className="block">
        <div className="relative h-24 w-full overflow-hidden rounded-card bg-surface sm:h-32">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={image} alt="" className="h-full w-full object-cover" />
          {post.reserved && (
            <span className="absolute left-2 top-2 rounded-pill bg-amber-100 px-2 py-0.5 text-[10px] font-semibold text-amber-700">
              Réservé
            </span>
          )}
          <PostDistanceBadge lat={post.lat} lng={post.lng} />
          <FavoriteHeartButton postId={post.id} />
        </div>
      </Link>

      <div className="mt-2 flex items-start justify-between gap-1">
        <span className="inline-block rounded-pill bg-surface px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-content-secondary">
          {typeInfo.label}
        </span>
        {showMenu && <PostCardMenu postId={post.id} isOwnPost={isOwnPost} reserved={post.reserved} />}
      </div>

      <Link href={`/annonces/${post.id}`} className="block">
        <p className="mt-1 line-clamp-2 text-sm font-medium text-content-primary">
          {post.title}
        </p>

        <div className="mt-1 flex items-center gap-1.5">
          <div className="flex h-[18px] w-[18px] flex-shrink-0 items-center justify-center overflow-hidden rounded-pill bg-corail/10 text-[8px] font-semibold text-corail">
            {author?.photo_visible && author?.photo_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={author.photo_url} alt="" className="h-full w-full object-cover" />
            ) : (
              (author?.display_name || '?').charAt(0).toUpperCase()
            )}
          </div>
          <span className="truncate text-[11px] text-content-secondary">
            {author?.display_name || 'Voisin'}
          </span>
          {author?.verification_status === 'verified' && <VerifiedBadge size={11} />}
        </div>

        <div className="mt-1 flex items-center justify-between text-[11px] text-content-secondary">
          <span>{formatRelativeTime(post.created_at)}</span>
          {msgCount > 0 && (
            <span className="flex items-center gap-0.5">
              <MessageCircle size={11} />
              {msgCount}
            </span>
          )}
        </div>
      </Link>
    </div>
  );
}

MQEOF_SRC_COMPONENTS_POSTCARD_JSX

mkdir -p "src/components/layout"
cat > "src/components/layout/CreateSheet.jsx" << 'MQEOF_SRC_COMPONENTS_LAYOUT_CREATESHEET_JSX'
'use client';

import { useEffect } from 'react';
import Link from 'next/link';
import { X, CalendarPlus } from 'lucide-react';
import { POST_TYPES } from '@/lib/postTypes';

const DESCRIPTIONS = {
  don: "Prêtez ou donnez un objet",
  entraide: "Proposez ou demandez de l'aide",
  covoiturage: "Proposez ou rejoignez un trajet",
  cherche: "Recherchez un objet, un service ou une personne",
  achat_groupe: "Groupez une commande avec vos voisins",
  alerte: "Signalez un problème ou informez vos voisins",
};

// Alternance corail/vert, cohérent avec le reste du design system.
const COLORS = ['text-corail', 'text-vert'];

export default function CreateSheet({ open, onClose }) {
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
      <button
        aria-label="Fermer"
        onClick={onClose}
        className="absolute inset-0 bg-black/40 transition-fast"
      />

      <div className="safe-bottom absolute bottom-0 left-0 right-0 max-h-[85vh] overflow-y-auto rounded-t-sheet bg-surface p-6 shadow-sheet">
        <div className="mx-auto mb-4 h-1 w-10 rounded-pill bg-border" />

        <div className="mb-1 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-content-primary">Créer sur Hoody</h2>
          <button
            aria-label="Fermer"
            onClick={onClose}
            className="flex h-tap w-tap items-center justify-center rounded-pill text-content-secondary hover:bg-surface-card"
          >
            <X size={20} />
          </button>
        </div>
        <p className="mb-5 text-sm text-content-secondary">Que voulez-vous faire ?</p>

        <div className="grid grid-cols-2 gap-3">
          {POST_TYPES.map((option, i) => (
            <Link
              key={option.type}
              href={`/new?type=${option.type}`}
              onClick={onClose}
              className="flex flex-col gap-2 rounded-card border border-border bg-surface-card p-3 transition-fast hover:bg-border/40 active:scale-[0.98]"
            >
              <div className="h-12 w-12 overflow-hidden rounded-card">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={`/categories/${option.type}.png`} alt="" className="h-full w-full object-cover" />
              </div>
              <div>
                <p className={`text-sm font-semibold ${COLORS[i % 2]}`}>{option.label}</p>
                <p className="mt-0.5 text-xs text-content-secondary">{DESCRIPTIONS[option.type]}</p>
              </div>
            </Link>
          ))}

          <Link
            href="/activites/new"
            onClick={onClose}
            className="flex flex-col gap-2 rounded-card border border-border bg-surface-card p-3 transition-fast hover:bg-border/40 active:scale-[0.98]"
          >
            <div className="flex h-12 w-12 items-center justify-center rounded-card bg-vert/10 text-vert">
              <CalendarPlus size={22} />
            </div>
            <div>
              <p className="text-sm font-semibold text-vert">Activité</p>
              <p className="mt-0.5 text-xs text-content-secondary">Proposez ou organisez une activité</p>
            </div>
          </Link>
        </div>
      </div>
    </div>
  );
}

MQEOF_SRC_COMPONENTS_LAYOUT_CREATESHEET_JSX

mkdir -p "src/app"
cat > "src/app/page.jsx" << 'MQEOF_SRC_APP_PAGE_JSX'
// Page d'accueil — Server Component.
//
// Direction visuelle : pastilles de catégories pleinement colorées,
// cartes horizontales avec vraies photos (illustration générique en
// secours), pile d'avatars pour les activités et les voisins.
//
// Volontairement exclu (cohérent avec la section 80 du prompt maître) :
// pas de notation/étoiles (aucun système d'avis n'existe côté base), pas
// de tri algorithmique par popularité, pas de notification-appât.

import Link from 'next/link';
import { Search, Users, Store, Map } from 'lucide-react';
import { createClient } from '@/lib/supabase/server';
import { POST_TYPES, formatRelativeTime } from '@/lib/postTypes';
import { formatEventDate } from '@/lib/eventCategories';
import AvatarStack from '@/components/AvatarStack';
import PostCard from '@/components/PostCard';

function formatEventDateBadge(dateString) {
  const date = new Date(dateString);
  return {
    day: date.toLocaleDateString('fr-FR', { weekday: 'short' }).toUpperCase().replace('.', ''),
    date: date.getDate(),
    month: date.toLocaleDateString('fr-FR', { month: 'short' }).toUpperCase().replace('.', ''),
  };
}

export default async function HomePage() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: profile } = await supabase
    .from('profiles')
    .select('display_name, quartier_id, quartiers(name, city)')
    .eq('user_id', user.id)
    .single();

  if (!profile?.quartier_id) {
    return (
      <div className="p-4">
        <div className="rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">
            Il te reste une étape avant de découvrir ton quartier.
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

  const quartierId = profile.quartier_id;
  const firstName = profile.display_name?.split(' ')[0] || null;

  const [neighborsCount, featuredAlertResult, feedResult, upcomingEventsResult, neighborPreviewResult] =
    await Promise.all([
      supabase.from('profiles').select('*', { count: 'exact', head: true }).eq('quartier_id', quartierId),
      supabase
        .from('posts')
        .select('id, title, created_at, user_id')
        .eq('quartier_id', quartierId)
        .eq('status', 'active')
        .eq('type', 'alerte')
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle(),
      supabase
        .from('posts')
        .select('id, type, title, created_at, user_id, reserved, lat, lng')
        .eq('quartier_id', quartierId)
        .eq('status', 'active')
        .neq('type', 'alerte')
        .order('created_at', { ascending: false })
        .limit(4),
      supabase
        .from('events')
        .select('id, category, title, location, event_date, max_attendees')
        .eq('quartier_id', quartierId)
        .eq('status', 'active')
        .gte('event_date', new Date().toISOString())
        .order('event_date', { ascending: true })
        .limit(3),
      supabase
        .from('profiles')
        .select('user_id, display_name, photo_url, photo_visible, verification_status')
        .eq('quartier_id', quartierId)
        .neq('map_visibility', 'off')
        .limit(4),
    ]);

  const featuredAlert = featuredAlertResult.data;
  const feed = feedResult.data || [];
  const upcomingEvents = upcomingEventsResult.data || [];
  const neighborPreview = neighborPreviewResult.data || [];

  const relevantUserIds = [
    ...new Set([featuredAlert?.user_id, ...feed.map((p) => p.user_id)].filter(Boolean)),
  ];
  const feedPostIds = feed.map((p) => p.id);
  const eventIds = upcomingEvents.map((e) => e.id);

  const [{ data: authors }, { data: images }, { data: attendeeRows }, { data: convCounts }] = await Promise.all([
    relevantUserIds.length > 0
      ? supabase.from('profiles').select('user_id, display_name, photo_url, photo_visible, verification_status').in('user_id', relevantUserIds)
      : Promise.resolve({ data: [] }),
    feedPostIds.length > 0
      ? supabase.from('post_images').select('post_id, storage_path, position').in('post_id', feedPostIds).order('position', { ascending: true })
      : Promise.resolve({ data: [] }),
    eventIds.length > 0
      ? supabase.from('event_attendees').select('event_id, user_id').in('event_id', eventIds)
      : Promise.resolve({ data: [] }),
    feedPostIds.length > 0
      ? supabase.rpc('get_conversation_counts', { p_post_ids: feedPostIds })
      : Promise.resolve({ data: [] }),
  ]);

  const authorName = Object.fromEntries((authors || []).map((a) => [a.user_id, a.display_name]));
  const authorPhoto = Object.fromEntries((authors || []).map((a) => [a.user_id, a]));
  const conversationCounts = Object.fromEntries((convCounts || []).map((c) => [c.post_id, c.count]));

  const thumbnailByPost = {};
  for (const img of images || []) {
    if (!thumbnailByPost[img.post_id]) {
      thumbnailByPost[img.post_id] = supabase.storage.from('posts').getPublicUrl(img.storage_path).data.publicUrl;
    }
  }

  // Profils des participants pour la pile d'avatars de chaque activité.
  const attendeeUserIds = [...new Set((attendeeRows || []).map((a) => a.user_id))];
  const { data: attendeeProfiles } =
    attendeeUserIds.length > 0
      ? await supabase.from('profiles').select('user_id, display_name, photo_url, photo_visible, verification_status').in('user_id', attendeeUserIds)
      : { data: [] };
  const attendeeProfileById = Object.fromEntries((attendeeProfiles || []).map((p) => [p.user_id, p]));

  const attendeesByEvent = {};
  for (const row of attendeeRows || []) {
    if (!attendeesByEvent[row.event_id]) attendeesByEvent[row.event_id] = [];
    const p = attendeeProfileById[row.user_id];
    if (p) attendeesByEvent[row.event_id].push(p);
  }

  return (
    <div className="flex flex-col p-4">
      <h1 className="text-xl font-semibold text-content-primary">
        {firstName ? `Bonjour ${firstName} 👋` : 'Bonjour 👋'}
      </h1>
      <p className="mt-1 text-sm text-content-secondary">
        Ravi de te revoir dans ton quartier.
      </p>

      <Link
        href="/annonces"
        className="mt-5 flex items-center gap-3 rounded-pill border border-border bg-surface-card px-4 py-3 shadow-soft transition-fast hover:shadow-none"
      >
        <Search size={17} className="text-content-secondary" />
        <span className="text-sm text-content-secondary">Rechercher dans le quartier</span>
      </Link>

      <Link
        href="/carte"
        className="mt-3 flex items-center justify-between rounded-card bg-corail/10 p-4 shadow-soft transition-fast hover:shadow-none"
      >
        <div className="flex items-center gap-3">
          <span className="flex h-10 w-10 items-center justify-center rounded-pill bg-corail/15 text-corail">
            <Map size={18} />
          </span>
          <div>
            <p className="text-sm font-semibold text-content-primary">Explorer mon quartier</p>
            <p className="text-xs text-content-secondary">Annonces, activités et commerces sur la carte</p>
          </div>
        </div>
        <span className="text-xs font-medium text-corail">Ouvrir →</span>
      </Link>

      {/* Catégories — vraies illustrations, grille 3 colonnes (2 lignes, pas de scroll) */}
      <div className="mt-5 grid grid-cols-3 gap-2.5">
        {POST_TYPES.map((cat) => (
          <Link
            key={cat.type}
            href={`/annonces?type=${cat.type}`}
            className="overflow-hidden rounded-card shadow-soft transition-fast active:scale-95"
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={`/categories/${cat.type}.png`}
              alt={cat.label}
              className="aspect-square w-full object-cover"
            />
          </Link>
        ))}
      </div>

      {/* Alerte la plus récente */}
      {featuredAlert && (
        <Link
          href={`/annonces/${featuredAlert.id}`}
          className="mt-5 flex items-center gap-3 rounded-card bg-corail/10 p-4 shadow-soft transition-fast hover:shadow-none"
        >
          <div className="h-10 w-10 flex-shrink-0 overflow-hidden rounded-pill">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/categories/alerte.png" alt="" className="h-full w-full object-cover" />
          </div>
          <div className="min-w-0">
            <p className="text-sm font-medium text-content-primary">{featuredAlert.title}</p>
            <p className="mt-0.5 text-xs text-content-secondary">
              Signalé par {authorName[featuredAlert.user_id] || 'un voisin'} ·{' '}
              {formatRelativeTime(featuredAlert.created_at)}
            </p>
          </div>
        </Link>
      )}

      {/* Près de chez toi — grille de 3, triée par date de publication */}
      {feed.length > 0 && (
        <section className="mt-7">
          <div className="mb-3 flex items-baseline justify-between">
            <h2 className="text-base font-semibold text-content-primary">Près de chez toi</h2>
            <Link href="/annonces" className="text-xs text-content-secondary">
              Voir tout
            </Link>
          </div>

          <div className="grid grid-cols-2 gap-3">
            {feed.map((post) => (
              <PostCard
                key={post.id}
                post={post}
                thumbnail={thumbnailByPost[post.id]}
                author={authorPhoto[post.user_id]}
                msgCount={conversationCounts[post.id] || 0}
              />
            ))}
          </div>

          <Link
            href="/annonces"
            className="mt-4 block w-full rounded-pill border border-border py-2.5 text-center text-sm font-medium text-content-primary transition-fast hover:border-content-secondary"
          >
            Voir plus
          </Link>
        </section>
      )}

      {feed.length === 0 && !featuredAlert && (
        <div className="mt-7 rounded-card border border-border bg-surface-card p-6 text-center text-sm text-content-secondary">
          Rien de nouveau pour l'instant.
          <div className="mt-2">
            <Link href="/new" className="font-medium text-corail">
              Sois le premier à publier →
            </Link>
          </div>
        </div>
      )}

      {/* Prochaines activités — badge date + pile de participants */}
      {upcomingEvents.length > 0 && (
        <section className="mt-7">
          <div className="mb-3 flex items-baseline justify-between">
            <h2 className="text-base font-semibold text-content-primary">Prochaines activités</h2>
            <Link href="/activites" className="text-xs text-content-secondary">
              Voir tout
            </Link>
          </div>

          <div className="flex flex-col gap-3">
            {upcomingEvents.map((event) => {
              const badge = formatEventDateBadge(event.event_date);
              const attendees = attendeesByEvent[event.id] || [];
              return (
                <Link
                  key={event.id}
                  href={`/activites/${event.id}`}
                  className="flex gap-3 rounded-card border border-border bg-surface-card p-3 shadow-soft transition-fast hover:shadow-none"
                >
                  <div className="flex h-14 w-14 flex-shrink-0 flex-col items-center justify-center rounded-card bg-surface">
                    <span className="text-[10px] font-medium text-corail">{badge.day}</span>
                    <span className="text-lg font-semibold leading-none text-content-primary">{badge.date}</span>
                    <span className="text-[10px] text-content-secondary">{badge.month}</span>
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-medium text-content-primary">{event.title}</p>
                    <p className="mt-0.5 truncate text-xs text-content-secondary">
                      {new Date(event.event_date).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}
                      {event.location ? ` · ${event.location}` : ''}
                    </p>
                    {attendees.length > 0 && (
                      <div className="mt-1.5">
                        <AvatarStack people={attendees} size={20} />
                      </div>
                    )}
                  </div>
                </Link>
              );
            })}
          </div>
        </section>
      )}

      {/* Résumé communauté — deux cartes avec illustration de fond */}
      <div className="mt-7 grid grid-cols-2 gap-3">
        <Link
          href="/voisins"
          className="relative flex h-32 flex-col justify-end overflow-hidden rounded-card p-3 shadow-soft"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/placeholders/voisins-card.jpg"
            alt=""
            className="absolute inset-0 h-full w-full object-cover"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-black/55 to-transparent" />
          <div className="relative">
            <AvatarStack people={neighborPreview} size={22} />
            <p className="mt-1.5 text-xs font-medium text-white">
              {neighborsCount.count ?? 0} voisins peuvent aider
            </p>
          </div>
        </Link>

        <Link
          href="/commerces"
          className="relative flex h-32 flex-col justify-end overflow-hidden rounded-card p-3 shadow-soft"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/placeholders/commerce-card.jpg"
            alt=""
            className="absolute inset-0 h-full w-full object-cover"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-black/55 to-transparent" />
          <div className="relative flex items-center gap-1.5">
            <Store size={14} className="text-white" />
            <p className="text-xs font-medium text-white">Soutenons nos commerces</p>
          </div>
        </Link>
      </div>
    </div>
  );
}

MQEOF_SRC_APP_PAGE_JSX

mkdir -p "src/app/annonces"
cat > "src/app/annonces/page.jsx" << 'MQEOF_SRC_APP_ANNONCES_PAGE_JSX'
// Server Component : liste des annonces du quartier de l'utilisateur,
// filtrable par type via ?type=don|entraide|covoiturage|cherche|alerte.
// Grille 2 colonnes, même style de carte que l'accueil.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { POST_TYPES } from '@/lib/postTypes';
import PostCard from '@/components/PostCard';
import { Map } from 'lucide-react';

export default async function AnnoncesPage({ searchParams }) {
  const params = await searchParams;
  const activeType = params?.type;

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
            Termine d'abord ton inscription pour voir les annonces de ton quartier.
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

  let query = supabase
    .from('posts')
    .select('id, type, title, description, approx_zone, created_at, user_id, reserved, lat, lng')
    .eq('quartier_id', profile.quartier_id)
    .eq('status', 'active')
    .order('created_at', { ascending: false })
    .limit(30);

  if (activeType) {
    query = query.eq('type', activeType);
  }

  const { data: posts, error } = await query;

  let authorInfo = {};
  let thumbnailByPost = {};
  let conversationCounts = {};
  if (posts?.length > 0) {
    const userIds = [...new Set(posts.map((p) => p.user_id))];
    const postIds = posts.map((p) => p.id);

    const [{ data: authors }, { data: images }, { data: counts }] = await Promise.all([
      supabase.from('profiles').select('user_id, display_name, photo_url, photo_visible, verification_status').in('user_id', userIds),
      supabase
        .from('post_images')
        .select('post_id, storage_path, position')
        .in('post_id', postIds)
        .order('position', { ascending: true }),
      supabase.rpc('get_conversation_counts', { p_post_ids: postIds }),
    ]);

    authorInfo = Object.fromEntries((authors || []).map((a) => [a.user_id, a]));

    for (const img of images || []) {
      if (!thumbnailByPost[img.post_id]) {
        thumbnailByPost[img.post_id] = supabase.storage.from('posts').getPublicUrl(img.storage_path).data.publicUrl;
      }
    }

    conversationCounts = Object.fromEntries((counts || []).map((c) => [c.post_id, c.count]));
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      {/* Filtres de catégorie */}
      <Link
        href="/carte"
        className="flex items-center justify-center gap-1.5 rounded-pill border border-border bg-surface-card py-2 text-sm font-medium text-content-primary transition-fast hover:bg-border/20"
      >
        <Map size={15} /> Voir sur la carte
      </Link>

      <div className="grid grid-cols-3 gap-2">
        <FilterTile href="/annonces" label="Toutes" active={!activeType} />
        {POST_TYPES.map((cat) => (
          <FilterTile
            key={cat.type}
            href={`/annonces?type=${cat.type}`}
            image={`/categories/${cat.type}.png`}
            active={activeType === cat.type}
          />
        ))}
      </div>

      {error && (
        <p className="text-sm text-corail">
          Impossible de charger les annonces pour le moment.
        </p>
      )}

      {!error && posts?.length === 0 && (
        <div className="mt-6 rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">
            Aucune annonce {activeType ? `dans cette catégorie` : ''} pour l'instant.
          </p>
          <p className="mt-1 text-sm text-content-secondary">
            Sois le premier à publier quelque chose dans ton quartier !
          </p>
          <Link
            href={activeType ? `/new?type=${activeType}` : '/new'}
            className="mt-4 inline-block h-tap rounded-pill bg-corail px-6 py-3 font-medium text-white transition-fast hover:bg-corail-hover"
          >
            Publier une annonce
          </Link>
        </div>
      )}

      <div className="grid grid-cols-2 gap-3">
        {posts?.map((post) => (
          <PostCard
            key={post.id}
            post={post}
            thumbnail={thumbnailByPost[post.id]}
            author={authorInfo[post.user_id]}
            msgCount={conversationCounts[post.id] || 0}
            isOwnPost={post.user_id === user.id}
            showMenu
          />
        ))}
      </div>
    </div>
  );
}

function FilterTile({ href, label, image, active }) {
  return (
    <Link
      href={href}
      className={`relative overflow-hidden rounded-card transition-fast ${
        active ? 'ring-2 ring-corail ring-offset-2 ring-offset-surface' : ''
      }`}
    >
      {image ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={image} alt={label} className="aspect-square w-full object-cover" />
      ) : (
        <div
          className={`flex aspect-square w-full items-center justify-center text-sm font-semibold ${
            active ? 'bg-corail text-white' : 'bg-surface-card text-content-primary'
          }`}
        >
          Toutes
        </div>
      )}
    </Link>
  );
}

MQEOF_SRC_APP_ANNONCES_PAGE_JSX

mkdir -p "src/app/annonces/[id]"
cat > "src/app/annonces/[id]/page.jsx" << 'MQEOF_SRC_APP_ANNONCES_ID_PAGE_JSX'
// Server Component : détail d'une annonce. La policy RLS
// "posts_select_own_quartier" garantit déjà qu'on ne peut pas voir
// l'annonce d'un autre quartier.
//
// NOTE DE PORTÉE : plusieurs éléments d'inspiration (notes/avis, "% de
// prêts honorés", historique d'emprunts, réservation avec calendrier) ne
// sont pas construits — ce sont de vraies fonctionnalités à part entière,
// pas juste de la mise en page. Ce qui est affiché ici reflète toujours de
// vraies données.

import Link from 'next/link';
import Image from 'next/image';
import { notFound } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';
import { getPlaceholderImage } from '@/lib/placeholderImages';
import { getLevel } from '@/lib/levels';
import VerifiedBadge from '@/components/VerifiedBadge';
import PostHeaderActions from './PostHeaderActions';
import ContactActions from './ContactActions';

export default async function AnnonceDetailPage({ params }) {
  const { id } = await params;
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: post, error } = await supabase
    .from('posts')
    .select('id, type, title, description, availability, approx_zone, created_at, user_id, reserved')
    .eq('id', id)
    .single();

  if (error || !post) {
    notFound();
  }

  const { data: authorProfile } = await supabase
    .from('profiles')
    .select('display_name, points, photo_url, photo_visible, verification_status')
    .eq('user_id', post.user_id)
    .single();

  const { data: images } = await supabase
    .from('post_images')
    .select('storage_path, position')
    .eq('post_id', post.id)
    .order('position', { ascending: true });

  const photoUrls = (images || []).map(
    (img) => supabase.storage.from('posts').getPublicUrl(img.storage_path).data.publicUrl
  );
  const heroImage = photoUrls[0] || getPlaceholderImage(post.type);

  const typeInfo = getPostTypeInfo(post.type);
  const isOwnPost = post.user_id === user.id;
  const authorName = authorProfile?.display_name || 'Voisin';
  const authorInitial = authorName.charAt(0).toUpperCase();
  const level = getLevel(authorProfile?.points || 0);

  const { data: otherPosts } = await supabase
    .from('posts')
    .select('id, title, type')
    .eq('user_id', post.user_id)
    .eq('status', 'active')
    .neq('id', post.id)
    .limit(3);

  return (
    <div className="flex flex-col gap-5 pb-4">
      {/* Photo pleine largeur avec retour/favori/partage en overlay */}
      <div className="relative h-72 w-full">
        <Image src={heroImage} alt="" fill sizes="100vw" className="object-cover" priority />
        {post.reserved && (
          <span className="absolute left-3 top-14 rounded-pill bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-700 shadow-soft">
            Réservé
          </span>
        )}
        <PostHeaderActions postId={post.id} postTitle={post.title} />
      </div>

      <div className="flex flex-col gap-5 px-4">
        <div>
          <span className="inline-block rounded-pill bg-surface-card px-3 py-1 text-xs font-semibold uppercase tracking-wide text-content-secondary">
            {typeInfo.label}
          </span>
          <h1 className="mt-2 text-xl font-semibold text-content-primary">{post.title}</h1>
          {post.description && (
            <p className="mt-1 text-sm text-content-secondary">{post.description}</p>
          )}
        </div>

        {/* Auteur + niveau (factuel, pas de note/avis — pas de systeme de notation) */}
        <Link
          href={isOwnPost ? '/profile' : '#'}
          className="flex items-center gap-3 rounded-card border border-border bg-surface-card p-3"
        >
          <div className="flex h-11 w-11 flex-shrink-0 items-center justify-center overflow-hidden rounded-pill bg-corail/10 font-semibold text-corail">
            {authorProfile?.photo_visible && authorProfile?.photo_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={authorProfile.photo_url} alt="" className="h-full w-full object-cover" />
            ) : (
              authorInitial
            )}
          </div>
          <div className="min-w-0 flex-1">
            <p className="flex items-center gap-1 font-medium text-content-primary">
              {authorName}
              {authorProfile?.verification_status === 'verified' && <VerifiedBadge />}
            </p>
            <p className="text-xs text-content-secondary">{level.label}</p>
          </div>
        </Link>

        {/* Infos structurées — uniquement des champs réels */}
        {(post.availability || post.approx_zone) && (
          <div className="grid grid-cols-2 gap-3 rounded-card border border-border bg-surface-card p-4">
            {post.availability && (
              <div>
                <p className="text-xs text-content-secondary">Disponibilité</p>
                <p className="mt-0.5 text-sm font-medium text-content-primary">{post.availability}</p>
              </div>
            )}
            {post.approx_zone && (
              <div>
                <p className="text-xs text-content-secondary">Zone</p>
                <p className="mt-0.5 text-sm font-medium text-content-primary">{post.approx_zone}</p>
              </div>
            )}
            <div>
              <p className="text-xs text-content-secondary">Publié</p>
              <p className="mt-0.5 text-sm font-medium text-content-primary">
                {formatRelativeTime(post.created_at)}
              </p>
            </div>
          </div>
        )}

        {!isOwnPost && (
          <>
            {post.reserved && (
              <p className="text-center text-xs text-amber-700">
                Cette annonce a été marquée comme réservée — tu peux quand même contacter au
                cas où ça ne se concrétiserait pas.
              </p>
            )}
            <ContactActions postId={post.id} postAuthorId={post.user_id} />
          </>
        )}

        {isOwnPost && (
          <div className="rounded-card border border-border bg-surface-card p-4 text-center text-sm text-content-secondary">
            C'est ta propre annonce.{' '}
            <Link href="/mes-annonces" className="font-medium text-corail">
              Gérer mes annonces
            </Link>
          </div>
        )}

        {otherPosts?.length > 0 && (
          <div>
            <h2 className="mb-2 text-sm font-medium text-content-secondary">
              Autres annonces de {authorName}
            </h2>
            <div className="flex flex-col gap-2">
              {otherPosts.map((op) => {
                const OpIcon = getPostTypeInfo(op.type).icon;
                return (
                  <Link
                    key={op.id}
                    href={`/annonces/${op.id}`}
                    className="flex items-center gap-2 rounded-card border border-border bg-surface-card p-3 text-sm text-content-primary transition-fast hover:bg-border/30"
                  >
                    <OpIcon size={16} /> {op.title}
                  </Link>
                );
              })}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

MQEOF_SRC_APP_ANNONCES_ID_PAGE_JSX

mkdir -p "src/app/profile"
cat > "src/app/profile/page.jsx" << 'MQEOF_SRC_APP_PROFILE_PAGE_JSX'
'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { getLevel } from '@/lib/levels';
import { Settings, Camera, ShieldCheck, Package, CalendarDays, Heart, Store } from 'lucide-react';
import VerifiedBadge from '@/components/VerifiedBadge';

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
        .select('display_name, photo_url, bio, role, points, quartier_id, created_at, verification_status')
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

          <p className="mt-3 flex items-center gap-1 text-lg font-semibold text-content-primary">
            {profile?.display_name || 'Voisin'}
            {profile?.verification_status === 'verified' && <VerifiedBadge size={15} />}
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
          <Link href="/sondages" className="rounded-card px-3 py-2 text-sm text-content-primary hover:bg-surface">
            Sondages de quartier
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

mkdir -p "src/app/voisins"
cat > "src/app/voisins/page.jsx" << 'MQEOF_SRC_APP_VOISINS_PAGE_JSX'
// Server Component : annuaire des voisins du quartier.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import VerifiedBadge from '@/components/VerifiedBadge';

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

  // On respecte map_visibility = 'off' comme un choix général de discrétion :
  // quelqu'un qui a explicitement demandé à ne pas apparaître ne doit pas se
  // retrouver listé ici non plus. Limite à 50 : mesure simple anti-scraping
  // (section 83) en attendant une vraie pagination si le quartier grossit.
  const { data: neighbors, error } = await supabase
    .from('profiles')
    .select('user_id, display_name, created_at, map_visibility, photo_url, photo_visible, verification_status')
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
              <div className="flex h-10 w-10 flex-shrink-0 items-center justify-center overflow-hidden rounded-pill bg-corail/10 font-semibold text-corail">
                {neighbor.photo_visible && neighbor.photo_url ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={neighbor.photo_url} alt="" className="h-full w-full object-cover" />
                ) : (
                  initial
                )}
              </div>
              <div className="min-w-0 flex-1">
                <p className="flex items-center gap-1 truncate font-medium text-content-primary">
                  {neighbor.display_name || 'Voisin'} {isMe && '(toi)'}
                  {neighbor.verification_status === 'verified' && <VerifiedBadge size={12} />}
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

mkdir -p "src/app/settings"
cat > "src/app/settings/page.jsx" << 'MQEOF_SRC_APP_SETTINGS_PAGE_JSX'
'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';

export default function SettingsPage() {
  const router = useRouter();
  const [currentEmail, setCurrentEmail] = useState('');

  const [newEmail, setNewEmail] = useState('');
  const [emailSubmitting, setEmailSubmitting] = useState(false);
  const [emailError, setEmailError] = useState('');
  const [emailSuccess, setEmailSuccess] = useState('');

  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [passwordSubmitting, setPasswordSubmitting] = useState(false);
  const [passwordError, setPasswordError] = useState('');
  const [passwordSuccess, setPasswordSuccess] = useState('');

  useEffect(() => {
    async function load() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        router.push('/login');
        return;
      }
      setCurrentEmail(user.email || '');
    }
    load();
  }, [router]);

  async function handleEmailSubmit(e) {
    e.preventDefault();
    setEmailError('');
    setEmailSuccess('');

    if (!newEmail.trim() || newEmail === currentEmail) {
      setEmailError('Indique une nouvelle adresse email différente.');
      return;
    }

    setEmailSubmitting(true);
    const { error } = await supabase.auth.updateUser({ email: newEmail.trim() });
    setEmailSubmitting(false);

    if (error) {
      setEmailError("Impossible de changer l'email. Réessaie.");
      return;
    }

    setEmailSuccess('Vérifie ta nouvelle boîte mail pour confirmer le changement.');
    setNewEmail('');
  }

  async function handlePasswordSubmit(e) {
    e.preventDefault();
    setPasswordError('');
    setPasswordSuccess('');

    if (newPassword.length < 8) {
      setPasswordError('Le mot de passe doit contenir au moins 8 caractères.');
      return;
    }
    if (newPassword !== confirmPassword) {
      setPasswordError('Les deux mots de passe ne correspondent pas.');
      return;
    }

    setPasswordSubmitting(true);
    const { error } = await supabase.auth.updateUser({ password: newPassword });
    setPasswordSubmitting(false);

    if (error) {
      setPasswordError('Impossible de changer le mot de passe. Réessaie.');
      return;
    }

    setPasswordSuccess('Mot de passe mis à jour.');
    setNewPassword('');
    setConfirmPassword('');
  }

  return (
    <div className="flex flex-col gap-6 p-4">
      <div>
        <Link href="/profile" className="text-sm font-medium text-content-secondary">
          ← Profil
        </Link>
        <h1 className="mt-1 text-xl font-semibold text-content-primary">Paramètres</h1>
      </div>

      <section className="rounded-card border border-border bg-surface-card p-4">
        <h2 className="mb-1 text-sm font-semibold text-content-primary">Email</h2>
        <p className="mb-3 text-xs text-content-secondary">Actuel : {currentEmail}</p>

        <form onSubmit={handleEmailSubmit} className="flex flex-col gap-3">
          <input
            type="email"
            value={newEmail}
            onChange={(e) => setNewEmail(e.target.value)}
            placeholder="Nouvelle adresse email"
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
          {emailError && <p className="text-sm text-corail">{emailError}</p>}
          {emailSuccess && <p className="text-sm text-vert">{emailSuccess}</p>}
          <button
            type="submit"
            disabled={emailSubmitting}
            className="h-tap w-full rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface disabled:opacity-60"
          >
            {emailSubmitting ? 'Envoi...' : "Changer l'email"}
          </button>
        </form>
      </section>

      <section className="rounded-card border border-border bg-surface-card p-4">
        <h2 className="mb-3 text-sm font-semibold text-content-primary">Mot de passe</h2>

        <form onSubmit={handlePasswordSubmit} className="flex flex-col gap-3">
          <input
            type="password"
            value={newPassword}
            onChange={(e) => setNewPassword(e.target.value)}
            placeholder="Nouveau mot de passe"
            minLength={8}
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
          <input
            type="password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            placeholder="Confirmer le mot de passe"
            minLength={8}
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
          {passwordError && <p className="text-sm text-corail">{passwordError}</p>}
          {passwordSuccess && <p className="text-sm text-vert">{passwordSuccess}</p>}
          <button
            type="submit"
            disabled={passwordSubmitting}
            className="h-tap w-full rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface disabled:opacity-60"
          >
            {passwordSubmitting ? 'Mise à jour...' : 'Changer le mot de passe'}
          </button>
        </form>
      </section>

      <Link
        href="/lieux-surveilles"
        className="rounded-card border border-border bg-surface-card p-4 text-center text-sm font-medium text-content-primary hover:bg-surface"
      >
        Lieux surveillés (alertes géolocalisées) →
      </Link>

      <Link
        href="/profile/edit"
        className="rounded-card border border-border bg-surface-card p-4 text-center text-sm font-medium text-content-primary hover:bg-surface"
      >
        Modifier mon profil (nom, bio, photo, confidentialité) →
      </Link>
    </div>
  );
}

MQEOF_SRC_APP_SETTINGS_PAGE_JSX

mkdir -p "src/app/notifications"
cat > "src/app/notifications/page.jsx" << 'MQEOF_SRC_APP_NOTIFICATIONS_PAGE_JSX'
'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { formatRelativeTime } from '@/lib/postTypes';
import { Bell, MessageCircle, CalendarCheck, CalendarX, UserPlus, MapPin } from 'lucide-react';

const ICONS = {
  message: MessageCircle,
  event_join: CalendarCheck,
  event_cancelled: CalendarX,
  invitation_used: UserPlus,
  watched_alert: MapPin,
};

export default function NotificationsPage() {
  const router = useRouter();
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(true);

  async function load() {
    const { data } = await supabase
      .from('notifications')
      .select('id, type, title, body, link, read_at, created_at')
      .order('created_at', { ascending: false })
      .limit(50);
    setNotifications(data || []);
    setLoading(false);
  }

  useEffect(() => {
    load();
  }, []);

  async function handleClick(notif) {
    if (!notif.read_at) {
      await supabase.from('notifications').update({ read_at: new Date().toISOString() }).eq('id', notif.id);
    }
    if (notif.link) router.push(notif.link);
  }

  async function handleMarkAllRead() {
    await supabase.rpc('mark_all_notifications_read');
    load();
  }

  const hasUnread = notifications.some((n) => !n.read_at);

  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-content-primary">Notifications</h1>
        {hasUnread && (
          <button onClick={handleMarkAllRead} className="text-sm font-medium text-corail">
            Tout marquer comme lu
          </button>
        )}
      </div>

      {loading && <div className="skeleton h-16 w-full" />}

      {!loading && notifications.length === 0 && (
        <div className="rounded-card border border-border bg-surface-card p-6 text-center text-sm text-content-secondary">
          <Bell size={22} className="mx-auto mb-2 text-content-secondary" />
          Aucune notification pour l'instant.
        </div>
      )}

      <div className="flex flex-col gap-2">
        {notifications.map((notif) => {
          const Icon = ICONS[notif.type] || Bell;
          return (
            <button
              key={notif.id}
              onClick={() => handleClick(notif)}
              className={`flex w-full items-start gap-3 rounded-card border p-3 text-left transition-fast hover:bg-border/20 ${
                notif.read_at ? 'border-border bg-surface-card' : 'border-corail/30 bg-corail/5'
              }`}
            >
              <div className="mt-0.5 flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-pill bg-surface text-content-secondary">
                <Icon size={16} />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-sm font-medium text-content-primary">{notif.title}</p>
                {notif.body && (
                  <p className="mt-0.5 line-clamp-1 text-sm text-content-secondary">{notif.body}</p>
                )}
                <p className="mt-0.5 text-xs text-content-secondary">
                  {formatRelativeTime(notif.created_at)}
                </p>
              </div>
              {!notif.read_at && <div className="mt-1.5 h-2 w-2 flex-shrink-0 rounded-pill bg-corail" />}
            </button>
          );
        })}
      </div>
    </div>
  );
}

MQEOF_SRC_APP_NOTIFICATIONS_PAGE_JSX

mkdir -p "src/app/sondages"
cat > "src/app/sondages/page.jsx" << 'MQEOF_SRC_APP_SONDAGES_PAGE_JSX'
// Server Component : sondages actifs du quartier.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import PollCard from './PollCard';

export default async function SondagesPage() {
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
            Termine d'abord ton inscription pour voir les sondages de ton quartier.
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

  const { data: polls } = await supabase
    .from('polls')
    .select('id, question, created_at, status')
    .eq('quartier_id', profile.quartier_id)
    .eq('status', 'active')
    .order('created_at', { ascending: false })
    .limit(20);

  const pollIds = (polls || []).map((p) => p.id);

  const [{ data: allOptions }, { data: myVotes }] = await Promise.all([
    pollIds.length > 0
      ? supabase.from('poll_options').select('id, poll_id, label, position').in('poll_id', pollIds).order('position', { ascending: true })
      : Promise.resolve({ data: [] }),
    pollIds.length > 0
      ? supabase.from('poll_votes').select('poll_id, option_id').eq('user_id', user.id).in('poll_id', pollIds)
      : Promise.resolve({ data: [] }),
  ]);

  const optionsByPoll = {};
  for (const opt of allOptions || []) {
    if (!optionsByPoll[opt.poll_id]) optionsByPoll[opt.poll_id] = [];
    optionsByPoll[opt.poll_id].push(opt);
  }

  const myVoteByPoll = Object.fromEntries((myVotes || []).map((v) => [v.poll_id, v.option_id]));

  // Résultats par sondage (fonction dédiée, agrégat uniquement).
  const resultsByPoll = {};
  for (const pollId of pollIds) {
    const { data: counts } = await supabase.rpc('get_poll_results', { p_poll_id: pollId });
    resultsByPoll[pollId] = Object.fromEntries((counts || []).map((c) => [c.option_id, Number(c.votes)]));
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-content-primary">Sondages</h1>
        <Link
          href="/sondages/new"
          className="rounded-pill bg-corail px-4 py-2 text-sm font-medium text-white transition-fast hover:bg-corail-hover"
        >
          Créer
        </Link>
      </div>

      {(!polls || polls.length === 0) && (
        <div className="rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">Aucun sondage pour l'instant.</p>
          <p className="mt-1 text-sm text-content-secondary">
            Pose une question à tes voisins pour organiser quelque chose ensemble.
          </p>
        </div>
      )}

      <div className="flex flex-col gap-3">
        {polls?.map((poll) => (
          <PollCard
            key={poll.id}
            poll={poll}
            options={optionsByPoll[poll.id] || []}
            results={resultsByPoll[poll.id] || {}}
            myVoteOptionId={myVoteByPoll[poll.id] || null}
          />
        ))}
      </div>
    </div>
  );
}

MQEOF_SRC_APP_SONDAGES_PAGE_JSX

mkdir -p "src/app/sondages"
cat > "src/app/sondages/PollCard.jsx" << 'MQEOF_SRC_APP_SONDAGES_POLLCARD_JSX'
'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';

export default function PollCard({ poll, options, results, myVoteOptionId }) {
  const router = useRouter();
  const [voting, setVoting] = useState(false);
  const [localVoteId, setLocalVoteId] = useState(myVoteOptionId);

  const totalVotes = Object.values(results).reduce((sum, n) => sum + n, 0);
  const hasVoted = !!localVoteId;

  async function handleVote(optionId) {
    if (voting || hasVoted) return;
    setVoting(true);

    const { data: { user } } = await supabase.auth.getUser();
    const { error } = await supabase
      .from('poll_votes')
      .insert({ poll_id: poll.id, option_id: optionId, user_id: user.id });

    setVoting(false);

    if (!error) {
      setLocalVoteId(optionId);
      router.refresh();
    }
  }

  return (
    <div className="rounded-card border border-border bg-surface-card p-4 shadow-soft">
      <p className="font-medium text-content-primary">{poll.question}</p>
      <p className="mt-0.5 text-xs text-content-secondary">
        {totalVotes} vote{totalVotes > 1 ? 's' : ''}
      </p>

      <div className="mt-3 flex flex-col gap-2">
        {options.map((option) => {
          const count = results[option.id] || 0;
          const pct = totalVotes > 0 ? Math.round((count / totalVotes) * 100) : 0;
          const isMine = localVoteId === option.id;

          if (hasVoted) {
            return (
              <div key={option.id} className="relative overflow-hidden rounded-card bg-surface">
                <div
                  className={`absolute inset-y-0 left-0 ${isMine ? 'bg-corail/20' : 'bg-border/60'}`}
                  style={{ width: `${pct}%` }}
                />
                <div className="relative flex items-center justify-between px-3 py-2 text-sm">
                  <span className={isMine ? 'font-medium text-corail' : 'text-content-primary'}>
                    {option.label} {isMine && '✓'}
                  </span>
                  <span className="text-content-secondary">{pct}%</span>
                </div>
              </div>
            );
          }

          return (
            <button
              key={option.id}
              onClick={() => handleVote(option.id)}
              disabled={voting}
              className="rounded-card border border-border bg-surface px-3 py-2 text-left text-sm text-content-primary transition-fast hover:border-corail hover:bg-corail/5 disabled:opacity-60"
            >
              {option.label}
            </button>
          );
        })}
      </div>
    </div>
  );
}

MQEOF_SRC_APP_SONDAGES_POLLCARD_JSX

mkdir -p "src/app/sondages/new"
cat > "src/app/sondages/new/page.jsx" << 'MQEOF_SRC_APP_SONDAGES_NEW_PAGE_JSX'
'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { Plus, X } from 'lucide-react';

const MAX_OPTIONS = 5;

export default function NewPollPage() {
  const router = useRouter();
  const [quartierId, setQuartierId] = useState(null);
  const [loadingProfile, setLoadingProfile] = useState(true);

  const [question, setQuestion] = useState('');
  const [options, setOptions] = useState(['', '']);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const hasSubmittedRef = useRef(false);

  useEffect(() => {
    async function load() {
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
    load();
  }, [router]);

  function updateOption(index, value) {
    setOptions((prev) => prev.map((o, i) => (i === index ? value : o)));
  }

  function addOption() {
    if (options.length < MAX_OPTIONS) setOptions((prev) => [...prev, '']);
  }

  function removeOption(index) {
    if (options.length > 2) setOptions((prev) => prev.filter((_, i) => i !== index));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');

    if (hasSubmittedRef.current) return;

    const cleanOptions = options.map((o) => o.trim()).filter(Boolean);
    if (!question.trim()) {
      setError('La question est obligatoire.');
      return;
    }
    if (cleanOptions.length < 2) {
      setError('Il faut au moins 2 choix.');
      return;
    }

    hasSubmittedRef.current = true;
    setSubmitting(true);

    const { data: { user } } = await supabase.auth.getUser();

    const { data: poll, error: pollError } = await supabase
      .from('polls')
      .insert({ quartier_id: quartierId, user_id: user.id, question: question.trim() })
      .select('id')
      .single();

    if (pollError || !poll) {
      setSubmitting(false);
      hasSubmittedRef.current = false;
      setError('Une erreur est survenue. Réessaie.');
      return;
    }

    const { error: optionsError } = await supabase.from('poll_options').insert(
      cleanOptions.map((label, i) => ({ poll_id: poll.id, label, position: i }))
    );

    setSubmitting(false);

    if (optionsError) {
      setError('Le sondage a été créé mais les choix ont échoué. Contacte le support.');
      return;
    }

    router.push('/sondages');
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
      <h1 className="mb-1 text-xl font-semibold text-content-primary">Créer un sondage</h1>
      <p className="mb-6 text-sm text-content-secondary">Pose une question à tout ton quartier.</p>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <div>
          <label htmlFor="question" className="mb-1 block text-sm font-medium text-content-primary">
            Question
          </label>
          <input
            id="question"
            type="text"
            required
            maxLength={200}
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
            placeholder="Ex : Quel jour pour la fête des voisins ?"
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium text-content-primary">Choix</label>
          <div className="flex flex-col gap-2">
            {options.map((option, i) => (
              <div key={i} className="flex items-center gap-2">
                <input
                  type="text"
                  maxLength={100}
                  value={option}
                  onChange={(e) => updateOption(i, e.target.value)}
                  placeholder={`Choix ${i + 1}`}
                  className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
                />
                {options.length > 2 && (
                  <button
                    type="button"
                    onClick={() => removeOption(i)}
                    aria-label="Retirer ce choix"
                    className="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-pill text-content-secondary hover:bg-surface-card"
                  >
                    <X size={16} />
                  </button>
                )}
              </div>
            ))}
          </div>
          {options.length < MAX_OPTIONS && (
            <button
              type="button"
              onClick={addOption}
              className="mt-2 flex items-center gap-1.5 text-sm font-medium text-corail"
            >
              <Plus size={15} /> Ajouter un choix
            </button>
          )}
        </div>

        {error && <p className="text-sm text-corail">{error}</p>}

        <button
          type="submit"
          disabled={submitting}
          className="mt-2 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
        >
          {submitting ? 'Publication...' : 'Publier le sondage'}
        </button>
      </form>
    </div>
  );
}

MQEOF_SRC_APP_SONDAGES_NEW_PAGE_JSX

mkdir -p "src/app/lieux-surveilles"
cat > "src/app/lieux-surveilles/page.jsx" << 'MQEOF_SRC_APP_LIEUX-SURVEILLES_PAGE_JSX'
'use client';

import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';
import { MapPin, Trash2 } from 'lucide-react';

export default function WatchedLocationsPage() {
  const [locations, setLocations] = useState([]);
  const [loading, setLoading] = useState(true);

  const [label, setLabel] = useState('');
  const [query, setQuery] = useState('');
  const [suggestions, setSuggestions] = useState([]);
  const [selectedCoords, setSelectedCoords] = useState(null);
  const [radius, setRadius] = useState(300);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const debounceRef = useRef(null);

  async function load() {
    const { data } = await supabase
      .from('watched_locations')
      .select('id, label, lat, lng, radius_m, created_at')
      .order('created_at', { ascending: false });
    setLocations(data || []);
    setLoading(false);
  }

  useEffect(() => {
    load();
  }, []);

  function handleAddressChange(value) {
    setQuery(value);
    setSelectedCoords(null);

    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (value.trim().length < 4) {
      setSuggestions([]);
      return;
    }

    debounceRef.current = setTimeout(async () => {
      try {
        const res = await fetch(
          `https://api-adresse.data.gouv.fr/search/?q=${encodeURIComponent(value)}&limit=5`
        );
        const json = await res.json();
        setSuggestions(json.features || []);
      } catch {
        setSuggestions([]);
      }
    }, 300);
  }

  function handleSelectSuggestion(feature) {
    const [lng, lat] = feature.geometry.coordinates;
    setQuery(feature.properties.label);
    setSelectedCoords({ lat, lng });
    setSuggestions([]);
  }

  async function handleAdd(e) {
    e.preventDefault();
    setError('');

    if (!label.trim()) {
      setError('Donne un nom à ce lieu (ex : École de mon fils).');
      return;
    }
    if (!selectedCoords) {
      setError('Choisis une adresse dans les suggestions.');
      return;
    }

    setSubmitting(true);
    const { data: { user } } = await supabase.auth.getUser();

    const { error: insertError } = await supabase.from('watched_locations').insert({
      user_id: user.id,
      label: label.trim(),
      lat: selectedCoords.lat,
      lng: selectedCoords.lng,
      radius_m: radius,
    });

    setSubmitting(false);

    if (insertError) {
      setError('Une erreur est survenue. Réessaie.');
      return;
    }

    setLabel('');
    setQuery('');
    setSelectedCoords(null);
    setRadius(300);
    load();
  }

  async function handleDelete(id) {
    await supabase.from('watched_locations').delete().eq('id', id);
    load();
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <div>
        <Link href="/settings" className="text-sm font-medium text-content-secondary">
          ← Paramètres
        </Link>
        <h1 className="mt-1 text-xl font-semibold text-content-primary">Lieux surveillés</h1>
        <p className="mt-1 text-sm text-content-secondary">
          Reçois une notification si une alerte quartier est publiée près d'un lieu qui te tient
          à cœur (école, résidence secondaire...).
        </p>
      </div>

      <form onSubmit={handleAdd} className="flex flex-col gap-3 rounded-card border border-border bg-surface-card p-4">
        <input
          type="text"
          maxLength={60}
          value={label}
          onChange={(e) => setLabel(e.target.value)}
          placeholder="Nom du lieu (ex : École de mon fils)"
          className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
        />

        <div className="relative">
          <input
            type="text"
            value={query}
            onChange={(e) => handleAddressChange(e.target.value)}
            placeholder="Adresse..."
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
          {suggestions.length > 0 && (
            <ul className="absolute z-10 mt-1 w-full overflow-hidden rounded-card border border-border bg-surface shadow-soft">
              {suggestions.map((feature) => (
                <li key={feature.properties.id}>
                  <button
                    type="button"
                    onClick={() => handleSelectSuggestion(feature)}
                    className="w-full px-4 py-3 text-left text-sm text-content-primary hover:bg-surface-card"
                  >
                    {feature.properties.label}
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>

        <div>
          <label className="mb-1 block text-xs text-content-secondary">
            Rayon de surveillance : {radius} m
          </label>
          <input
            type="range"
            min={50}
            max={1000}
            step={50}
            value={radius}
            onChange={(e) => setRadius(Number(e.target.value))}
            className="w-full accent-corail"
          />
        </div>

        {error && <p className="text-sm text-corail">{error}</p>}

        <button
          type="submit"
          disabled={submitting}
          className="h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
        >
          {submitting ? 'Ajout...' : 'Ajouter ce lieu'}
        </button>
      </form>

      {!loading && locations.length === 0 && (
        <p className="text-center text-sm text-content-secondary">Aucun lieu surveillé pour l'instant.</p>
      )}

      <div className="flex flex-col gap-2">
        {locations.map((loc) => (
          <div
            key={loc.id}
            className="flex items-center gap-3 rounded-card border border-border bg-surface-card p-3"
          >
            <span className="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-pill bg-corail/10 text-corail">
              <MapPin size={16} />
            </span>
            <div className="min-w-0 flex-1">
              <p className="truncate font-medium text-content-primary">{loc.label}</p>
              <p className="text-xs text-content-secondary">Rayon : {loc.radius_m} m</p>
            </div>
            <button
              onClick={() => handleDelete(loc.id)}
              aria-label="Supprimer"
              className="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-pill text-content-secondary hover:bg-surface"
            >
              <Trash2 size={16} />
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

MQEOF_SRC_APP_LIEUX-SURVEILLES_PAGE_JSX

mkdir -p "public/placeholders"
base64 -d > "public/placeholders/achat_groupe.png" << 'MQB64EOF_PUBLIC_PLACEHOLDERS_ACHAT_GROUPE_PNG'
iVBORw0KGgoAAAANSUhEUgAAAZAAAAGQCAIAAAAP3aGbAAAHrElEQVR4nO3dTXITOQCAUTLFQbjR7OeA7LlR7pBiPwsoCImJ7f5x61O/t6TilCWkr+V2xX56/v7yCaDgn6OfAMCtBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8gQLCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8gQLCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8gQLCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8gQLCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8gQLCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjI+H/0EAr58+/r+H5///e/xz+QxjPfT1ONNe3r+/nL0cxjXxaX82mTL2njfmGy8ExCsy64u5dcmWNbG+4EJxjsN97AuuGs1L/j50Rjvtj/PfgTrrWWrs7umjXe/R7E5wfrDmnVZXNPG+5jHshXBAjIE67f1l9DWRdh4H/8bWEmwgAzB+mmri2flImy8x/4elhEsIEOwgAzBAjIEC8gQLCBDsIAMwfppq7/Ir/xlv/Ee+3tYRrCADMH6bf3Fs3X5Nd7H/wZWEiwgQ7D+sOYSWrz8Gu9jHstWBOutZeuyu5qNd79HsTnBuuDe1Vlfzca77c+zH19C8ZGzfauK8b4x2XgnIFjXne1764z309TjTRMsIMM9LCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8gQLCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8j4fPQTWOLqN4yv4St/YVjJE5amwDklg7WrXY9vwBrVYDlkwQlVg7UrhywYUzhYDllwNuFg7cohCwbUDpZDFpxKO1i7csiC0eSD5ZAF55EP1q4csmAoMwTLIQtOYoZg7cohC8YxSbAcsuAMJgnWrhyyYBDzBMshC6Y3T7B25ZAFI5gqWA5ZMLepgrUrhyw43GzBcsiCiSU/0/0oDlkcwmX4lwmDteZ/V5JgZLO9JAQmJlh/cPZmNNbka4IFZAgWkCFYQIZgARmCBWQI1lvelGEcVuMbggVkCBaQIVhAhmABGYJ1gTudjMA6fE+wgAzBAjIEC8gQLCBDsIAMwbrMGzQcywq8SLCADMECMgQLyBAsIEOw/spdT45i7f2NYAEZggVkCBaQIVhAhmABGYL1EW/W8HhW3QcEC8gQLCBDsIAMwQIyBOsKd0B5JOvtY4IFZAgWkCFYQIZgARmCBWQI1nXeuOExrLSrBAvIECwgQ7CADMECMgTrJu6Gsjdr7BaCBWQIFpAhWECGYAEZggVkCNatvInDfqyuGwkWkCFYQIZgARmCBWQI1h3cGWUP1tXtBAvIECwgQ7CADMECMgQLyBCs+3hDh21ZUXcRLCBDsIAMwQIyBAvIEKy7uUvKVqylewkWkCFYQIZgARmCBWQIFpAhWEt4c4f1rKIFBAvIECwgQ7CADMECMgRrIXdMWcP6WUawgAzBAjIEC8gQLCBDsIAMwVrOGz0sY+UsJlhAhmABGYIFZAgWkCFYq7h7yr2smTUEC8gQLCBDsIAMwQIyBAvIEKy1vOnD7ayWlQQLyBAsIEOwgAzBAjIEawPupHIL62Q9wQIyBAvIECwgQ7CADMECMgRrG94A4mNWyCYEC8gQLCDj6fn7y9HPAeAmTlhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAxuejnwC3+vLt6/t/9LFwC5jJLh8vM7qLu+s9++0qMzkBwRrXjRvsNZvtIjM5DfewBrVgjy1+1NzM5EwEa0Rrdoud9pqZnIxgDWf9PrHTfjCT8xGssWy1Q+w0MzklwRrItnvjzDvNTM5KsIAMwRrFHpfxcx4NzOTEBAvIECwgQ7CGsN8rjrO9ljGTcxMsIEOwgAzBAjIEC8gQLCBDsIAMwRrCfh8Xd7YPojOTcxMsIEOwgAzBGsUerzjO+SrGTE5MsIAMwRrItpfxMx8KzOSsBGssW+0Ne8xMTkmwhrN+h9hjP5jJ+QjWiNbsE3vsNTM5GcEa1LLdYo+9ZyZn4qvqR3fj58bZYFeZyQkIVsbF/WZ3LWAmuwQLyHAPC8gQLCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8gQLCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8gQLCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8gQLCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8gQLCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8gQLCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8gQLCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8gQLCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8gQLCBDsIAMwQIyBAvIECwgQ7CAjP8BZ0qAf3EMTA8AAAAASUVORK5CYII=
MQB64EOF_PUBLIC_PLACEHOLDERS_ACHAT_GROUPE_PNG

mkdir -p "public/categories"
base64 -d > "public/categories/achat_groupe.png" << 'MQB64EOF_PUBLIC_CATEGORIES_ACHAT_GROUPE_PNG'
iVBORw0KGgoAAAANSUhEUgAAASwAAAEsCAIAAAD2HxkiAAAEz0lEQVR4nO3cPY4UOxSAUXhiIeyI/C2QnB3NHhA5AUQg6Oqf4nNdnxMiRirZ95Orrel5//bt6zug81/9ALA7EUJMhBATIcRECDERQkyEEBMhxEQIMRFCTIQQEyHERAgxEUJMhBATIcRECDERQkyEEBMhxEQIMRFCTIQQEyHERAgxEUJMhBATIcRECDERQkyEEBMhxEQIMRFCTIQQEyHERAgxEUJMhBATIcRECDERQkyEEBMhxEQIMRFCTIQQEyHERAgxEUJMhBATIcRECDERQkyEEBMhxEQIMRFCTIQQEyHERAgxEUJMhBATIcRECDERQkyEEBMhxEQIMRFCTIQQEyHERAgxEUJMhBATIcRECDERQkyEEBMhxEQIMRFCTIQQEyHERAgxEUJMhBATIcRECLEP9QP89PHL52d+/O3T/696EvjHnIQQWyXCJ4+yJw9SCK0SIWxroQgdhuxpoQhhT2tF6DBkQ2tFCBtaLkKHIbtZLkLYzYoROgzZyooRwlYWjdBhyD4WjRD2sW6EDkM2scpXmc6gw01c/YtsS0d4cHHFxqWt+zoKm5gQ4dXfRnjGgN2fECFcmgghJkKIiRBiIoTYkAgHXJHxgBn7PiRCuC4RQkyEEBMhxEQIsTkRzrgo47gxOz4nQrgoEUJMhBATIcRGRTjmkzo3TdrrURHCFYkQYiKEmAghJkKITYtw0qUZfzJsl6dFCJcjQoiJEGIihJgIITYwwmFXZ/xi3v4OjBCuRYQQEyHERAixmRHO++zODyN3dmaEcCEihJgIISZCiIkQYmMjHHmNtrmpezo2QrgKEUJMhBATIcRECLHJEU69TNvT4N2cHCFcggghJkKIiRBiwyMc/Gl+K7P3cXiEsD4RQkyEEBMhxEQIsfkRzr5Y28H4HZwfISxOhBATIcRECDERQmyLCMdfrw22w95tESGsTIQQEyHERAixXSLc4fP9PJvs2i4RwrJECDERQkyEEBMhxDaKcJOrtjH22a+NIoQ1iRBiIoSYCCEmQojtFeE+F25Xt9VO7RUhLEiEEHv/9u1r/QywNSchxEQIMRFCTIQQEyHERAgxEUJMhBD7UD/AVX388vmXf9nq1x1/sAgv4Tdm7vP72P1u/CBahNfyOnqHI8N3/L9dlEV4OREedddUTR1Bi3AGER7ywDzNG0GLcBIR3vbwJE0aQYtwHhHe8OQMzRhBi3AqEUJMhBAT4d+85D3q6i9jFuFsIoSYCCEmQoiJEGIihJgI/+YlXwW4+vcJLMLZRAgxEUJMhDc8+R414zXMIpxKhLc9PEOThs8inEeEhzwwSfOGzyKcRIRH3TVPU4fPIpxBhHc4OFWzh88ivJy/tvYgf+3vnUV4ERFCzOsoxEQIMRFCTIQQEyHERAgxEUJMhBATIcRECDERQkyEEBMhxEQIMRFCTIQQEyHERAgxEUJMhBATIcRECDERQkyEEBMhxEQIMRFCTIQQEyHERAgxEUJMhBATIcRECDERQkyEEBMhxEQIMRFCTIQQEyHERAgxEUJMhBATIcRECDERQkyEEBMhxEQIMRFCTIQQEyHERAgxEUJMhBATIcRECDERQkyEEBMhxEQIMRFCTIQQEyHERAgxEUJMhBATIcRECDERQkyEEBMhxEQIMRFC7DsCsLZSJWcEHQAAAABJRU5ErkJggg==
MQB64EOF_PUBLIC_CATEGORIES_ACHAT_GROUPE_PNG

echo "Les 4 fonctionnalites ont ete ajoutees avec succes."
echo "Prochaine etape : executer les migrations 032 a 035, puis git add -A && git commit -m \"verification email, achat groupe, sondages, lieux surveilles\" && git push"
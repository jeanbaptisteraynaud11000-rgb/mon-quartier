#!/usr/bin/env bash
set -e
echo "Cartes detaillees annonces + activites..."

mkdir -p "src/app/annonces"
cat > "src/app/annonces/PostCardMenu.jsx" << 'MQEOF_SRC_APP_ANNONCES_POSTCARDMENU_JSX'
'use client';

import { useState, useRef, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { MoreVertical } from 'lucide-react';
import { supabase } from '@/lib/supabaseClient';
import ReportSheet from '@/components/ReportSheet';

export default function PostCardMenu({ postId, isOwnPost }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [reportOpen, setReportOpen] = useState(false);
  const ref = useRef(null);

  useEffect(() => {
    function handleClickOutside(e) {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false);
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  async function handleMarkCompleted(e) {
    e.preventDefault();
    e.stopPropagation();
    await supabase.from('posts').update({ status: 'completed' }).eq('id', postId);
    setOpen(false);
    router.refresh();
  }

  async function handleDelete(e) {
    e.preventDefault();
    e.stopPropagation();
    if (!confirm('Supprimer cette annonce ?')) return;
    await supabase.from('posts').update({ status: 'deleted' }).eq('id', postId);
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
        className="flex h-7 w-7 items-center justify-center rounded-pill text-content-secondary hover:bg-surface-card"
      >
        <MoreVertical size={16} />
      </button>

      {open && (
        <div className="absolute right-0 top-full z-10 mt-1 w-44 overflow-hidden rounded-card border border-border bg-surface shadow-soft">
          {isOwnPost ? (
            <>
              <Link
                href={`/annonces/${postId}/edit`}
                onClick={(e) => e.stopPropagation()}
                className="block px-4 py-2 text-left text-sm text-content-primary hover:bg-surface-card"
              >
                Modifier
              </Link>
              <button
                onClick={handleMarkCompleted}
                className="block w-full px-4 py-2 text-left text-sm text-content-primary hover:bg-surface-card"
              >
                Marquer terminé
              </button>
              <button
                onClick={handleDelete}
                className="block w-full px-4 py-2 text-left text-sm text-corail hover:bg-surface-card"
              >
                Supprimer
              </button>
            </>
          ) : (
            <button
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                setReportOpen(true);
                setOpen(false);
              }}
              className="block w-full px-4 py-2 text-left text-sm text-content-primary hover:bg-surface-card"
            >
              Signaler
            </button>
          )}
        </div>
      )}

      <ReportSheet
        open={reportOpen}
        onClose={() => setReportOpen(false)}
        targetType="post"
        targetId={postId}
      />
    </div>
  );
}

MQEOF_SRC_APP_ANNONCES_POSTCARDMENU_JSX

mkdir -p "src/app/annonces"
cat > "src/app/annonces/page.jsx" << 'MQEOF_SRC_APP_ANNONCES_PAGE_JSX'
// Server Component : liste des annonces du quartier de l'utilisateur,
// filtrable par type via ?type=don|entraide|covoiturage|cherche|alerte.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { POST_TYPES, getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';
import { getPlaceholderImage } from '@/lib/placeholderImages';
import { Heart } from 'lucide-react';
import PostCardMenu from './PostCardMenu';

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
    .select('id, type, title, description, approx_zone, created_at, user_id')
    .eq('quartier_id', profile.quartier_id)
    .eq('status', 'active')
    .order('created_at', { ascending: false })
    .limit(30);

  if (activeType) {
    query = query.eq('type', activeType);
  }

  const { data: posts, error } = await query;

  // Requêtes séparées : pas de clé étrangère directe posts → profiles.
  let authorInfo = {};
  let thumbnailByPost = {};
  let favoriteCounts = {};
  if (posts?.length > 0) {
    const userIds = [...new Set(posts.map((p) => p.user_id))];
    const postIds = posts.map((p) => p.id);

    const [{ data: authors }, { data: images }, { data: counts }] = await Promise.all([
      supabase.from('profiles').select('user_id, display_name, photo_url, photo_visible').in('user_id', userIds),
      supabase
        .from('post_images')
        .select('post_id, storage_path, position')
        .in('post_id', postIds)
        .order('position', { ascending: true }),
      supabase.rpc('get_favorite_counts', { p_post_ids: postIds }),
    ]);

    authorInfo = Object.fromEntries((authors || []).map((a) => [a.user_id, a]));

    for (const img of images || []) {
      if (!thumbnailByPost[img.post_id]) {
        thumbnailByPost[img.post_id] = supabase.storage.from('posts').getPublicUrl(img.storage_path).data.publicUrl;
      }
    }

    favoriteCounts = Object.fromEntries((counts || []).map((c) => [c.post_id, c.count]));
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      {/* Filtres de catégorie */}
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

      <div className="flex flex-col gap-3">
        {posts?.map((post) => {
          const typeInfo = getPostTypeInfo(post.type);
          const thumbnail = thumbnailByPost[post.id] || getPlaceholderImage(post.type);
          const author = authorInfo[post.user_id];
          const isOwnPost = post.user_id === user.id;
          const favCount = favoriteCounts[post.id] || 0;

          return (
            <div
              key={post.id}
              className="flex gap-3 rounded-card border border-border bg-surface-card p-3 shadow-soft"
            >
              <Link href={`/annonces/${post.id}`} className="h-20 w-20 flex-shrink-0 overflow-hidden rounded-card bg-surface">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={thumbnail} alt="" className="h-full w-full object-cover" />
              </Link>

              <div className="min-w-0 flex-1">
                <div className="flex items-center justify-between gap-2">
                  <Link href={`/annonces/${post.id}`} className="flex min-w-0 items-center gap-1.5">
                    <div className="flex h-5 w-5 flex-shrink-0 items-center justify-center overflow-hidden rounded-pill bg-corail/10 text-[9px] font-semibold text-corail">
                      {author?.photo_visible && author?.photo_url ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={author.photo_url} alt="" className="h-full w-full object-cover" />
                      ) : (
                        (author?.display_name || '?').charAt(0).toUpperCase()
                      )}
                    </div>
                    <span className="truncate text-xs font-medium text-content-secondary">
                      {author?.display_name || 'Voisin'} · {formatRelativeTime(post.created_at)}
                    </span>
                  </Link>
                  <PostCardMenu postId={post.id} isOwnPost={isOwnPost} />
                </div>

                <Link href={`/annonces/${post.id}`}>
                  <p className="mt-1 truncate font-semibold text-content-primary">{post.title}</p>
                  {post.description && (
                    <p className="mt-0.5 line-clamp-2 text-sm text-content-secondary">
                      {post.description}
                    </p>
                  )}
                </Link>

                <div className="mt-2 flex items-center justify-between gap-2">
                  <div className="flex min-w-0 items-center gap-1.5">
                    <span className="flex-shrink-0 rounded-pill bg-surface px-2 py-0.5 text-[11px] font-medium text-content-secondary">
                      {typeInfo.label}
                    </span>
                    {post.approx_zone && (
                      <span className="truncate text-[11px] text-content-secondary">
                        {post.approx_zone}
                      </span>
                    )}
                  </div>
                  {favCount > 0 && (
                    <span className="flex flex-shrink-0 items-center gap-1 text-xs text-content-secondary">
                      <Heart size={13} />
                      {favCount}
                    </span>
                  )}
                </div>
              </div>
            </div>
          );
        })}
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

mkdir -p "src/app/activites"
cat > "src/app/activites/EventCardMenu.jsx" << 'MQEOF_SRC_APP_ACTIVITES_EVENTCARDMENU_JSX'
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

MQEOF_SRC_APP_ACTIVITES_EVENTCARDMENU_JSX

mkdir -p "src/app/activites"
cat > "src/app/activites/page.jsx" << 'MQEOF_SRC_APP_ACTIVITES_PAGE_JSX'
// Server Component : activités à venir du quartier, triées par date,
// filtrable par catégorie via ?category=sortie|musee|sport|jeux_de_societe|autre.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { EVENT_CATEGORIES, getEventCategoryInfo, formatEventDate } from '@/lib/eventCategories';
import { getPlaceholderImage } from '@/lib/placeholderImages';
import EventCardMenu from './EventCardMenu';

export default async function ActivitesPage({ searchParams }) {
  const params = await searchParams;
  const activeCategory = params?.category;

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

  let query = supabase
    .from('events')
    .select('id, category, title, location, event_date, max_attendees, user_id')
    .eq('quartier_id', profile.quartier_id)
    .eq('status', 'active')
    .gte('event_date', new Date().toISOString())
    .order('event_date', { ascending: true })
    .limit(30);

  if (activeCategory) {
    query = query.eq('category', activeCategory);
  }

  const { data: events, error } = await query;

  let attendeeCounts = {};
  let organizerInfo = {};
  if (events?.length > 0) {
    const [{ data: attendees }, { data: organizers }] = await Promise.all([
      supabase.from('event_attendees').select('event_id').in('event_id', events.map((e) => e.id)),
      supabase
        .from('profiles')
        .select('user_id, display_name, photo_url, photo_visible')
        .in('user_id', [...new Set(events.map((e) => e.user_id))]),
    ]);
    for (const a of attendees || []) {
      attendeeCounts[a.event_id] = (attendeeCounts[a.event_id] || 0) + 1;
    }
    organizerInfo = Object.fromEntries((organizers || []).map((o) => [o.user_id, o]));
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

      {/* Filtres de catégorie — même traitement que /annonces */}
      <div className="grid grid-cols-3 gap-2">
        <FilterTile href="/activites" label="Toutes" active={!activeCategory} />
        {EVENT_CATEGORIES.map((cat) => (
          <FilterTile
            key={cat.category}
            href={`/activites?category=${cat.category}`}
            image={getPlaceholderImage(cat.category)}
            label={cat.label}
            active={activeCategory === cat.category}
          />
        ))}
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
          const count = attendeeCounts[event.id] || 0;
          const isFull = count >= event.max_attendees;
          const organizer = organizerInfo[event.user_id];
          const isOrganizer = event.user_id === user.id;

          return (
            <div key={event.id} className="rounded-card border border-border bg-surface-card p-3 shadow-soft">
              <div className="flex gap-3">
                <Link href={`/activites/${event.id}`} className="h-20 w-20 flex-shrink-0 overflow-hidden rounded-card">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={getPlaceholderImage(event.category)}
                    alt=""
                    className="h-full w-full object-cover"
                  />
                </Link>

                <div className="min-w-0 flex-1">
                  <div className="flex items-center justify-between gap-2">
                    <Link href={`/activites/${event.id}`} className="flex min-w-0 items-center gap-1.5">
                      <div className="flex h-5 w-5 flex-shrink-0 items-center justify-center overflow-hidden rounded-pill bg-vert/10 text-[9px] font-semibold text-vert">
                        {organizer?.photo_visible && organizer?.photo_url ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img src={organizer.photo_url} alt="" className="h-full w-full object-cover" />
                        ) : (
                          (organizer?.display_name || '?').charAt(0).toUpperCase()
                        )}
                      </div>
                      <span className="truncate text-xs font-medium text-content-secondary">
                        {organizer?.display_name || 'Voisin'} · {formatEventDate(event.event_date)}
                      </span>
                    </Link>
                    <EventCardMenu eventId={event.id} isOrganizer={isOrganizer} />
                  </div>

                  <Link href={`/activites/${event.id}`}>
                    <p className="mt-1 font-semibold text-content-primary">{event.title}</p>
                    {event.location && (
                      <p className="mt-0.5 truncate text-sm text-content-secondary">{event.location}</p>
                    )}
                  </Link>

                  <div className="mt-2 flex items-center gap-1.5">
                    <span className="rounded-pill bg-surface px-2 py-0.5 text-[11px] font-medium text-content-secondary">
                      {catInfo.label}
                    </span>
                    <span className={`text-[11px] font-medium ${isFull ? 'text-corail' : 'text-content-secondary'}`}>
                      {isFull ? 'Complet' : `${count} / ${event.max_attendees} places`}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          );
        })}
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

MQEOF_SRC_APP_ACTIVITES_PAGE_JSX

echo "Cartes detaillees ajoutees avec succes."
echo "Prochaine etape : executer la migration 024, puis git add -A && git commit -m \"cartes detaillees : auteur, menu, favoris\" && git push"
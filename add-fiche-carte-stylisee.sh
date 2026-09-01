#!/usr/bin/env bash
set -e
echo "Fiche detail carte stylisee (photo, auteur, disponibilite, distance)..."

mkdir -p "src/app/carte"
cat > "src/app/carte/page.jsx" << 'MQEOF_SRC_APP_CARTE_PAGE_JSX'
// Server Component : rassemble les annonces, activités et commerces ayant
// des coordonnées, dans le quartier de l'utilisateur uniquement (jamais
// au-delà — cohérent avec l'isolation stricte par quartier de toute
// l'app). Le rendu de la carte elle-même est délégué à un composant client
// (MapLibre a besoin du navigateur).

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import QuartierMapWrapper from '@/components/map/QuartierMapWrapper';
import { calculateDistance, formatDistance } from '@/lib/distanceCalculator';
import { getPlaceholderImage } from '@/lib/placeholderImages';

export default async function CartePage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: profile } = await supabase
    .from('profiles')
    .select('quartier_id, quartiers(name, city, center_lat, center_lng)')
    .eq('user_id', user.id)
    .single();

  if (!profile?.quartier_id) {
    return (
      <div className="p-4">
        <div className="rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">
            Termine d'abord ton inscription pour découvrir la carte de ton quartier.
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
  const centerLat = profile.quartiers?.center_lat || 0;
  const centerLng = profile.quartiers?.center_lng || 0;

  const [{ data: boundary }, { data: areaM2 }, { data: posts }, { data: events }, { data: places }] = await Promise.all([
    supabase.rpc('get_quartier_boundary', { p_quartier_id: quartierId }),
    supabase.rpc('get_quartier_area_m2', { p_quartier_id: quartierId }),
    supabase
      .from('posts')
      .select('id, type, title, description, availability, approx_zone, user_id, lat, lng')
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .not('lat', 'is', null),
    supabase
      .from('events')
      .select('id, category, title, location, event_date, max_attendees, user_id, photo_url, lat, lng')
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .gte('event_date', new Date().toISOString())
      .not('lat', 'is', null),
    supabase
      .from('places')
      .select('id, category, name, address, phone, photo_url, lat, lng')
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .not('lat', 'is', null),
  ]);

  // Auteurs des annonces/activités (photo, nom) — requête séparée, pas de
  // clé étrangère directe vers profiles.
  const authorIds = [
    ...new Set([...(posts || []).map((p) => p.user_id), ...(events || []).map((e) => e.user_id)]),
  ];
  const { data: authors } =
    authorIds.length > 0
      ? await supabase.from('profiles').select('user_id, display_name, photo_url, photo_visible').in('user_id', authorIds)
      : { data: [] };
  const authorById = Object.fromEntries((authors || []).map((a) => [a.user_id, a]));

  // Photo de couverture des annonces (première image).
  const postIds = (posts || []).map((p) => p.id);
  const { data: postImages } =
    postIds.length > 0
      ? await supabase
          .from('post_images')
          .select('post_id, storage_path, position')
          .in('post_id', postIds)
          .order('position', { ascending: true })
      : { data: [] };
  const thumbnailByPost = {};
  for (const img of postImages || []) {
    if (!thumbnailByPost[img.post_id]) {
      thumbnailByPost[img.post_id] = supabase.storage.from('posts').getPublicUrl(img.storage_path).data.publicUrl;
    }
  }

  function distanceFromCenter(lat, lng) {
    const km = calculateDistance(centerLat, centerLng, lat, lng);
    return formatDistance(km);
  }

  // Un seul tableau à plat pour la carte — propriétés simples uniquement
  // (MapLibre sérialise les propriétés des sources groupées).
  const points = [
    ...(posts || []).map((p) => {
      const author = authorById[p.user_id];
      return {
        id: p.id,
        kind: 'post',
        category: p.type,
        title: p.title,
        description: p.description || '',
        photo: thumbnailByPost[p.id] || getPlaceholderImage(p.type),
        authorName: author?.display_name || 'Voisin',
        authorPhoto: author?.photo_visible ? author?.photo_url || '' : '',
        availability: p.availability || '',
        zone: p.approx_zone || '',
        distanceLabel: distanceFromCenter(p.lat, p.lng) || '',
        lat: p.lat,
        lng: p.lng,
      };
    }),
    ...(events || []).map((e) => {
      const author = authorById[e.user_id];
      return {
        id: e.id,
        kind: 'event',
        category: e.category,
        title: e.title,
        description: e.location || '',
        photo: e.photo_url || getPlaceholderImage(e.category),
        authorName: author?.display_name || 'Voisin',
        authorPhoto: author?.photo_visible ? author?.photo_url || '' : '',
        availability: new Date(e.event_date).toLocaleDateString('fr-FR', {
          weekday: 'short',
          day: 'numeric',
          month: 'short',
          hour: '2-digit',
          minute: '2-digit',
        }),
        zone: '',
        distanceLabel: distanceFromCenter(e.lat, e.lng) || '',
        lat: e.lat,
        lng: e.lng,
      };
    }),
    ...(places || []).map((pl) => ({
      id: pl.id,
      kind: 'place',
      category: pl.category,
      title: pl.name,
      description: pl.address || '',
      photo: pl.photo_url || getPlaceholderImage(pl.category),
      authorName: '',
      authorPhoto: '',
      availability: '',
      zone: '',
      distanceLabel: distanceFromCenter(pl.lat, pl.lng) || '',
      lat: pl.lat,
      lng: pl.lng,
    })),
  ];

  return (
    <div className="flex h-[calc(100vh-3.5rem-4.25rem)] flex-col">
      <div className="border-b border-border bg-surface p-4">
        <h1 className="text-lg font-semibold text-content-primary">
          Carte — {profile.quartiers?.name}
        </h1>
        <p className="text-xs text-content-secondary">
          {points.length} élément{points.length > 1 ? 's' : ''} dans ton quartier
        </p>
      </div>

      <div className="relative flex-1">
        <QuartierMapWrapper
          centerLat={centerLat}
          centerLng={centerLng}
          boundary={boundary}
          areaM2={areaM2}
          points={points}
        />
      </div>
    </div>
  );
}

MQEOF_SRC_APP_CARTE_PAGE_JSX

mkdir -p "src/components/map"
cat > "src/components/map/MarkerBottomSheet.jsx" << 'MQEOF_SRC_COMPONENTS_MAP_MARKERBOTTOMSHEET_JSX'
'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { X, Heart, CalendarDays } from 'lucide-react';
import { supabase } from '@/lib/supabaseClient';
import { getPostTypeInfo } from '@/lib/postTypes';
import { getEventCategoryInfo } from '@/lib/eventCategories';
import { getPlaceCategoryInfo } from '@/lib/placeCategories';

export default function MarkerBottomSheet({ point, onClose }) {
  const [favorited, setFavorited] = useState(false);
  const [userId, setUserId] = useState(null);

  useEffect(() => {
    if (!point || point.kind !== 'post') return;
    let cancelled = false;

    async function load() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user || cancelled) return;
      setUserId(user.id);

      const { data } = await supabase
        .from('favorites')
        .select('post_id')
        .eq('user_id', user.id)
        .eq('post_id', point.id)
        .maybeSingle();
      if (!cancelled) setFavorited(!!data);
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [point]);

  async function handleToggleFavorite() {
    if (!userId || !point) return;
    if (favorited) {
      await supabase.from('favorites').delete().eq('user_id', userId).eq('post_id', point.id);
      setFavorited(false);
    } else {
      await supabase.from('favorites').insert({ user_id: userId, post_id: point.id });
      setFavorited(true);
    }
  }

  if (!point) return null;

  let categoryLabel = '';
  let href = '#';
  let ctaLabel = 'Voir';
  let badgeTint = 'bg-surface-card text-content-secondary';

  if (point.kind === 'post') {
    categoryLabel = getPostTypeInfo(point.category).label;
    href = `/annonces/${point.id}`;
    ctaLabel = "Voir l'annonce";
    badgeTint = 'bg-corail/10 text-corail';
  } else if (point.kind === 'event') {
    categoryLabel = getEventCategoryInfo(point.category).label;
    href = `/activites/${point.id}`;
    ctaLabel = "Voir l'activité";
    badgeTint = 'bg-vert/10 text-vert';
  } else if (point.kind === 'place') {
    categoryLabel = getPlaceCategoryInfo(point.category).label;
    href = `/commerces/${point.id}`;
    ctaLabel = 'Voir la fiche';
    badgeTint = 'bg-surface-card text-content-secondary';
  }

  return (
    <div className="absolute inset-x-0 bottom-0 z-10 rounded-t-sheet bg-surface p-4 shadow-sheet">
      <div className="mx-auto mb-3 h-1 w-10 rounded-pill bg-border" />

      <div className="flex items-start justify-between">
        <span className={`inline-block rounded-pill px-2.5 py-1 text-xs font-semibold uppercase tracking-wide ${badgeTint}`}>
          {categoryLabel}
        </span>
        <div className="flex items-center gap-1">
          {point.kind === 'post' && (
            <button
              onClick={handleToggleFavorite}
              aria-label={favorited ? 'Retirer des favoris' : 'Ajouter aux favoris'}
              className="flex h-8 w-8 items-center justify-center rounded-pill text-content-secondary hover:bg-surface-card"
            >
              <Heart size={16} fill={favorited ? '#FF5A5F' : 'none'} className={favorited ? 'text-corail' : ''} />
            </button>
          )}
          <button
            onClick={onClose}
            aria-label="Fermer"
            className="flex h-8 w-8 items-center justify-center rounded-pill text-content-secondary hover:bg-surface-card"
          >
            <X size={16} />
          </button>
        </div>
      </div>

      <div className="mt-2 flex gap-3">
        <div className="min-w-0 flex-1">
          <p className="font-semibold text-content-primary">{point.title}</p>
          {point.description && (
            <p className="mt-1 line-clamp-2 text-sm text-content-secondary">{point.description}</p>
          )}
        </div>
        {point.photo && (
          <div className="h-16 w-16 flex-shrink-0 overflow-hidden rounded-card bg-surface-card">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={point.photo} alt="" className="h-full w-full object-cover" />
          </div>
        )}
      </div>

      {point.authorName && (
        <div className="mt-3 flex items-center gap-2">
          <div className="flex h-7 w-7 flex-shrink-0 items-center justify-center overflow-hidden rounded-pill bg-corail/10 text-[10px] font-semibold text-corail">
            {point.authorPhoto ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={point.authorPhoto} alt="" className="h-full w-full object-cover" />
            ) : (
              point.authorName.charAt(0).toUpperCase()
            )}
          </div>
          <p className="text-sm text-content-secondary">
            {point.authorName}
            {point.distanceLabel && ` · à ${point.distanceLabel}`}
            {point.zone && ` · ${point.zone}`}
          </p>
        </div>
      )}

      {!point.authorName && point.distanceLabel && (
        <p className="mt-3 text-sm text-content-secondary">à {point.distanceLabel}</p>
      )}

      {point.availability && (
        <div className="mt-3 flex items-center gap-1.5 rounded-card bg-surface-card px-3 py-2 text-xs font-medium text-content-primary">
          <CalendarDays size={13} className="text-content-secondary" />
          {point.availability}
        </div>
      )}

      <Link
        href={href}
        className="mt-4 block h-tap w-full rounded-pill bg-corail text-center leading-[2.75rem] font-medium text-white transition-fast hover:bg-corail-hover"
      >
        {ctaLabel}
      </Link>
    </div>
  );
}

MQEOF_SRC_COMPONENTS_MAP_MARKERBOTTOMSHEET_JSX

echo "Fiche stylisee ajoutee avec succes."
echo "Prochaine etape : git add -A && git commit -m \"carte : fiche detaillee stylisee au clic\" && git push"
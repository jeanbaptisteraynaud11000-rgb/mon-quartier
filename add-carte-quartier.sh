#!/usr/bin/env bash
set -e
echo "Ajout de la carte du quartier (MapLibre)..."

cat > "package.json" << 'MQEOF_PACKAGE_JSON'
{
  "name": "mon-quartier",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "14.2.5",
    "react": "18.3.1",
    "react-dom": "18.3.1",
    "@supabase/supabase-js": "^2.45.0",
    "@supabase/ssr": "^0.5.1",
    "lucide-react": "^0.383.0",
    "maplibre-gl": "^4.7.1"
  },
  "devDependencies": {
    "tailwindcss": "^3.4.4",
    "postcss": "^8.4.38",
    "autoprefixer": "^10.4.19",
    "eslint": "^8.57.0",
    "eslint-config-next": "14.2.5"
  }
}

MQEOF_PACKAGE_JSON

mkdir -p "src/components/map"
cat > "src/components/map/QuartierMapView.jsx" << 'MQEOF_SRC_COMPONENTS_MAP_QUARTIERMAPVIEW_JSX'
'use client';

import { useEffect, useRef, useState } from 'react';
import maplibregl from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';
import MarkerBottomSheet from './MarkerBottomSheet';

// Couleurs par grande famille de contenu — volontairement simplifiées à 3
// couleurs (plutôt qu'une par sous-catégorie) pour que la carte reste
// lisible en un coup d'œil. Le détail exact de la catégorie reste visible
// dans la fiche qui s'ouvre au clic.
const KIND_COLORS = {
  post: '#FF5A5F',
  event: '#8B5CF6',
  place: '#475569',
};

export default function QuartierMapView({ centerLat, centerLng, boundary, points }) {
  const containerRef = useRef(null);
  const mapRef = useRef(null);
  const [selectedPoint, setSelectedPoint] = useState(null);

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    const map = new maplibregl.Map({
      container: containerRef.current,
      style: {
        version: 8,
        sources: {
          osm: {
            type: 'raster',
            tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
            tileSize: 256,
            attribution: '&copy; OpenStreetMap contributors',
          },
        },
        layers: [{ id: 'osm', type: 'raster', source: 'osm' }],
      },
      center: [centerLng, centerLat],
      zoom: 15,
    });

    map.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-right');
    mapRef.current = map;

    map.on('load', () => {
      // Périmètre du quartier — cercle semi-transparent.
      if (boundary) {
        map.addSource('quartier-boundary', { type: 'geojson', data: boundary });
        map.addLayer({
          id: 'quartier-boundary-fill',
          type: 'fill',
          source: 'quartier-boundary',
          paint: { 'fill-color': '#FF5A5F', 'fill-opacity': 0.08 },
        });
        map.addLayer({
          id: 'quartier-boundary-line',
          type: 'line',
          source: 'quartier-boundary',
          paint: { 'line-color': '#FF5A5F', 'line-width': 2, 'line-opacity': 0.5 },
        });
      }

      // Contenu (annonces/activités/commerces), regroupé automatiquement.
      const geojson = {
        type: 'FeatureCollection',
        features: points.map((p) => ({
          type: 'Feature',
          geometry: { type: 'Point', coordinates: [p.lng, p.lat] },
          properties: p,
        })),
      };

      map.addSource('content', {
        type: 'geojson',
        data: geojson,
        cluster: true,
        clusterRadius: 50,
        clusterMaxZoom: 16,
      });

      map.addLayer({
        id: 'clusters',
        type: 'circle',
        source: 'content',
        filter: ['has', 'point_count'],
        paint: {
          'circle-color': '#FF5A5F',
          'circle-radius': ['step', ['get', 'point_count'], 16, 10, 22, 30, 28],
          'circle-opacity': 0.85,
        },
      });

      map.addLayer({
        id: 'cluster-count',
        type: 'symbol',
        source: 'content',
        filter: ['has', 'point_count'],
        layout: { 'text-field': '{point_count_abbreviated}', 'text-size': 13 },
        paint: { 'text-color': '#FFFFFF' },
      });

      map.addLayer({
        id: 'unclustered-point',
        type: 'circle',
        source: 'content',
        filter: ['!', ['has', 'point_count']],
        paint: {
          'circle-color': [
            'match',
            ['get', 'kind'],
            'post', KIND_COLORS.post,
            'event', KIND_COLORS.event,
            'place', KIND_COLORS.place,
            '#999999',
          ],
          'circle-radius': 9,
          'circle-stroke-width': 2,
          'circle-stroke-color': '#FFFFFF',
        },
      });

      map.on('click', 'clusters', (e) => {
        const features = map.queryRenderedFeatures(e.point, { layers: ['clusters'] });
        const clusterId = features[0].properties.cluster_id;
        map.getSource('content').getClusterExpansionZoom(clusterId, (err, zoom) => {
          if (err) return;
          map.easeTo({ center: features[0].geometry.coordinates, zoom });
        });
      });

      map.on('click', 'unclustered-point', (e) => {
        const props = e.features[0].properties;
        setSelectedPoint(props);
      });

      map.on('mouseenter', 'clusters', () => (map.getCanvas().style.cursor = 'pointer'));
      map.on('mouseleave', 'clusters', () => (map.getCanvas().style.cursor = ''));
      map.on('mouseenter', 'unclustered-point', () => (map.getCanvas().style.cursor = 'pointer'));
      map.on('mouseleave', 'unclustered-point', () => (map.getCanvas().style.cursor = ''));
    });

    return () => {
      map.remove();
      mapRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="relative h-full w-full">
      <div ref={containerRef} className="h-full w-full" />
      <MarkerBottomSheet point={selectedPoint} onClose={() => setSelectedPoint(null)} />
    </div>
  );
}

MQEOF_SRC_COMPONENTS_MAP_QUARTIERMAPVIEW_JSX

mkdir -p "src/components/map"
cat > "src/components/map/MarkerBottomSheet.jsx" << 'MQEOF_SRC_COMPONENTS_MAP_MARKERBOTTOMSHEET_JSX'
'use client';

import Link from 'next/link';
import { X } from 'lucide-react';
import { getPostTypeInfo } from '@/lib/postTypes';
import { getEventCategoryInfo } from '@/lib/eventCategories';
import { getPlaceCategoryInfo } from '@/lib/placeCategories';

export default function MarkerBottomSheet({ point, onClose }) {
  if (!point) return null;

  let icon = null;
  let categoryLabel = '';
  let href = '#';
  let ctaLabel = 'Voir';

  if (point.kind === 'post') {
    const info = getPostTypeInfo(point.category);
    icon = info.icon;
    categoryLabel = info.label;
    href = `/annonces/${point.id}`;
    ctaLabel = "Voir l'annonce";
  } else if (point.kind === 'event') {
    const info = getEventCategoryInfo(point.category);
    icon = info.icon;
    categoryLabel = info.label;
    href = `/activites/${point.id}`;
    ctaLabel = "Voir l'activité";
  } else if (point.kind === 'place') {
    const info = getPlaceCategoryInfo(point.category);
    icon = info.icon;
    categoryLabel = info.label;
    href = `/commerces/${point.id}`;
    ctaLabel = 'Voir la fiche';
  }

  const Icon = icon;

  return (
    <div className="absolute inset-x-0 bottom-0 z-10 rounded-t-sheet bg-surface p-4 shadow-sheet">
      <div className="mb-3 flex items-start justify-between">
        <div className="flex items-center gap-2">
          {Icon && (
            <span className="flex h-9 w-9 items-center justify-center rounded-pill bg-surface-card text-content-primary">
              <Icon size={17} />
            </span>
          )}
          <div>
            <p className="text-xs text-content-secondary">{categoryLabel}</p>
            <p className="font-semibold text-content-primary">{point.title}</p>
          </div>
        </div>
        <button
          onClick={onClose}
          aria-label="Fermer"
          className="flex h-8 w-8 items-center justify-center rounded-pill text-content-secondary hover:bg-surface-card"
        >
          <X size={16} />
        </button>
      </div>

      {point.subtitle && (
        <p className="mb-3 text-sm text-content-secondary">{point.subtitle}</p>
      )}

      <Link
        href={href}
        className="block h-tap w-full rounded-pill bg-corail text-center leading-[2.75rem] font-medium text-white transition-fast hover:bg-corail-hover"
      >
        {ctaLabel}
      </Link>
    </div>
  );
}

MQEOF_SRC_COMPONENTS_MAP_MARKERBOTTOMSHEET_JSX

mkdir -p "src/components/map"
cat > "src/components/map/QuartierMapWrapper.jsx" << 'MQEOF_SRC_COMPONENTS_MAP_QUARTIERMAPWRAPPER_JSX'
'use client';

import dynamic from 'next/dynamic';

// MapLibre accède à `window` dès son import — ssr: false est indispensable.
const QuartierMapView = dynamic(() => import('./QuartierMapView'), {
  ssr: false,
  loading: () => (
    <div className="flex h-full w-full items-center justify-center bg-surface-card">
      <div className="skeleton h-8 w-32" />
    </div>
  ),
});

export default function QuartierMapWrapper(props) {
  return <QuartierMapView {...props} />;
}

MQEOF_SRC_COMPONENTS_MAP_QUARTIERMAPWRAPPER_JSX

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

  const [{ data: boundary }, { data: posts }, { data: events }, { data: places }] = await Promise.all([
    supabase.rpc('get_quartier_boundary', { p_quartier_id: quartierId }),
    supabase
      .from('posts')
      .select('id, type, title, description, lat, lng')
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .not('lat', 'is', null),
    supabase
      .from('events')
      .select('id, category, title, location, lat, lng')
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .gte('event_date', new Date().toISOString())
      .not('lat', 'is', null),
    supabase
      .from('places')
      .select('id, category, name, address, lat, lng')
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .not('lat', 'is', null),
  ]);

  // Un seul tableau à plat pour la carte — propriétés simples uniquement
  // (MapLibre sérialise les propriétés des sources groupées).
  const points = [
    ...(posts || []).map((p) => ({
      id: p.id,
      kind: 'post',
      category: p.type,
      title: p.title,
      subtitle: p.description || '',
      lat: p.lat,
      lng: p.lng,
    })),
    ...(events || []).map((e) => ({
      id: e.id,
      kind: 'event',
      category: e.category,
      title: e.title,
      subtitle: e.location || '',
      lat: e.lat,
      lng: e.lng,
    })),
    ...(places || []).map((pl) => ({
      id: pl.id,
      kind: 'place',
      category: pl.category,
      title: pl.name,
      subtitle: pl.address || '',
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
          centerLat={profile.quartiers?.center_lat || 0}
          centerLng={profile.quartiers?.center_lng || 0}
          boundary={boundary}
          points={points}
        />
      </div>
    </div>
  );
}

MQEOF_SRC_APP_CARTE_PAGE_JSX

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
        .select('user_id, display_name, photo_url, photo_visible')
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
      ? supabase.from('profiles').select('user_id, display_name, photo_url, photo_visible').in('user_id', relevantUserIds)
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
      ? await supabase.from('profiles').select('user_id, display_name, photo_url, photo_visible').in('user_id', attendeeUserIds)
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
      supabase.from('profiles').select('user_id, display_name, photo_url, photo_visible').in('user_id', userIds),
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

echo "Carte du quartier ajoutee avec succes."
echo "IMPORTANT : npm install necessaire (nouvelle dependance maplibre-gl)"
echo "Prochaine etape : npm install && git add -A && git commit -m \"carte du quartier : MapLibre, clustering, fiche au clic\" && git push"
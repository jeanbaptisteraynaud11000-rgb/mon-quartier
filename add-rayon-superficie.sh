#!/usr/bin/env bash
set -e
echo "Rayon ajustable (200m-2km) + superficie du quartier..."

mkdir -p "src/lib"
cat > "src/lib/geoCircle.js" << 'MQEOF_SRC_LIB_GEOCIRCLE_JS'
// Génère un polygone GeoJSON approximant un cercle de `radiusMeters` autour
// d'un point — utilisé pour dessiner le périmètre ajustable sur la carte
// (MapLibre n'a pas de primitive "cercle géographique" native).

export function createCircleGeoJSON(centerLat, centerLng, radiusMeters, points = 64) {
  const coords = [];
  const earthRadius = 6371000; // mètres

  for (let i = 0; i <= points; i++) {
    const angle = (i / points) * 2 * Math.PI;
    const dx = radiusMeters * Math.cos(angle);
    const dy = radiusMeters * Math.sin(angle);

    const dLat = dy / earthRadius;
    const dLng = dx / (earthRadius * Math.cos((centerLat * Math.PI) / 180));

    const lat = centerLat + (dLat * 180) / Math.PI;
    const lng = centerLng + (dLng * 180) / Math.PI;

    coords.push([lng, lat]);
  }

  return {
    type: 'Feature',
    geometry: { type: 'Polygon', coordinates: [coords] },
    properties: {},
  };
}

MQEOF_SRC_LIB_GEOCIRCLE_JS

mkdir -p "src/components/map"
cat > "src/components/map/QuartierMapView.jsx" << 'MQEOF_SRC_COMPONENTS_MAP_QUARTIERMAPVIEW_JSX'
'use client';

import { useEffect, useRef, useState } from 'react';
import maplibregl from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';
import MarkerBottomSheet from './MarkerBottomSheet';
import { createCircleGeoJSON } from '@/lib/geoCircle';
import { calculateDistance } from '@/lib/distanceCalculator';

const KIND_COLORS = {
  post: '#FF5A5F',
  event: '#8B5CF6',
  place: '#475569',
};

const MIN_RADIUS = 200;
const MAX_RADIUS = 2000;
const DEFAULT_RADIUS = 700;

function formatArea(areaM2) {
  if (!areaM2) return null;
  if (areaM2 >= 1_000_000) return `${(areaM2 / 1_000_000).toFixed(2)} km²`;
  return `${Math.round(areaM2).toLocaleString('fr-FR')} m²`;
}

function toGeoJSON(points) {
  return {
    type: 'FeatureCollection',
    features: points.map((p) => ({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [p.lng, p.lat] },
      properties: p,
    })),
  };
}

export default function QuartierMapView({ centerLat, centerLng, boundary, areaM2, points }) {
  const containerRef = useRef(null);
  const mapRef = useRef(null);
  const [mapReady, setMapReady] = useState(false);
  const [selectedPoint, setSelectedPoint] = useState(null);
  const [radius, setRadius] = useState(DEFAULT_RADIUS);

  // Points réellement dans le rayon sélectionné — tout ce qui dépasse
  // l'étendue réelle du quartier n'ajoute rien de plus (les données
  // au-delà ne sont de toute façon jamais accessibles, RLS oblige).
  const filteredPoints = points.filter(
    (p) => calculateDistance(centerLat, centerLng, p.lat, p.lng) * 1000 <= radius
  );

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    const map = new maplibregl.Map({
      container: containerRef.current,
      style: {
        version: 8,
        glyphs: 'https://demotiles.maplibre.org/font/{fontstack}/{range}.pbf',
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
      try {
        // Périmètre réel du quartier (fixe, en trait pointillé fin).
        if (boundary) {
          map.addSource('quartier-boundary', { type: 'geojson', data: boundary });
          map.addLayer({
            id: 'quartier-boundary-line',
            type: 'line',
            source: 'quartier-boundary',
            paint: { 'line-color': '#475569', 'line-width': 1.5, 'line-dasharray': [2, 2], 'line-opacity': 0.5 },
          });
        }

        // Cercle du rayon sélectionné — ajustable via le curseur.
        map.addSource('radius-circle', {
          type: 'geojson',
          data: createCircleGeoJSON(centerLat, centerLng, DEFAULT_RADIUS),
        });
        map.addLayer({
          id: 'radius-circle-fill',
          type: 'fill',
          source: 'radius-circle',
          paint: { 'fill-color': '#FF5A5F', 'fill-opacity': 0.08 },
        });
        map.addLayer({
          id: 'radius-circle-line',
          type: 'line',
          source: 'radius-circle',
          paint: { 'line-color': '#FF5A5F', 'line-width': 2, 'line-opacity': 0.6 },
        });

        map.addSource('content', {
          type: 'geojson',
          data: toGeoJSON(points),
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
          layout: {
            'text-field': '{point_count_abbreviated}',
            'text-font': ['Noto Sans Regular'],
            'text-size': 13,
          },
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
          setSelectedPoint(e.features[0].properties);
        });

        map.on('mouseenter', 'clusters', () => (map.getCanvas().style.cursor = 'pointer'));
        map.on('mouseleave', 'clusters', () => (map.getCanvas().style.cursor = ''));
        map.on('mouseenter', 'unclustered-point', () => (map.getCanvas().style.cursor = 'pointer'));
        map.on('mouseleave', 'unclustered-point', () => (map.getCanvas().style.cursor = ''));

        setMapReady(true);
      } catch (err) {
        console.error('Erreur lors du chargement des couches de la carte :', err);
      }
    });

    return () => {
      map.remove();
      mapRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Rejoue le cercle et le contenu affiché à chaque changement de rayon.
  useEffect(() => {
    if (!mapReady || !mapRef.current) return;
    const map = mapRef.current;

    const circleSource = map.getSource('radius-circle');
    if (circleSource) {
      circleSource.setData(createCircleGeoJSON(centerLat, centerLng, radius));
    }

    const contentSource = map.getSource('content');
    if (contentSource) {
      contentSource.setData(toGeoJSON(filteredPoints));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [radius, mapReady]);

  return (
    <div className="relative h-full w-full">
      <div ref={containerRef} className="h-full w-full" />

      {/* Superficie du quartier + curseur de rayon */}
      <div className="absolute left-3 top-3 z-10 flex flex-col gap-2 rounded-card bg-white/95 p-3 shadow-soft">
        {areaM2 && (
          <p className="text-xs text-content-secondary">
            Superficie du quartier : <span className="font-medium text-content-primary">{formatArea(areaM2)}</span>
          </p>
        )}
        <div className="flex items-center gap-2">
          <span className="text-xs text-content-secondary">200 m</span>
          <input
            type="range"
            min={MIN_RADIUS}
            max={MAX_RADIUS}
            step={50}
            value={radius}
            onChange={(e) => setRadius(Number(e.target.value))}
            className="w-32 accent-corail"
          />
          <span className="text-xs text-content-secondary">2 km</span>
        </div>
        <p className="text-xs text-content-primary">
          Rayon : <span className="font-medium">{radius >= 1000 ? `${(radius / 1000).toFixed(1)} km` : `${radius} m`}</span>
          {' · '}
          {filteredPoints.length} élément{filteredPoints.length > 1 ? 's' : ''}
        </p>
      </div>

      <MarkerBottomSheet point={selectedPoint} onClose={() => setSelectedPoint(null)} />
    </div>
  );
}

MQEOF_SRC_COMPONENTS_MAP_QUARTIERMAPVIEW_JSX

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

  const [{ data: boundary }, { data: areaM2 }, { data: posts }, { data: events }, { data: places }] = await Promise.all([
    supabase.rpc('get_quartier_boundary', { p_quartier_id: quartierId }),
    supabase.rpc('get_quartier_area_m2', { p_quartier_id: quartierId }),
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
          areaM2={areaM2}
          points={points}
        />
      </div>
    </div>
  );
}

MQEOF_SRC_APP_CARTE_PAGE_JSX

echo "Rayon + superficie ajoutes avec succes."
echo "Prochaine etape : executer la migration 031, puis git add -A && git commit -m \"carte : rayon ajustable + superficie\" && git push"
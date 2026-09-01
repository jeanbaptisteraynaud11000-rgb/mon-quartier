#!/usr/bin/env bash
set -e
echo "Ajout du pointeur vous-etes-ici + style marqueurs ameliore..."

mkdir -p "src/components/map"
cat > "src/components/map/QuartierMapView.jsx" << 'MQEOF_SRC_COMPONENTS_MAP_QUARTIERMAPVIEW_JSX'
'use client';

import { useEffect, useRef, useState } from 'react';
import maplibregl from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';
import MarkerBottomSheet from './MarkerBottomSheet';
import { createCircleGeoJSON } from '@/lib/geoCircle';
import { calculateDistance } from '@/lib/distanceCalculator';
import { useUserPosition } from '@/lib/useUserPosition';

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
  const userMarkerRef = useRef(null);
  const [mapReady, setMapReady] = useState(false);
  const [selectedPoint, setSelectedPoint] = useState(null);
  const [radius, setRadius] = useState(DEFAULT_RADIUS);
  const userPosition = useUserPosition();

  // Points réellement dans le rayon sélectionné — tout ce qui dépasse
  // l'étendue réelle du quartier n'ajoute rien de plus (les données
  // au-delà ne sont de toute façon jamais accessibles, RLS oblige).
  // Le rayon se mesure depuis MA position réelle quand elle est
  // disponible (plus logique que depuis le centre administratif du
  // quartier), sinon on retombe sur le centre du quartier.
  const originLat = userPosition?.lat ?? centerLat;
  const originLng = userPosition?.lng ?? centerLng;

  const filteredPoints = points.filter(
    (p) => calculateDistance(originLat, originLng, p.lat, p.lng) * 1000 <= radius
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
          id: 'clusters-halo',
          type: 'circle',
          source: 'content',
          filter: ['has', 'point_count'],
          paint: {
            'circle-color': '#FF5A5F',
            'circle-radius': ['step', ['get', 'point_count'], 24, 10, 30, 30, 38],
            'circle-opacity': 0.15,
          },
        });

        map.addLayer({
          id: 'clusters',
          type: 'circle',
          source: 'content',
          filter: ['has', 'point_count'],
          paint: {
            'circle-color': '#FF5A5F',
            'circle-radius': ['step', ['get', 'point_count'], 16, 10, 22, 30, 28],
            'circle-opacity': 0.9,
            'circle-stroke-width': 2,
            'circle-stroke-color': '#FFFFFF',
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
          id: 'unclustered-point-halo',
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
            'circle-radius': 16,
            'circle-opacity': 0.18,
          },
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
            'circle-radius': 11,
            'circle-stroke-width': 3,
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

  // Rejoue le cercle et le contenu affiché à chaque changement de rayon
  // ou de position (le cercle est centré sur MOI, pas sur le quartier).
  useEffect(() => {
    if (!mapReady || !mapRef.current) return;
    const map = mapRef.current;

    const circleSource = map.getSource('radius-circle');
    if (circleSource) {
      circleSource.setData(createCircleGeoJSON(originLat, originLng, radius));
    }

    const contentSource = map.getSource('content');
    if (contentSource) {
      contentSource.setData(toGeoJSON(filteredPoints));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [radius, mapReady, userPosition?.lat, userPosition?.lng]);

  // Marqueur "vous êtes ici" — point bleu avec halo, comme sur la plupart
  // des applications de carte. Élément DOM à part (maplibregl.Marker),
  // indépendant des couches de contenu groupé.
  useEffect(() => {
    if (!mapReady || !mapRef.current || !userPosition) return;

    if (!userMarkerRef.current) {
      const el = document.createElement('div');
      el.style.width = '18px';
      el.style.height = '18px';
      el.style.borderRadius = '50%';
      el.style.background = '#3B82F6';
      el.style.border = '3px solid white';
      el.style.boxShadow = '0 0 0 4px rgba(59, 130, 246, 0.25), 0 2px 6px rgba(0,0,0,0.3)';

      userMarkerRef.current = new maplibregl.Marker({ element: el })
        .setLngLat([userPosition.lng, userPosition.lat])
        .addTo(mapRef.current);

      mapRef.current.flyTo({ center: [userPosition.lng, userPosition.lat], zoom: 16, duration: 800 });
    } else {
      userMarkerRef.current.setLngLat([userPosition.lng, userPosition.lat]);
    }
  }, [mapReady, userPosition]);

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

echo "Pointeur et style ameliores avec succes."
echo "Prochaine etape : git add -A && git commit -m \"carte : pointeur ma position + marqueurs plus modernes\" && git push"
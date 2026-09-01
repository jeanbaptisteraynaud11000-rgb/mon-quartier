#!/usr/bin/env bash
set -e
echo "Fix critique : loadImage() est une Promise en MapLibre v4, pas un callback..."

mkdir -p "src/components/map"
cat > "src/components/map/QuartierMapView.jsx" << 'MQEOF_SRC_COMPONENTS_MAP_QUARTIERMAPVIEW_JSX'
'use client';

import { useEffect, useRef, useState } from 'react';
import maplibregl from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';
import MarkerBottomSheet from './MarkerBottomSheet';
import { createCircleGeoJSON } from '@/lib/geoCircle';
import { calculateDistance } from '@/lib/distanceCalculator';
import { createEmojiMarkerImage, CATEGORY_EMOJI } from '@/lib/mapMarkerIcons';

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

  // Le rayon est TOUJOURS centré sur le quartier — jamais sur la position
  // physique actuelle de l'utilisateur. Voyager ailleurs (une autre
  // ville...) ne doit jamais faire apparaître un cercle centré sur cet
  // ailleurs : Hoody montre le quartier d'appartenance, pas "autour de moi
  // en ce moment".
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

        // Vraies icônes en forme de pin fournies pour les annonces et
        // activités (chargement asynchrone, ce sont de vrais fichiers).
        // Pour les commerces (aucune image fournie pour ces catégories),
        // on garde le repli emoji dessiné sur canvas.
        const REAL_MARKER_CATEGORIES = new Set([
          'don', 'entraide', 'covoiturage', 'cherche', 'alerte',
          'sortie', 'musee', 'sport', 'jeux_de_societe',
        ]);

        const usedCategories = [...new Set(points.map((p) => p.category))];

        const loadPromises = usedCategories.map((category) => {
          const imageId = `marker-${category}`;
          if (map.hasImage(imageId)) return Promise.resolve();

          if (REAL_MARKER_CATEGORIES.has(category)) {
            // MapLibre GL v4 : loadImage() renvoie une Promise, ce n'est
            // plus une API à callback comme dans les versions plus
            // anciennes — c'est ce qui bloquait tout silencieusement.
            return map
              .loadImage(`/markers/${category}.png`)
              .then(({ data }) => {
                if (data && !map.hasImage(imageId)) {
                  map.addImage(imageId, data);
                }
              })
              .catch((err) => {
                console.error(`Impossible de charger l'icône ${category} :`, err);
              });
          }

          const spec = CATEGORY_EMOJI[category] || { emoji: '📍', color: '#999999' };
          map.addImage(imageId, createEmojiMarkerImage(spec.emoji, spec.color));
          return Promise.resolve();
        });

        Promise.all(loadPromises).then(() => {
          const realCategoriesPresent = usedCategories.filter((c) => REAL_MARKER_CATEGORIES.has(c));

          map.addLayer({
            id: 'unclustered-point',
            type: 'symbol',
            source: 'content',
            filter: ['!', ['has', 'point_count']],
            layout: {
              'icon-image': ['concat', 'marker-', ['get', 'category']],
              'icon-size':
                realCategoriesPresent.length > 0
                  ? ['match', ['get', 'category'], ...realCategoriesPresent.flatMap((c) => [c, 0.35]), 0.5]
                  : 0.5,
              'icon-anchor':
                realCategoriesPresent.length > 0
                  ? ['match', ['get', 'category'], ...realCategoriesPresent.flatMap((c) => [c, 'bottom']), 'center']
                  : 'center',
              'icon-allow-overlap': true,
            },
          });

          map.on('click', 'unclustered-point', (e) => {
            setSelectedPoint(e.features[0].properties);
          });

          map.on('mouseenter', 'unclustered-point', () => (map.getCanvas().style.cursor = 'pointer'));
          map.on('mouseleave', 'unclustered-point', () => (map.getCanvas().style.cursor = ''));
        }).catch((err) => {
          console.error('Erreur lors de l\'ajout des marqueurs :', err);
        });

        map.on('click', 'clusters', (e) => {
          const features = map.queryRenderedFeatures(e.point, { layers: ['clusters'] });
          const clusterId = features[0].properties.cluster_id;
          map.getSource('content').getClusterExpansionZoom(clusterId, (err, zoom) => {
            if (err) return;
            map.easeTo({ center: features[0].geometry.coordinates, zoom });
          });
        });

        map.on('mouseenter', 'clusters', () => (map.getCanvas().style.cursor = 'pointer'));
        map.on('mouseleave', 'clusters', () => (map.getCanvas().style.cursor = ''));

        setMapReady(true);

        // Marqueur fixe du centre du quartier — statique, ne dépend
        // d'aucune géolocalisation.
        const el = document.createElement('div');
        el.style.width = '14px';
        el.style.height = '14px';
        el.style.borderRadius = '50%';
        el.style.background = '#475569';
        el.style.border = '3px solid white';
        el.style.boxShadow = '0 2px 6px rgba(0,0,0,0.3)';
        el.title = 'Centre du quartier';
        new maplibregl.Marker({ element: el }).setLngLat([centerLng, centerLat]).addTo(map);
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

  // Rejoue le cercle et le contenu affiché à chaque changement de rayon —
  // toujours centré sur le quartier.
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
          Rayon (depuis le centre du quartier) :{' '}
          <span className="font-medium">{radius >= 1000 ? `${(radius / 1000).toFixed(1)} km` : `${radius} m`}</span>
          {' · '}
          {filteredPoints.length} élément{filteredPoints.length > 1 ? 's' : ''}
        </p>
      </div>

      <MarkerBottomSheet point={selectedPoint} onClose={() => setSelectedPoint(null)} />
    </div>
  );
}

MQEOF_SRC_COMPONENTS_MAP_QUARTIERMAPVIEW_JSX

echo "Correction appliquee avec succes."
echo "Prochaine etape : git add -A && git commit -m \"fix: loadImage() Promise API MapLibre v4\" && git push"
#!/usr/bin/env bash
set -e
echo "Correction : glyphes manquants bloquaient toute la carte..."

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
        const props = e.features[0].properties;
        setSelectedPoint(props);
      });

      map.on('mouseenter', 'clusters', () => (map.getCanvas().style.cursor = 'pointer'));
      map.on('mouseleave', 'clusters', () => (map.getCanvas().style.cursor = ''));
      map.on('mouseenter', 'unclustered-point', () => (map.getCanvas().style.cursor = 'pointer'));
      map.on('mouseleave', 'unclustered-point', () => (map.getCanvas().style.cursor = ''));
     } catch (err) {
       // Une erreur ici ne doit plus jamais bloquer silencieusement tout
       // le reste (c'est exactement ce qui s'est passé avec le premier
       // bug de police manquante) — au moins le fond de carte reste visible.
       console.error('Erreur lors du chargement des couches de la carte :', err);
     }
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

echo "Correction appliquee avec succes."
echo "Prochaine etape : git add -A && git commit -m \"fix: glyphes manquants bloquaient la carte\" && git push"
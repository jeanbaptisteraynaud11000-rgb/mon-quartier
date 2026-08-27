#!/usr/bin/env bash
set -e
echo "Ajout du chantier #6 (carte du quartier)..."

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
    "leaflet": "^1.9.4",
    "react-leaflet": "^4.2.1"
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

mkdir -p "src/app/onboarding"
cat > "src/app/onboarding/page.jsx" << 'MQEOF_SRC_APP_ONBOARDING_PAGE_JSX'
'use client';

import { useEffect, useState, useCallback, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';

// Statuts possibles de l'écran affiché
const SCREENS = {
  LOADING: 'loading',
  ADDRESS_FORM: 'address_form',
  QUARTIER_FOUND: 'quartier_found',
  NO_QUARTIER: 'no_quartier',
  MEMBERSHIP_PENDING: 'membership_pending',
  MEMBERSHIP_APPROVED: 'membership_approved',
  MEMBERSHIP_REJECTED: 'membership_rejected',
};

export default function OnboardingPage() {
  const router = useRouter();
  const [screen, setScreen] = useState(SCREENS.LOADING);
  const [error, setError] = useState('');

  // Recherche d'adresse
  const [query, setQuery] = useState('');
  const [suggestions, setSuggestions] = useState([]);
  const [searching, setSearching] = useState(false);
  const debounceRef = useRef(null);

  // Résultat de la détection
  const [detectedQuartier, setDetectedQuartier] = useState(null);
  const [selectedCoords, setSelectedCoords] = useState(null);
  const [selectedLabel, setSelectedLabel] = useState('');
  const [submitting, setSubmitting] = useState(false);

  // Étape 1 : vérifier si l'utilisateur a déjà une demande d'adhésion
  // en cours (évite de lui re-proposer l'onboarding à chaque visite).
  useEffect(() => {
    async function checkExistingMembership() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        router.push('/login');
        return;
      }

      const { data: memberships, error: fetchError } = await supabase
        .from('neighborhood_memberships')
        .select('status, quartiers(name, city)')
        .eq('user_id', user.id)
        .order('requested_at', { ascending: false })
        .limit(1);

      if (fetchError) {
        setError("Impossible de vérifier ton statut. Réessaie dans un instant.");
        setScreen(SCREENS.ADDRESS_FORM);
        return;
      }

      const latest = memberships?.[0];

      if (!latest) {
        setScreen(SCREENS.ADDRESS_FORM);
      } else if (latest.status === 'pending') {
        setDetectedQuartier(latest.quartiers);
        setScreen(SCREENS.MEMBERSHIP_PENDING);
      } else if (latest.status === 'approved') {
        setDetectedQuartier(latest.quartiers);
        setScreen(SCREENS.MEMBERSHIP_APPROVED);
      } else if (latest.status === 'rejected') {
        setScreen(SCREENS.MEMBERSHIP_REJECTED);
      } else {
        setScreen(SCREENS.ADDRESS_FORM);
      }
    }

    checkExistingMembership();
  }, [router]);

  // Autocomplétion via l'API Adresse (data.gouv.fr), avec un debounce de 300ms
  // pour ne pas spammer l'API à chaque frappe.
  const handleQueryChange = useCallback((value) => {
    setQuery(value);
    setDetectedQuartier(null);
    setSelectedCoords(null);

    if (debounceRef.current) clearTimeout(debounceRef.current);

    if (value.trim().length < 4) {
      setSuggestions([]);
      return;
    }

    debounceRef.current = setTimeout(async () => {
      setSearching(true);
      try {
        const res = await fetch(
          `https://api-adresse.data.gouv.fr/search/?q=${encodeURIComponent(value)}&limit=5`
        );
        const json = await res.json();
        setSuggestions(json.features || []);
      } catch {
        setSuggestions([]);
      } finally {
        setSearching(false);
      }
    }, 300);
  }, []);

  async function handleSelectSuggestion(feature) {
    const [lng, lat] = feature.geometry.coordinates;
    setQuery(feature.properties.label);
    setSelectedLabel(feature.properties.label);
    setSelectedCoords({ lat, lng });
    setSuggestions([]);

    // Appel de la fonction PostGIS (via RPC) pour savoir dans quel
    // quartier tombe ce point.
    const { data, error: rpcError } = await supabase.rpc('find_quartier_for_coordinates', {
      p_lat: lat,
      p_lng: lng,
    });

    if (rpcError) {
      setError("Impossible de vérifier ton quartier pour le moment. Réessaie.");
      return;
    }

    if (data && data.length > 0) {
      setDetectedQuartier(data[0]);
      setScreen(SCREENS.QUARTIER_FOUND);
    } else {
      setDetectedQuartier(null);
      setScreen(SCREENS.NO_QUARTIER);
    }
  }

  async function handleRequestMembership() {
    if (!detectedQuartier || !selectedCoords) return;
    setSubmitting(true);
    setError('');

    const { data: { user } } = await supabase.auth.getUser();

    // On sauvegarde les coordonnées AVANT la demande d'adhésion : la table
    // profile_locations est protégée par RLS (visible uniquement par son
    // propriétaire), donc aucun risque à l'écrire dès maintenant.
    const { error: locationError } = await supabase.from('profile_locations').upsert({
      user_id: user.id,
      lat: selectedCoords.lat,
      lng: selectedCoords.lng,
    });

    if (locationError) {
      setSubmitting(false);
      setError("Une erreur est survenue lors de l'enregistrement de ta position. Réessaie.");
      return;
    }

    const { error: insertError } = await supabase.from('neighborhood_memberships').insert({
      user_id: user.id,
      quartier_id: detectedQuartier.id,
      status: 'pending',
    });

    setSubmitting(false);

    if (insertError) {
      setError("Une erreur est survenue lors de l'envoi de ta demande. Réessaie.");
      return;
    }

    setScreen(SCREENS.MEMBERSHIP_PENDING);
  }

  // ---------------------------------------------------------------------
  // RENDU
  // ---------------------------------------------------------------------

  if (screen === SCREENS.LOADING) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="skeleton h-4 w-40" />
      </div>
    );
  }

  if (screen === SCREENS.MEMBERSHIP_PENDING) {
    return (
      <ScreenCard emoji="🕒" title="Ta demande est en cours d'examen">
        <p>
          Ta demande pour rejoindre{' '}
          <span className="font-medium text-content-primary">
            {detectedQuartier?.name} — {detectedQuartier?.city}
          </span>{' '}
          a bien été envoyée à l'administrateur du quartier.
        </p>
        <p className="mt-3">
          Tu peux déjà découvrir Mon Quartier en attendant. Certaines fonctionnalités
          (messagerie, recherche de voisins) seront disponibles après validation.
        </p>
        <button
          onClick={() => router.push('/')}
          className="mt-6 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover"
        >
          Découvrir Mon Quartier
        </button>
      </ScreenCard>
    );
  }

  if (screen === SCREENS.MEMBERSHIP_APPROVED) {
    return (
      <ScreenCard emoji="🎉" title="Tu fais partie du quartier !">
        <p>
          Ton adhésion à{' '}
          <span className="font-medium text-content-primary">
            {detectedQuartier?.name} — {detectedQuartier?.city}
          </span>{' '}
          est validée.
        </p>
        <button
          onClick={() => router.push('/')}
          className="mt-6 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover"
        >
          Découvrir mes voisins
        </button>
      </ScreenCard>
    );
  }

  if (screen === SCREENS.MEMBERSHIP_REJECTED) {
    return (
      <ScreenCard emoji="😕" title="Ta demande n'a pas été validée">
        <p>
          L'administrateur de quartier n'a pas pu valider ta demande. Tu peux
          réessayer avec une adresse différente.
        </p>
        <button
          onClick={() => setScreen(SCREENS.ADDRESS_FORM)}
          className="mt-6 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover"
        >
          Réessayer
        </button>
      </ScreenCard>
    );
  }

  return (
    <div className="flex min-h-screen flex-col p-6">
      <div className="mx-auto w-full max-w-sm">
        <h1 className="mb-1 text-2xl font-semibold text-content-primary">
          Où habites-tu ?
        </h1>
        <p className="mb-6 text-sm text-content-secondary">
          On va vérifier si Mon Quartier est disponible dans ton secteur.
        </p>

        <div className="relative">
          <input
            type="text"
            value={query}
            onChange={(e) => handleQueryChange(e.target.value)}
            placeholder="7 rue Édouard Branly, Hyères"
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />

          {suggestions.length > 0 && (
            <ul className="absolute z-10 mt-1 w-full overflow-hidden rounded-card border border-border bg-surface shadow-soft">
              {suggestions.map((feature) => (
                <li key={feature.properties.id}>
                  <button
                    onClick={() => handleSelectSuggestion(feature)}
                    className="w-full px-4 py-3 text-left text-sm text-content-primary transition-fast hover:bg-surface-card"
                  >
                    {feature.properties.label}
                  </button>
                </li>
              ))}
            </ul>
          )}

          {searching && (
            <p className="mt-2 text-xs text-content-secondary">Recherche...</p>
          )}
        </div>

        {error && <p className="mt-4 text-sm text-corail">{error}</p>}

        {screen === SCREENS.QUARTIER_FOUND && detectedQuartier && (
          <div className="mt-6 rounded-card border border-border bg-surface-card p-4">
            <p className="text-sm text-content-secondary">Votre quartier semble être :</p>
            <p className="mt-1 text-lg font-semibold text-content-primary">
              {detectedQuartier.name} — {detectedQuartier.city}
            </p>
            <button
              onClick={handleRequestMembership}
              disabled={submitting}
              className="mt-4 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
            >
              {submitting ? 'Envoi...' : 'Demander à rejoindre ce quartier'}
            </button>
          </div>
        )}

        {screen === SCREENS.NO_QUARTIER && (
          <div className="mt-6 rounded-card border border-border bg-surface-card p-4">
            <p className="text-sm text-content-primary">
              Mon Quartier n'est pas encore disponible dans votre secteur.
            </p>
            <p className="mt-2 text-xs text-content-secondary">
              {selectedLabel}
            </p>
            {/* NOTE : le vrai bouton "être prévenu" nécessite une table
                d'attente dédiée — à ajouter dans un chantier ultérieur si
                cette fonctionnalité est jugée prioritaire. */}
          </div>
        )}
      </div>
    </div>
  );
}

function ScreenCard({ emoji, title, children }) {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center p-6 text-center">
      <div className="mx-auto w-full max-w-sm">
        <div className="mb-4 text-4xl">{emoji}</div>
        <h1 className="mb-2 text-xl font-semibold text-content-primary">{title}</h1>
        <div className="text-sm text-content-secondary">{children}</div>
      </div>
    </div>
  );
}

MQEOF_SRC_APP_ONBOARDING_PAGE_JSX

mkdir -p "src/app/voisins"
cat > "src/app/voisins/page.jsx" << 'MQEOF_SRC_APP_VOISINS_PAGE_JSX'
// Server Component : annuaire des voisins du quartier.
//
// NOTE SUR LA PORTÉE : la vraie carte géographique interactive (section 7
// du prompt maître) est volontairement laissée pour un chantier dédié —
// elle nécessite une bibliothèque de cartographie (Leaflet/Mapbox) ET de
// stocker les coordonnées approximatives de chaque utilisateur, qu'on ne
// conserve pas encore aujourd'hui (seul le polygone du quartier existe).
// Cette page couvre déjà la partie utile immédiatement : voir qui fait
// partie de son quartier, dans le respect des préférences de vie privée.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import NeighborhoodMapWrapper from '@/components/map/NeighborhoodMapWrapper';

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
    .select('quartier_id, quartiers(name, city, center_lat, center_lng)')
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

  // Périmètre du quartier + positions floutées des voisins, calculés
  // côté base de données (voir migration 008) — on ne manipule ici que des
  // coordonnées déjà anonymisées, jamais les adresses exactes.
  const [{ data: boundary }, { data: mapPoints }] = await Promise.all([
    supabase.rpc('get_quartier_boundary', { p_quartier_id: myProfile.quartier_id }),
    supabase.rpc('get_neighborhood_map_points', { p_quartier_id: myProfile.quartier_id }),
  ]);

  // On respecte map_visibility = 'off' comme un choix général de discrétion,
  // pas seulement pour la carte à venir : quelqu'un qui a explicitement
  // demandé à ne pas apparaître ne doit pas se retrouver listé ici non plus.
  // Limite à 50 : mesure simple anti-scraping (section 83) en attendant une
  // vraie pagination si le quartier grossit.
  const { data: neighbors, error } = await supabase
    .from('profiles')
    .select('user_id, display_name, created_at, map_visibility')
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

      {myProfile.quartiers?.center_lat && (
        <NeighborhoodMapWrapper
          centerLat={myProfile.quartiers.center_lat}
          centerLng={myProfile.quartiers.center_lng}
          boundary={boundary}
          points={mapPoints || []}
        />
      )}

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
              <div className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-pill bg-corail/10 font-semibold text-corail">
                {initial}
              </div>
              <div className="min-w-0 flex-1">
                <p className="truncate font-medium text-content-primary">
                  {neighbor.display_name || 'Voisin'} {isMe && '(toi)'}
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

mkdir -p "src/components/map"
cat > "src/components/map/NeighborhoodMap.jsx" << 'MQEOF_SRC_COMPONENTS_MAP_NEIGHBORHOODMAP_JSX'
'use client';

import { MapContainer, TileLayer, GeoJSON, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

// Icône personnalisée (cercle corail) plutôt que le pin par défaut de
// Leaflet, dont les images cassent systématiquement avec les bundlers
// modernes (Webpack/Next) sans configuration supplémentaire.
const neighborIcon = L.divIcon({
  className: '',
  html: '<div style="width:16px;height:16px;border-radius:50%;background:#FF5A5F;border:2px solid white;box-shadow:0 1px 4px rgba(0,0,0,0.3);"></div>',
  iconSize: [16, 16],
  iconAnchor: [8, 8],
});

const boundaryStyle = {
  color: '#FF5A5F',
  weight: 2,
  fillColor: '#FF5A5F',
  fillOpacity: 0.05,
};

export default function NeighborhoodMap({ centerLat, centerLng, boundary, points }) {
  return (
    <MapContainer
      center={[centerLat, centerLng]}
      zoom={15}
      scrollWheelZoom={false}
      style={{ height: '280px', width: '100%', borderRadius: '1rem' }}
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />

      {boundary && <GeoJSON data={boundary} style={boundaryStyle} />}

      {points.map((point) => (
        <Marker key={point.user_id} position={[point.lat, point.lng]} icon={neighborIcon}>
          <Popup>{point.display_name || 'Voisin'}</Popup>
        </Marker>
      ))}
    </MapContainer>
  );
}

MQEOF_SRC_COMPONENTS_MAP_NEIGHBORHOODMAP_JSX

mkdir -p "src/components/map"
cat > "src/components/map/NeighborhoodMapWrapper.jsx" << 'MQEOF_SRC_COMPONENTS_MAP_NEIGHBORHOODMAPWRAPPER_JSX'
'use client';

import dynamic from 'next/dynamic';

// Leaflet accède à `window`/`document` dès son import, ce qui casse le
// rendu côté serveur de Next.js. `ssr: false` force ce composant à ne se
// charger que dans le navigateur.
const NeighborhoodMap = dynamic(() => import('./NeighborhoodMap'), {
  ssr: false,
  loading: () => <div className="skeleton" style={{ height: '280px', width: '100%' }} />,
});

export default function NeighborhoodMapWrapper(props) {
  return <NeighborhoodMap {...props} />;
}

MQEOF_SRC_COMPONENTS_MAP_NEIGHBORHOODMAPWRAPPER_JSX

echo "Chantier #6 ajoute avec succes."
echo "IMPORTANT : lance npm install avant npm run dev (nouvelles dependances leaflet)"
echo "Prochaine etape : npm install && git add -A && git commit -m \"chantier 6 : carte du quartier\" && git push"
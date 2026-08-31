#!/usr/bin/env bash
set -e
echo "Ajout commerces locaux + calcul de distance..."

mkdir -p "src/lib"
cat > "src/lib/distanceCalculator.js" << 'MQEOF_SRC_LIB_DISTANCECALCULATOR_JS'
// Calcul de distance entre deux points GPS (formule de Haversine).
// Utilisé pour trier les commerces par proximité — à partir de la
// géolocalisation LIVE du navigateur (jamais stockée), pas des coordonnées
// de résidence de l'utilisateur qu'on ne conserve plus.

export function calculateDistance(lat1, lon1, lat2, lon2) {
  if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
    return Infinity;
  }
  const R = 6371; // rayon de la Terre en km
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRadians(degrees) {
  return degrees * (Math.PI / 180);
}

export function formatDistance(distanceKm) {
  if (!isFinite(distanceKm)) return null;
  if (distanceKm < 0.1) return 'À proximité';
  if (distanceKm < 1) return `${Math.round(distanceKm * 1000)} m`;
  return `${distanceKm.toFixed(1)} km`;
}

// Trie une liste d'éléments {lat, lng, ...} par distance croissante à
// partir d'une position donnée. Les éléments sans coordonnées passent en
// dernier plutôt que d'être exclus.
export function sortByDistance(items, userLat, userLng) {
  if (userLat == null || userLng == null) return items;
  return [...items]
    .map((item) => ({ ...item, _distance: calculateDistance(userLat, userLng, item.lat, item.lng) }))
    .sort((a, b) => a._distance - b._distance);
}

MQEOF_SRC_LIB_DISTANCECALCULATOR_JS

mkdir -p "src/lib"
cat > "src/lib/placeCategories.js" << 'MQEOF_SRC_LIB_PLACECATEGORIES_JS'
import { Store, UtensilsCrossed, Stethoscope, Palette, Wrench, Landmark, MoreHorizontal } from 'lucide-react';

export const PLACE_CATEGORIES = [
  { category: 'commerce', label: 'Commerce', icon: Store },
  { category: 'restaurant', label: 'Restauration', icon: UtensilsCrossed },
  { category: 'sante', label: 'Santé', icon: Stethoscope },
  { category: 'loisirs', label: 'Loisirs', icon: Palette },
  { category: 'service', label: 'Service', icon: Wrench },
  { category: 'site_touristique', label: 'Site touristique', icon: Landmark },
  { category: 'autre', label: 'Autre', icon: MoreHorizontal },
];

export function getPlaceCategoryInfo(category) {
  return PLACE_CATEGORIES.find((c) => c.category === category) || { label: category, icon: MoreHorizontal };
}

MQEOF_SRC_LIB_PLACECATEGORIES_JS

mkdir -p "src/app/commerces"
cat > "src/app/commerces/page.jsx" << 'MQEOF_SRC_APP_COMMERCES_PAGE_JSX'
'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';
import { PLACE_CATEGORIES, getPlaceCategoryInfo } from '@/lib/placeCategories';
import { sortByDistance, formatDistance } from '@/lib/distanceCalculator';

export default function CommercesPage() {
  const [places, setPlaces] = useState([]);
  const [loading, setLoading] = useState(true);
  const [activeCategory, setActiveCategory] = useState(null);
  const [userPosition, setUserPosition] = useState(null);
  const [geoDenied, setGeoDenied] = useState(false);
  const [noQuartier, setNoQuartier] = useState(false);

  useEffect(() => {
    async function load() {
      const { data: { user } } = await supabase.auth.getUser();
      const { data: profile } = await supabase
        .from('profiles')
        .select('quartier_id')
        .eq('user_id', user.id)
        .single();

      if (!profile?.quartier_id) {
        setNoQuartier(true);
        setLoading(false);
        return;
      }

      const { data } = await supabase
        .from('places')
        .select('id, category, name, description, address, lat, lng')
        .eq('quartier_id', profile.quartier_id)
        .order('created_at', { ascending: false });

      setPlaces(data || []);
      setLoading(false);
    }
    load();

    // Géolocalisation LIVE, jamais stockée — juste pour trier l'affichage
    // du moment. Dégradation propre si refusée ou indisponible.
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (pos) => setUserPosition({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
        () => setGeoDenied(true),
        { timeout: 5000 }
      );
    } else {
      setGeoDenied(true);
    }
  }, []);

  if (noQuartier) {
    return (
      <div className="p-4">
        <div className="rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">
            Termine d'abord ton inscription pour voir les commerces de ton quartier.
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

  const filtered = activeCategory ? places.filter((p) => p.category === activeCategory) : places;
  const sorted = userPosition ? sortByDistance(filtered, userPosition.lat, userPosition.lng) : filtered;

  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-content-primary">Commerces & lieux</h1>
        <Link
          href="/commerces/new"
          className="rounded-pill bg-corail px-4 py-2 text-sm font-medium text-white transition-fast hover:bg-corail-hover"
        >
          Ajouter
        </Link>
      </div>

      {geoDenied && (
        <p className="text-xs text-content-secondary">
          Active ta localisation pour voir les distances.
        </p>
      )}

      <div className="flex gap-2 overflow-x-auto pb-1">
        <button
          onClick={() => setActiveCategory(null)}
          className={`flex-shrink-0 rounded-pill border px-4 py-2 text-sm font-medium transition-fast ${
            !activeCategory ? 'border-corail bg-corail text-white' : 'border-border bg-surface text-content-primary'
          }`}
        >
          Tous
        </button>
        {PLACE_CATEGORIES.map((cat) => {
          const Icon = cat.icon;
          return (
            <button
              key={cat.category}
              onClick={() => setActiveCategory(cat.category)}
              className={`flex flex-shrink-0 items-center gap-1.5 rounded-pill border px-4 py-2 text-sm font-medium transition-fast ${
                activeCategory === cat.category
                  ? 'border-corail bg-corail text-white'
                  : 'border-border bg-surface text-content-primary'
              }`}
            >
              <Icon size={14} /> {cat.label}
            </button>
          );
        })}
      </div>

      {loading && <div className="skeleton h-20 w-full" />}

      {!loading && sorted.length === 0 && (
        <div className="rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">Aucun commerce référencé pour l'instant.</p>
          <Link href="/commerces/new" className="mt-3 inline-block font-medium text-corail">
            Ajouter le premier →
          </Link>
        </div>
      )}

      <div className="flex flex-col gap-2">
        {sorted.map((place) => {
          const catInfo = getPlaceCategoryInfo(place.category);
          const Icon = catInfo.icon;
          const distance = place._distance !== undefined ? formatDistance(place._distance) : null;
          return (
            <Link
              key={place.id}
              href={`/commerces/${place.id}`}
              className="flex items-center gap-3 rounded-card border border-border bg-surface-card p-3 transition-fast hover:bg-border/20"
            >
              <div className="flex h-11 w-11 flex-shrink-0 items-center justify-center rounded-pill bg-surface text-content-secondary">
                <Icon size={19} />
              </div>
              <div className="min-w-0 flex-1">
                <p className="truncate font-medium text-content-primary">{place.name}</p>
                <p className="truncate text-xs text-content-secondary">
                  {catInfo.label}{place.address ? ` · ${place.address}` : ''}
                </p>
              </div>
              {distance && (
                <span className="flex-shrink-0 text-xs font-medium text-content-secondary">{distance}</span>
              )}
            </Link>
          );
        })}
      </div>
    </div>
  );
}

MQEOF_SRC_APP_COMMERCES_PAGE_JSX

mkdir -p "src/app/commerces/[id]"
cat > "src/app/commerces/[id]/page.jsx" << 'MQEOF_SRC_APP_COMMERCES_ID_PAGE_JSX'
// Server Component : détail d'un commerce. RLS "places_select_own_quartier"
// garantit déjà l'isolation par quartier.

import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { getPlaceCategoryInfo } from '@/lib/placeCategories';

export default async function PlaceDetailPage({ params }) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: place, error } = await supabase
    .from('places')
    .select('id, category, name, description, address, phone, website, added_by')
    .eq('id', id)
    .single();

  if (error || !place) {
    notFound();
  }

  const catInfo = getPlaceCategoryInfo(place.category);
  const Icon = catInfo.icon;

  return (
    <div className="flex flex-col gap-5 p-4">
      <Link href="/commerces" className="text-sm font-medium text-content-secondary">
        ← Retour
      </Link>

      <div className="rounded-card border border-border bg-surface-card p-5">
        <div className="flex items-center gap-2">
          <span className="flex h-8 w-8 items-center justify-center rounded-pill bg-surface text-content-secondary">
            <Icon size={16} />
          </span>
          <span className="text-sm font-medium text-content-secondary">{catInfo.label}</span>
        </div>

        <h1 className="mt-3 text-xl font-semibold text-content-primary">{place.name}</h1>

        {place.address && (
          <p className="mt-2 text-sm text-content-secondary">{place.address}</p>
        )}

        {place.description && (
          <p className="mt-4 whitespace-pre-wrap text-content-primary">{place.description}</p>
        )}

        {(place.phone || place.website) && (
          <div className="mt-4 flex flex-col gap-1 border-t border-border pt-4">
            {place.phone && (
              <a href={`tel:${place.phone}`} className="text-sm font-medium text-corail">
                {place.phone}
              </a>
            )}
            {place.website && (
              <a
                href={place.website.startsWith('http') ? place.website : `https://${place.website}`}
                target="_blank"
                rel="noopener noreferrer"
                className="text-sm font-medium text-corail"
              >
                {place.website}
              </a>
            )}
          </div>
        )}
      </div>

      <p className="text-center text-xs text-content-secondary">
        Ajouté par un habitant du quartier. Vérifie les informations avant de te déplacer.
      </p>
    </div>
  );
}

MQEOF_SRC_APP_COMMERCES_ID_PAGE_JSX

mkdir -p "src/app/commerces/new"
cat > "src/app/commerces/new/page.jsx" << 'MQEOF_SRC_APP_COMMERCES_NEW_PAGE_JSX'
'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { PLACE_CATEGORIES } from '@/lib/placeCategories';

export default function NewPlacePage() {
  const router = useRouter();

  const [quartierId, setQuartierId] = useState(null);
  const [loadingProfile, setLoadingProfile] = useState(true);

  const [category, setCategory] = useState('commerce');
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [phone, setPhone] = useState('');
  const [website, setWebsite] = useState('');

  const [addressQuery, setAddressQuery] = useState('');
  const [suggestions, setSuggestions] = useState([]);
  const [selectedAddress, setSelectedAddress] = useState(null); // { label, lat, lng }
  const debounceRef = useRef(null);

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

  function handleAddressChange(value) {
    setAddressQuery(value);
    setSelectedAddress(null);

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
    setAddressQuery(feature.properties.label);
    setSelectedAddress({ label: feature.properties.label, lat, lng });
    setSuggestions([]);
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');

    if (hasSubmittedRef.current) return;
    if (!name.trim()) {
      setError('Le nom est obligatoire.');
      return;
    }

    hasSubmittedRef.current = true;
    setSubmitting(true);

    const { data: { user } } = await supabase.auth.getUser();

    const { data: newPlace, error: insertError } = await supabase
      .from('places')
      .insert({
        quartier_id: quartierId,
        added_by: user.id,
        category,
        name: name.trim(),
        description: description.trim() || null,
        address: selectedAddress?.label || addressQuery.trim() || null,
        lat: selectedAddress?.lat || null,
        lng: selectedAddress?.lng || null,
        phone: phone.trim() || null,
        website: website.trim() || null,
      })
      .select('id')
      .single();

    setSubmitting(false);

    if (insertError || !newPlace) {
      hasSubmittedRef.current = false;
      setError('Une erreur est survenue. Réessaie.');
      return;
    }

    router.push(`/commerces/${newPlace.id}`);
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
      <h1 className="mb-6 text-xl font-semibold text-content-primary">Ajouter un commerce ou lieu</h1>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <div>
          <label className="mb-1 block text-sm font-medium text-content-primary">Catégorie</label>
          <div className="grid grid-cols-2 gap-2">
            {PLACE_CATEGORIES.map((cat) => {
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
          <label htmlFor="name" className="mb-1 block text-sm font-medium text-content-primary">
            Nom
          </label>
          <input
            id="name"
            type="text"
            required
            maxLength={100}
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Ex : Boulangerie du Centre"
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        <div className="relative">
          <label htmlFor="address" className="mb-1 block text-sm font-medium text-content-primary">
            Adresse <span className="text-content-secondary">(optionnel)</span>
          </label>
          <input
            id="address"
            type="text"
            value={addressQuery}
            onChange={(e) => handleAddressChange(e.target.value)}
            placeholder="Commence à taper une adresse..."
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
          <label htmlFor="description" className="mb-1 block text-sm font-medium text-content-primary">
            Description <span className="text-content-secondary">(optionnel)</span>
          </label>
          <textarea
            id="description"
            rows={3}
            maxLength={500}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            className="w-full resize-none rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        <div>
          <label htmlFor="phone" className="mb-1 block text-sm font-medium text-content-primary">
            Téléphone <span className="text-content-secondary">(optionnel)</span>
          </label>
          <input
            id="phone"
            type="tel"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        <div>
          <label htmlFor="website" className="mb-1 block text-sm font-medium text-content-primary">
            Site web <span className="text-content-secondary">(optionnel)</span>
          </label>
          <input
            id="website"
            type="text"
            value={website}
            onChange={(e) => setWebsite(e.target.value)}
            placeholder="exemple.fr"
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        {error && <p className="text-sm text-corail">{error}</p>}

        <button
          type="submit"
          disabled={submitting}
          className="mt-2 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
        >
          {submitting ? 'Ajout...' : 'Ajouter'}
        </button>
      </form>
    </div>
  );
}

MQEOF_SRC_APP_COMMERCES_NEW_PAGE_JSX

mkdir -p "src/app/profile"
cat > "src/app/profile/page.jsx" << 'MQEOF_SRC_APP_PROFILE_PAGE_JSX'
'use client';

// Placeholder enrichi le temps du chantier auth/communauté — la vraie page
// profil (avatar, bio, badges, stats...) sera construite au chantier dédié.

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { getLevel } from '@/lib/levels';

export default function ProfilePage() {
  const router = useRouter();
  const [inviteLink, setInviteLink] = useState('');
  const [generating, setGenerating] = useState(false);
  const [inviteError, setInviteError] = useState('');
  const [copied, setCopied] = useState(false);
  const [role, setRole] = useState(null);
  const [points, setPoints] = useState(0);

  useEffect(() => {
    async function loadRole() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;
      const { data: profile } = await supabase
        .from('profiles')
        .select('role, points')
        .eq('user_id', user.id)
        .single();
      setRole(profile?.role);
      setPoints(profile?.points || 0);
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
      <div className="rounded-card border border-border bg-surface-card p-4 text-center">
        <p className="text-sm font-medium text-corail">{getLevel(points).label}</p>
        <p className="mt-1 text-xs text-content-secondary">
          {points} point{points > 1 ? 's' : ''} de contribution
        </p>
      </div>

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
        <Link href="/commerces" className="rounded-card px-3 py-2 text-sm text-content-primary hover:bg-surface">
          Commerces & lieux du quartier
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
  );
}

MQEOF_SRC_APP_PROFILE_PAGE_JSX

mkdir -p "src/app"
cat > "src/app/page.jsx" << 'MQEOF_SRC_APP_PAGE_JSX'
// Page d'accueil — Server Component.
//
// Direction visuelle : peu de couleur (le corail/vert de la marque
// n'intervient plus que sur les icônes, jamais en fond plein), grandes
// zones photo/illustration, hiérarchie typographique nette, beaucoup
// d'espace. L'alerte la plus récente a sa propre carte pleine largeur —
// c'est l'info la plus urgente, elle mérite la meilleure place.
//
// Volontairement exclu (cohérent avec la section 80 du prompt maître) :
// pas de "vu par X personnes", pas de tri algorithmique par popularité,
// pas de notification-appât. Le fil reste chronologique, l'app reste utile
// plutôt qu'accrocheuse.

import Link from 'next/link';
import { Search, Users, Store } from 'lucide-react';
import { createClient } from '@/lib/supabase/server';
import { POST_TYPES, getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';
import { getEventCategoryInfo, formatEventDate } from '@/lib/eventCategories';

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

  const [neighborsCount, featuredAlertResult, feedResult, upcomingEventsResult] = await Promise.all([
    supabase
      .from('profiles')
      .select('*', { count: 'exact', head: true })
      .eq('quartier_id', quartierId),
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
      .select('id, type, title, created_at, user_id')
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .neq('type', 'alerte')
      .order('created_at', { ascending: false })
      .limit(4),
    supabase
      .from('events')
      .select('id, category, title, event_date, max_attendees')
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .gte('event_date', new Date().toISOString())
      .order('event_date', { ascending: true })
      .limit(4),
  ]);

  const featuredAlert = featuredAlertResult.data;
  const feed = feedResult.data || [];
  const upcomingEvents = upcomingEventsResult.data || [];

  // Requêtes séparées : pas de FK directe posts/events → profiles, et on
  // récupère la 1ère photo de chaque annonce pour l'illustration de carte.
  const relevantUserIds = [
    ...new Set([featuredAlert?.user_id, ...feed.map((p) => p.user_id)].filter(Boolean)),
  ];
  const feedPostIds = feed.map((p) => p.id);

  const [{ data: authors }, { data: images }, { data: attendees }] = await Promise.all([
    relevantUserIds.length > 0
      ? supabase.from('profiles').select('user_id, display_name').in('user_id', relevantUserIds)
      : Promise.resolve({ data: [] }),
    feedPostIds.length > 0
      ? supabase.from('post_images').select('post_id, storage_path, position').in('post_id', feedPostIds).order('position', { ascending: true })
      : Promise.resolve({ data: [] }),
    upcomingEvents.length > 0
      ? supabase.from('event_attendees').select('event_id').in('event_id', upcomingEvents.map((e) => e.id))
      : Promise.resolve({ data: [] }),
  ]);

  const authorName = Object.fromEntries((authors || []).map((a) => [a.user_id, a.display_name]));

  const thumbnailByPost = {};
  for (const img of images || []) {
    if (!thumbnailByPost[img.post_id]) {
      thumbnailByPost[img.post_id] = supabase.storage.from('posts').getPublicUrl(img.storage_path).data.publicUrl;
    }
  }

  const attendeeCounts = {};
  for (const a of attendees || []) {
    attendeeCounts[a.event_id] = (attendeeCounts[a.event_id] || 0) + 1;
  }

  return (
    <div className="flex flex-col p-4">
      <h1 className="text-xl font-semibold text-content-primary">
        {firstName ? `Bonjour ${firstName}` : 'Bonjour'}
      </h1>
      <p className="mt-1 text-sm text-content-secondary">
        Voici ce qui se passe près de chez toi.
      </p>

      {/* Barre de recherche — pour l'instant amène simplement aux annonces ;
          une vraie recherche (annonces + voisins) est prévue dans un
          prochain chantier (section 46 du prompt maître). */}
      <Link
        href="/annonces"
        className="mt-5 flex items-center gap-3 rounded-pill border border-border px-4 py-3 transition-fast hover:border-content-secondary"
      >
        <Search size={17} className="text-content-secondary" />
        <span className="text-sm text-content-secondary">Rechercher dans le quartier</span>
      </Link>

      {/* Catégories — traitement neutre, pas de fond coloré */}
      <div className="-mx-4 mt-6 flex gap-6 overflow-x-auto px-4 pb-1">
        {POST_TYPES.map((cat) => {
          const Icon = cat.icon;
          return (
            <Link
              key={cat.type}
              href={`/annonces?type=${cat.type}`}
              className="flex flex-shrink-0 flex-col items-center gap-2 pb-2 text-content-secondary transition-fast hover:text-content-primary"
            >
              <Icon size={22} />
              <span className="text-xs">{cat.label}</span>
            </Link>
          );
        })}
      </div>

      {/* Alerte la plus récente — pleine largeur, mise en avant */}
      {featuredAlert && (
        <Link
          href={`/annonces/${featuredAlert.id}`}
          className="mt-6 flex items-start gap-3 rounded-card bg-amber-50 p-4 transition-fast hover:bg-amber-100"
        >
          <div className="mt-0.5 flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-pill bg-amber-100 text-amber-700">
            {(() => {
              const AlertIcon = getPostTypeInfo('alerte').icon;
              return <AlertIcon size={16} />;
            })()}
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

      {/* Fil "Près de chez toi" — même format carte que les activités */}
      {feed.length > 0 && (
        <section className="mt-8">
          <div className="mb-3 flex items-baseline justify-between">
            <h2 className="text-base font-semibold text-content-primary">Près de chez toi</h2>
          </div>

          <div className="grid grid-cols-2 gap-3">
            {feed.map((post) => {
              const typeInfo = getPostTypeInfo(post.type);
              const Icon = typeInfo.icon;
              const thumbnail = thumbnailByPost[post.id];
              return (
                <Link key={post.id} href={`/annonces/${post.id}`}>
                  <div className="relative h-24 w-full overflow-hidden rounded-card bg-surface-card">
                    {thumbnail ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={thumbnail} alt="" className="h-full w-full object-cover" />
                    ) : (
                      <div className="flex h-full w-full items-center justify-center text-content-secondary">
                        <Icon size={24} />
                      </div>
                    )}
                  </div>
                  <p className="mt-2 line-clamp-2 text-sm font-medium text-content-primary">
                    {post.title}
                  </p>
                  <p className="mt-0.5 text-xs text-content-secondary">
                    {authorName[post.user_id] || 'Voisin'} · {formatRelativeTime(post.created_at)}
                  </p>
                </Link>
              );
            })}
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
        <div className="mt-8 rounded-card border border-border bg-surface-card p-6 text-center text-sm text-content-secondary">
          Rien de nouveau pour l'instant.
          <div className="mt-2">
            <Link href="/new" className="font-medium text-corail">
              Sois le premier à publier →
            </Link>
          </div>
        </div>
      )}

      {/* Prochaines activités */}
      {upcomingEvents.length > 0 && (
        <section className="mt-8">
          <div className="mb-3 flex items-baseline justify-between">
            <h2 className="text-base font-semibold text-content-primary">Prochaines activités</h2>
            <Link href="/activites" className="text-xs text-content-secondary">
              Tout voir
            </Link>
          </div>

          <div className="-mx-4 flex gap-3 overflow-x-auto px-4 pb-1">
            {upcomingEvents.map((event) => {
              const catInfo = getEventCategoryInfo(event.category);
              const Icon = catInfo.icon;
              const count = attendeeCounts[event.id] || 0;
              const isFull = count >= event.max_attendees;
              return (
                <Link key={event.id} href={`/activites/${event.id}`} className="w-40 flex-shrink-0">
                  <div className="flex h-24 w-full items-center justify-center rounded-card bg-surface-card text-content-secondary">
                    <Icon size={24} />
                  </div>
                  <p className="mt-2 line-clamp-2 text-sm font-medium text-content-primary">
                    {event.title}
                  </p>
                  <p className={`mt-0.5 text-xs ${isFull ? 'text-corail' : 'text-content-secondary'}`}>
                    {formatEventDate(event.event_date)} · {isFull ? 'Complet' : `${count}/${event.max_attendees}`}
                  </p>
                </Link>
              );
            })}
          </div>
        </section>
      )}

      <Link
        href="/commerces"
        className="mt-3 flex items-center justify-between rounded-card border border-border p-4 transition-fast hover:border-content-secondary"
      >
        <div className="flex items-center gap-3">
          <Store size={18} className="text-content-secondary" />
          <span className="text-sm text-content-primary">Commerces & lieux du quartier</span>
        </div>
        <span className="text-xs text-content-secondary">Voir</span>
      </Link>

      <Link
        href="/voisins"
        className="mt-3 flex items-center justify-between rounded-card border border-border p-4 transition-fast hover:border-content-secondary"
      >
        <div className="flex items-center gap-3">
          <Users size={18} className="text-content-secondary" />
          <span className="text-sm text-content-primary">
            {neighborsCount.count ?? 0} voisin{(neighborsCount.count ?? 0) > 1 ? 's' : ''} dans ce quartier
          </span>
        </div>
        <span className="text-xs text-content-secondary">Voir</span>
      </Link>
    </div>
  );
}

MQEOF_SRC_APP_PAGE_JSX

echo "Commerces + distance ajoutes avec succes."
echo "Prochaine etape : executer la migration 018, puis git add -A && git commit -m \"commerces locaux + tri par distance\" && git push"
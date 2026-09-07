#!/usr/bin/env bash
set -e
echo "Simplification du parcours onboarding..."

mkdir -p "src/app/onboarding"
cat > "src/app/onboarding/page.jsx" << 'MQEOF_SRC_APP_ONBOARDING_PAGE_JSX'
'use client';

import { useEffect, useState, useCallback, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';

// Parcours simplifié : adresse → quartier trouvé/créé → "Visiter mon
// quartier" → accueil. Toute adhésion est auto-approuvée instantanément
// (migration 005) — il n'y a plus de vrai état "en attente" à afficher,
// donc plus d'écrans intermédiaires pour ça.
const SCREENS = {
  LOADING: 'loading',
  ADDRESS_FORM: 'address_form',
  QUARTIER_FOUND: 'quartier_found',
  NO_QUARTIER: 'no_quartier',
};

export default function OnboardingPage() {
  const router = useRouter();
  const [screen, setScreen] = useState(SCREENS.LOADING);
  const [error, setError] = useState('');

  const [query, setQuery] = useState('');
  const [suggestions, setSuggestions] = useState([]);
  const [searching, setSearching] = useState(false);
  const debounceRef = useRef(null);

  const [detectedQuartier, setDetectedQuartier] = useState(null);
  const [selectedLabel, setSelectedLabel] = useState('');
  const [submitting, setSubmitting] = useState(false);

  // Si la personne a déjà un quartier (déjà inscrite), on ne repasse
  // jamais par l'onboarding — direction l'accueil immédiatement.
  useEffect(() => {
    async function checkAlreadyMember() {
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

      if (profile?.quartier_id) {
        router.push('/');
        return;
      }

      setScreen(SCREENS.ADDRESS_FORM);
    }

    checkAlreadyMember();
  }, [router]);

  const handleQueryChange = useCallback((value) => {
    setQuery(value);
    setDetectedQuartier(null);

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
    const city = feature.properties.city || feature.properties.name;
    const postcode = feature.properties.postcode || null;

    setQuery(feature.properties.label);
    setSelectedLabel(feature.properties.label);
    setSuggestions([]);

    const { data, error: rpcError } = await supabase.rpc('find_or_create_quartier', {
      p_lat: lat,
      p_lng: lng,
      p_city: city,
      p_postal_code: postcode,
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

  // Rejoint le quartier ET va directement à l'accueil — pas d'écran
  // intermédiaire "en attente" ou "approuvé", puisque l'adhésion est
  // instantanée.
  async function handleVisitQuartier() {
    if (!detectedQuartier) return;
    setSubmitting(true);
    setError('');

    const { data: { user } } = await supabase.auth.getUser();

    const { error: insertError } = await supabase.from('neighborhood_memberships').insert({
      user_id: user.id,
      quartier_id: detectedQuartier.id,
      status: 'pending',
    });

    if (insertError) {
      setSubmitting(false);
      setError("Une erreur est survenue. Réessaie.");
      return;
    }

    router.push('/');
    router.refresh();
  }

  if (screen === SCREENS.LOADING) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="skeleton h-4 w-40" />
      </div>
    );
  }

  return (
    <div className="flex min-h-screen flex-col p-6">
      <div className="mx-auto w-full max-w-sm">
        <h1 className="mb-1 text-2xl font-semibold text-content-primary">
          Où habites-tu ?
        </h1>
        <p className="mb-6 text-sm text-content-secondary">
          On va vérifier si Hoody est disponible dans ton secteur.
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
              onClick={handleVisitQuartier}
              disabled={submitting}
              className="mt-4 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
            >
              {submitting ? 'Un instant...' : 'Visiter mon quartier'}
            </button>
          </div>
        )}

        {screen === SCREENS.NO_QUARTIER && (
          <div className="mt-6 rounded-card border border-border bg-surface-card p-4">
            <p className="text-sm text-content-primary">
              Une erreur inattendue est survenue en essayant de rattacher cette adresse à un
              quartier.
            </p>
            <p className="mt-2 text-xs text-content-secondary">
              {selectedLabel}
            </p>
            <button
              onClick={() => setScreen(SCREENS.ADDRESS_FORM)}
              className="mt-3 text-sm font-medium text-corail"
            >
              Réessayer
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

MQEOF_SRC_APP_ONBOARDING_PAGE_JSX

echo "Onboarding simplifie avec succes."
echo "Prochaine etape : git add -A && git commit -m \"onboarding : parcours simplifie, plus decran attente\" && git push"
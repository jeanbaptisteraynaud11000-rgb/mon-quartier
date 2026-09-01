#!/usr/bin/env bash
set -e
echo "Onboarding : creation automatique de quartier..."

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
    const city = feature.properties.city || feature.properties.name;
    const postcode = feature.properties.postcode || null;

    setQuery(feature.properties.label);
    setSelectedLabel(feature.properties.label);
    setSelectedCoords({ lat, lng });
    setSuggestions([]);

    // On cherche d'abord un quartier existant à cette adresse ; s'il n'y
    // en a aucun, la fonction en crée un nouveau automatiquement (rayon
    // ~700m autour du point) — plus besoin qu'un quartier existe au
    // préalable pour qu'une inscription aboutisse.
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

  async function handleRequestMembership() {
    if (!detectedQuartier) return;
    setSubmitting(true);
    setError('');

    const { data: { user } } = await supabase.auth.getUser();

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
          Tu peux déjà découvrir Hoody en attendant. Certaines fonctionnalités
          (messagerie, recherche de voisins) seront disponibles après validation.
        </p>
        <button
          onClick={() => router.push('/')}
          className="mt-6 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover"
        >
          Découvrir Hoody
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

echo "Onboarding mis a jour avec succes."
echo "Prochaine etape : executer la migration 026, puis git add -A && git commit -m \"onboarding : creation automatique de quartier\" && git push"
'use client';

import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';
import { MapPin, Trash2 } from 'lucide-react';

export default function WatchedLocationsPage() {
  const [locations, setLocations] = useState([]);
  const [loading, setLoading] = useState(true);

  const [label, setLabel] = useState('');
  const [query, setQuery] = useState('');
  const [suggestions, setSuggestions] = useState([]);
  const [selectedCoords, setSelectedCoords] = useState(null);
  const [radius, setRadius] = useState(300);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const debounceRef = useRef(null);

  async function load() {
    const { data } = await supabase
      .from('watched_locations')
      .select('id, label, lat, lng, radius_m, created_at')
      .order('created_at', { ascending: false });
    setLocations(data || []);
    setLoading(false);
  }

  useEffect(() => {
    load();
  }, []);

  function handleAddressChange(value) {
    setQuery(value);
    setSelectedCoords(null);

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
    setQuery(feature.properties.label);
    setSelectedCoords({ lat, lng });
    setSuggestions([]);
  }

  async function handleAdd(e) {
    e.preventDefault();
    setError('');

    if (!label.trim()) {
      setError('Donne un nom à ce lieu (ex : École de mon fils).');
      return;
    }
    if (!selectedCoords) {
      setError('Choisis une adresse dans les suggestions.');
      return;
    }

    setSubmitting(true);
    const { data: { user } } = await supabase.auth.getUser();

    const { error: insertError } = await supabase.from('watched_locations').insert({
      user_id: user.id,
      label: label.trim(),
      lat: selectedCoords.lat,
      lng: selectedCoords.lng,
      radius_m: radius,
    });

    setSubmitting(false);

    if (insertError) {
      setError('Une erreur est survenue. Réessaie.');
      return;
    }

    setLabel('');
    setQuery('');
    setSelectedCoords(null);
    setRadius(300);
    load();
  }

  async function handleDelete(id) {
    await supabase.from('watched_locations').delete().eq('id', id);
    load();
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <div>
        <Link href="/settings" className="text-sm font-medium text-content-secondary">
          ← Paramètres
        </Link>
        <h1 className="mt-1 text-xl font-semibold text-content-primary">Lieux surveillés</h1>
        <p className="mt-1 text-sm text-content-secondary">
          Reçois une notification si une alerte quartier est publiée près d'un lieu qui te tient
          à cœur (école, résidence secondaire...).
        </p>
      </div>

      <form onSubmit={handleAdd} className="flex flex-col gap-3 rounded-card border border-border bg-surface-card p-4">
        <input
          type="text"
          maxLength={60}
          value={label}
          onChange={(e) => setLabel(e.target.value)}
          placeholder="Nom du lieu (ex : École de mon fils)"
          className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
        />

        <div className="relative">
          <input
            type="text"
            value={query}
            onChange={(e) => handleAddressChange(e.target.value)}
            placeholder="Adresse..."
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
          <label className="mb-1 block text-xs text-content-secondary">
            Rayon de surveillance : {radius} m
          </label>
          <input
            type="range"
            min={50}
            max={1000}
            step={50}
            value={radius}
            onChange={(e) => setRadius(Number(e.target.value))}
            className="w-full accent-corail"
          />
        </div>

        {error && <p className="text-sm text-corail">{error}</p>}

        <button
          type="submit"
          disabled={submitting}
          className="h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
        >
          {submitting ? 'Ajout...' : 'Ajouter ce lieu'}
        </button>
      </form>

      {!loading && locations.length === 0 && (
        <p className="text-center text-sm text-content-secondary">Aucun lieu surveillé pour l'instant.</p>
      )}

      <div className="flex flex-col gap-2">
        {locations.map((loc) => (
          <div
            key={loc.id}
            className="flex items-center gap-3 rounded-card border border-border bg-surface-card p-3"
          >
            <span className="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-pill bg-corail/10 text-corail">
              <MapPin size={16} />
            </span>
            <div className="min-w-0 flex-1">
              <p className="truncate font-medium text-content-primary">{loc.label}</p>
              <p className="text-xs text-content-secondary">Rayon : {loc.radius_m} m</p>
            </div>
            <button
              onClick={() => handleDelete(loc.id)}
              aria-label="Supprimer"
              className="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-pill text-content-secondary hover:bg-surface"
            >
              <Trash2 size={16} />
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}


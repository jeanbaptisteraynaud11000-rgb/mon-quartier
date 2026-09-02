'use client';

import { useRef, useState } from 'react';

// Composant contrôlé réutilisable : évite de dupliquer la logique de
// debounce + suggestions à chaque endroit du formulaire qui a besoin
// d'une adresse (zone, point de départ, point d'arrivée, lieu de retrait...).
export default function AddressAutocompleteField({
  id,
  label,
  optional = false,
  placeholder = '',
  value,
  onChange,
  onSelect,
  helperText,
}) {
  const [suggestions, setSuggestions] = useState([]);
  const debounceRef = useRef(null);

  function handleChange(newValue) {
    onChange(newValue);

    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (newValue.trim().length < 4) {
      setSuggestions([]);
      return;
    }

    const queryAtCallTime = newValue;

    debounceRef.current = setTimeout(async () => {
      try {
        const res = await fetch(
          `https://api-adresse.data.gouv.fr/search/?q=${encodeURIComponent(queryAtCallTime)}&limit=5`
        );
        const json = await res.json();
        // Garde-fou contre une réponse tardive qui ne correspond plus au
        // texte actuellement affiché.
        setSuggestions((current) => (queryAtCallTime === newValue ? json.features || [] : current));
      } catch {
        setSuggestions([]);
      }
    }, 300);
  }

  function handleSelectSuggestion(feature) {
    const [lng, lat] = feature.geometry.coordinates;
    onChange(feature.properties.label);
    onSelect({ lat, lng, label: feature.properties.label });
    setSuggestions([]);
  }

  return (
    <div className="relative">
      <label htmlFor={id} className="mb-1 block text-sm font-medium text-content-primary">
        {label} {optional && <span className="text-content-secondary">(optionnel)</span>}
      </label>
      <input
        id={id}
        type="text"
        maxLength={150}
        value={value}
        onChange={(e) => handleChange(e.target.value)}
        placeholder={placeholder}
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
      {helperText && <p className="mt-1 text-xs text-content-secondary">{helperText}</p>}
    </div>
  );
}


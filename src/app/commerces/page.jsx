'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';
import { PLACE_CATEGORIES, getPlaceCategoryInfo } from '@/lib/placeCategories';
import { sortByDistance, formatDistance } from '@/lib/distanceCalculator';
import { getPlaceholderImage } from '@/lib/placeholderImages';
import { Star, Tag } from 'lucide-react';

export default function CommercesPage() {
  const [places, setPlaces] = useState([]);
  const [offersByPlace, setOffersByPlace] = useState({});
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
        .select('id, category, name, description, address, lat, lng, photo_url, is_sponsored, sponsored_until')
        .eq('quartier_id', profile.quartier_id)
        .order('created_at', { ascending: false });

      const placeIds = (data || []).map((p) => p.id);

      // Offres actives et dans leur période — visibles par tout le monde
      // dans le quartier (RLS s'en charge déjà).
      const { data: offers } =
        placeIds.length > 0
          ? await supabase
              .from('place_offers')
              .select('id, place_id, title, ends_at')
              .in('place_id', placeIds)
              .eq('status', 'active')
          : { data: [] };

      const now = new Date();
      const offersMap = {};
      for (const o of offers || []) {
        if (new Date(o.ends_at) >= now) offersMap[o.place_id] = o;
      }
      setOffersByPlace(offersMap);

      setPlaces(data || []);
      setLoading(false);
    }
    load();

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
  const sortedByDistance = userPosition ? sortByDistance(filtered, userPosition.lat, userPosition.lng) : filtered;

  // Les fiches sponsorisées apparaissent en tête — toujours étiquetées
  // clairement "Sponsorisé", jamais confondues avec du contenu organique.
  const isCurrentlySponsored = (p) => p.is_sponsored && (!p.sponsored_until || new Date(p.sponsored_until) >= new Date());
  const sorted = [...sortedByDistance].sort((a, b) => (isCurrentlySponsored(b) ? 1 : 0) - (isCurrentlySponsored(a) ? 1 : 0));

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
          const distance = place._distance !== undefined ? formatDistance(place._distance) : null;
          const sponsored = isCurrentlySponsored(place);
          const offer = offersByPlace[place.id];

          return (
            <Link
              key={place.id}
              href={`/commerces/${place.id}`}
              className={`flex items-center gap-3 rounded-card border p-3 transition-fast hover:bg-border/20 ${
                sponsored ? 'border-amber-300 bg-amber-50/50' : 'border-border bg-surface-card'
              }`}
            >
              <div className="h-11 w-11 flex-shrink-0 overflow-hidden rounded-pill">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={place.photo_url || getPlaceholderImage(place.category)}
                  alt=""
                  className="h-full w-full object-cover"
                />
              </div>
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-1.5">
                  <p className="truncate font-medium text-content-primary">{place.name}</p>
                  {sponsored && (
                    <span className="flex flex-shrink-0 items-center gap-0.5 rounded-pill bg-amber-100 px-1.5 py-0.5 text-[10px] font-semibold text-amber-700">
                      <Star size={9} fill="currentColor" /> Sponsorisé
                    </span>
                  )}
                </div>
                <p className="truncate text-xs text-content-secondary">
                  {catInfo.label}{place.address ? ` · ${place.address}` : ''}
                </p>
                {offer && (
                  <p className="mt-0.5 flex items-center gap-1 truncate text-xs font-medium text-vert">
                    <Tag size={11} /> {offer.title}
                  </p>
                )}
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


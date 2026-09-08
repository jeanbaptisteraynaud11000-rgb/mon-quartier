#!/usr/bin/env bash
set -e
echo "Commerces sponsorises + offres ponctuelles..."

mkdir -p "src/app/commerces"
cat > "src/app/commerces/page.jsx" << 'MQEOF_SRC_APP_COMMERCES_PAGE_JSX'
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

MQEOF_SRC_APP_COMMERCES_PAGE_JSX

mkdir -p "src/app/commerces/[id]"
cat > "src/app/commerces/[id]/page.jsx" << 'MQEOF_SRC_APP_COMMERCES_ID_PAGE_JSX'
// Server Component : détail d'un commerce. RLS "places_select_own_quartier"
// garantit déjà l'isolation par quartier.

import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { getPlaceCategoryInfo } from '@/lib/placeCategories';
import { getPlaceholderImage } from '@/lib/placeholderImages';
import { Star, Tag } from 'lucide-react';
import OfferManager from './OfferManager';

export default async function PlaceDetailPage({ params }) {
  const { id } = await params;
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: place, error } = await supabase
    .from('places')
    .select('id, category, name, description, address, phone, website, added_by, photo_url, is_sponsored, sponsored_until')
    .eq('id', id)
    .single();

  if (error || !place) {
    notFound();
  }

  const isOwner = place.added_by === user.id;
  const isSponsored = place.is_sponsored && (!place.sponsored_until || new Date(place.sponsored_until) >= new Date());

  const { data: activeOffer } = await supabase
    .from('place_offers')
    .select('title, description, ends_at')
    .eq('place_id', place.id)
    .eq('status', 'active')
    .gte('ends_at', new Date().toISOString())
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  const catInfo = getPlaceCategoryInfo(place.category);
  const Icon = catInfo.icon;

  return (
    <div className="flex flex-col gap-5 p-4">
      <Link href="/commerces" className="text-sm font-medium text-content-secondary">
        ← Retour
      </Link>

      <div className="relative h-44 w-full overflow-hidden rounded-card bg-surface-card">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={place.photo_url || getPlaceholderImage(place.category)}
          alt=""
          className="h-full w-full object-cover"
        />
        {isSponsored && (
          <span className="absolute left-3 top-3 flex items-center gap-1 rounded-pill bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-700 shadow-soft">
            <Star size={12} fill="currentColor" /> Sponsorisé
          </span>
        )}
      </div>

      {activeOffer && (
        <div className="rounded-card bg-vert/10 p-4">
          <div className="flex items-center gap-2">
            <Tag size={16} className="text-vert" />
            <p className="font-semibold text-vert">{activeOffer.title}</p>
          </div>
          {activeOffer.description && (
            <p className="mt-1 text-sm text-content-primary">{activeOffer.description}</p>
          )}
          <p className="mt-1 text-xs text-content-secondary">
            Valable jusqu'au {new Date(activeOffer.ends_at).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long' })}
          </p>
        </div>
      )}

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

      {isOwner && <OfferManager placeId={place.id} />}

      <p className="text-center text-xs text-content-secondary">
        Ajouté par un habitant du quartier. Vérifie les informations avant de te déplacer.
      </p>
    </div>
  );
}

MQEOF_SRC_APP_COMMERCES_ID_PAGE_JSX

mkdir -p "src/app/commerces/[id]"
cat > "src/app/commerces/[id]/OfferManager.jsx" << 'MQEOF_SRC_APP_COMMERCES_ID_OFFERMANAGER_JSX'
'use client';

import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabaseClient';
import { Tag } from 'lucide-react';

const STATUS_LABELS = {
  pending: { label: 'En attente de validation', tint: 'bg-surface text-content-secondary' },
  active: { label: 'Active', tint: 'bg-vert/10 text-vert' },
  rejected: { label: 'Refusée', tint: 'bg-corail/10 text-corail' },
  expired: { label: 'Terminée', tint: 'bg-surface text-content-secondary' },
};

export default function OfferManager({ placeId }) {
  const [offers, setOffers] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [endsAt, setEndsAt] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  async function load() {
    const { data } = await supabase
      .from('place_offers')
      .select('id, title, description, ends_at, status')
      .eq('place_id', placeId)
      .order('created_at', { ascending: false });
    setOffers(data || []);
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [placeId]);

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');

    if (!title.trim() || !endsAt) {
      setError("Le titre de l'offre et la date de fin sont obligatoires.");
      return;
    }

    setSubmitting(true);
    const { error: insertError } = await supabase.from('place_offers').insert({
      place_id: placeId,
      title: title.trim(),
      description: description.trim() || null,
      ends_at: new Date(`${endsAt}T23:59:59`).toISOString(),
    });
    setSubmitting(false);

    if (insertError) {
      setError('Une erreur est survenue. Réessaie.');
      return;
    }

    setTitle('');
    setDescription('');
    setEndsAt('');
    setShowForm(false);
    setSuccess(true);
    load();
  }

  return (
    <div className="rounded-card border border-border bg-surface-card p-4">
      <div className="flex items-center justify-between">
        <h2 className="text-sm font-semibold text-content-primary">Mes offres</h2>
        <button
          onClick={() => setShowForm((v) => !v)}
          className="text-sm font-medium text-corail"
        >
          {showForm ? 'Annuler' : '+ Créer une offre'}
        </button>
      </div>

      <p className="mt-1 text-xs text-content-secondary">
        Une offre est visible par tout le quartier une fois validée. La validation se fait
        manuellement pour l'instant — contacte l'équipe Hoody pour organiser le paiement.
      </p>

      {success && (
        <p className="mt-2 text-xs text-vert">
          ✓ Demande envoyée, elle sera activée après validation.
        </p>
      )}

      {showForm && (
        <form onSubmit={handleSubmit} className="mt-3 flex flex-col gap-2 border-t border-border pt-3">
          <input
            type="text"
            maxLength={100}
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Ex : -20% ce week-end"
            className="w-full rounded-card border border-border bg-surface px-3 py-2 text-sm text-content-primary outline-none focus:border-corail"
          />
          <textarea
            rows={2}
            maxLength={300}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Détails (optionnel)"
            className="w-full resize-none rounded-card border border-border bg-surface px-3 py-2 text-sm text-content-primary outline-none focus:border-corail"
          />
          <div>
            <label className="mb-1 block text-xs text-content-secondary">Valable jusqu'au</label>
            <input
              type="date"
              value={endsAt}
              onChange={(e) => setEndsAt(e.target.value)}
              className="w-full rounded-card border border-border bg-surface px-3 py-2 text-sm text-content-primary outline-none focus:border-corail"
            />
          </div>
          {error && <p className="text-xs text-corail">{error}</p>}
          <button
            type="submit"
            disabled={submitting}
            className="h-tap rounded-pill bg-corail text-sm font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
          >
            {submitting ? 'Envoi...' : 'Envoyer la demande'}
          </button>
        </form>
      )}

      {offers.length > 0 && (
        <div className="mt-3 flex flex-col gap-2 border-t border-border pt-3">
          {offers.map((o) => (
            <div key={o.id} className="flex items-center gap-2 rounded-card bg-surface p-2">
              <Tag size={14} className="flex-shrink-0 text-content-secondary" />
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm text-content-primary">{o.title}</p>
              </div>
              <span className={`flex-shrink-0 rounded-pill px-2 py-0.5 text-[10px] font-medium ${STATUS_LABELS[o.status].tint}`}>
                {STATUS_LABELS[o.status].label}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

MQEOF_SRC_APP_COMMERCES_ID_OFFERMANAGER_JSX

mkdir -p "src/app/admin/commerces"
cat > "src/app/admin/commerces/page.jsx" << 'MQEOF_SRC_APP_ADMIN_COMMERCES_PAGE_JSX'
// Server Component protégé — voir requireAdmin().

import { requireAdmin } from '@/lib/requireAdmin';
import { getPlaceCategoryInfo } from '@/lib/placeCategories';
import SponsorToggle from './SponsorToggle';
import OfferModeration from './OfferModeration';

export default async function AdminCommercesPage() {
  const { supabase } = await requireAdmin();

  const { data: places } = await supabase
    .from('places')
    .select('id, name, category, is_sponsored, sponsored_until, quartiers(name, city)')
    .order('name', { ascending: true });

  const { data: pendingOffers } = await supabase
    .from('place_offers')
    .select('id, title, description, ends_at, places(name)')
    .eq('status', 'pending')
    .order('created_at', { ascending: true });

  return (
    <div className="flex flex-col gap-6 p-4">
      <h1 className="text-xl font-semibold text-content-primary">
        Commerces — sponsoring & offres
      </h1>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-content-secondary">
          Offres en attente de validation ({pendingOffers?.length || 0})
        </h2>
        {(!pendingOffers || pendingOffers.length === 0) && (
          <p className="text-sm text-content-secondary">Aucune offre en attente.</p>
        )}
        <div className="flex flex-col gap-2">
          {pendingOffers?.map((offer) => (
            <OfferModeration key={offer.id} offer={offer} />
          ))}
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-content-secondary">
          Fiches ({places?.length || 0})
        </h2>
        <div className="flex flex-col gap-2">
          {places?.map((place) => {
            const catInfo = getPlaceCategoryInfo(place.category);
            return (
              <div
                key={place.id}
                className="flex items-center justify-between gap-3 rounded-card border border-border bg-surface-card p-3"
              >
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium text-content-primary">{place.name}</p>
                  <p className="truncate text-xs text-content-secondary">
                    {catInfo.label} · {place.quartiers?.name} — {place.quartiers?.city}
                  </p>
                </div>
                <SponsorToggle placeId={place.id} isSponsored={place.is_sponsored} sponsoredUntil={place.sponsored_until} />
              </div>
            );
          })}
        </div>
      </section>
    </div>
  );
}

MQEOF_SRC_APP_ADMIN_COMMERCES_PAGE_JSX

mkdir -p "src/app/admin/commerces"
cat > "src/app/admin/commerces/SponsorToggle.jsx" << 'MQEOF_SRC_APP_ADMIN_COMMERCES_SPONSORTOGGLE_JSX'
'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { Star } from 'lucide-react';

export default function SponsorToggle({ placeId, isSponsored, sponsoredUntil }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [days, setDays] = useState(30);

  const currentlyActive = isSponsored && (!sponsoredUntil || new Date(sponsoredUntil) >= new Date());

  async function handleActivate() {
    setBusy(true);
    const until = new Date();
    until.setDate(until.getDate() + Number(days));

    await supabase
      .from('places')
      .update({ is_sponsored: true, sponsored_until: until.toISOString() })
      .eq('id', placeId);

    setBusy(false);
    router.refresh();
  }

  async function handleDeactivate() {
    setBusy(true);
    await supabase.from('places').update({ is_sponsored: false }).eq('id', placeId);
    setBusy(false);
    router.refresh();
  }

  if (currentlyActive) {
    return (
      <div className="flex flex-shrink-0 items-center gap-2">
        <span className="flex items-center gap-1 rounded-pill bg-amber-100 px-2 py-1 text-xs font-medium text-amber-700">
          <Star size={11} fill="currentColor" />
          Jusqu'au {new Date(sponsoredUntil).toLocaleDateString('fr-FR')}
        </span>
        <button
          onClick={handleDeactivate}
          disabled={busy}
          className="rounded-pill border border-border px-2 py-1 text-xs text-content-secondary hover:bg-surface"
        >
          Retirer
        </button>
      </div>
    );
  }

  return (
    <div className="flex flex-shrink-0 items-center gap-1.5">
      <select
        value={days}
        onChange={(e) => setDays(e.target.value)}
        className="rounded-card border border-border bg-surface px-2 py-1 text-xs text-content-primary"
      >
        <option value={7}>7 jours</option>
        <option value={30}>30 jours</option>
        <option value={90}>90 jours</option>
      </select>
      <button
        onClick={handleActivate}
        disabled={busy}
        className="rounded-pill bg-amber-500 px-3 py-1 text-xs font-medium text-white hover:bg-amber-600 disabled:opacity-60"
      >
        Sponsoriser
      </button>
    </div>
  );
}

MQEOF_SRC_APP_ADMIN_COMMERCES_SPONSORTOGGLE_JSX

mkdir -p "src/app/admin/commerces"
cat > "src/app/admin/commerces/OfferModeration.jsx" << 'MQEOF_SRC_APP_ADMIN_COMMERCES_OFFERMODERATION_JSX'
'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';

export default function OfferModeration({ offer }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  async function handleDecision(status) {
    setBusy(true);
    await supabase.from('place_offers').update({ status }).eq('id', offer.id);
    setBusy(false);
    router.refresh();
  }

  return (
    <div className="rounded-card border border-border bg-surface-card p-3">
      <p className="text-sm font-medium text-content-primary">{offer.title}</p>
      <p className="text-xs text-content-secondary">
        {offer.places?.name} · jusqu'au {new Date(offer.ends_at).toLocaleDateString('fr-FR')}
      </p>
      {offer.description && (
        <p className="mt-1 text-sm text-content-secondary">{offer.description}</p>
      )}
      <div className="mt-2 flex gap-2">
        <button
          onClick={() => handleDecision('active')}
          disabled={busy}
          className="rounded-pill bg-vert px-3 py-1.5 text-xs font-medium text-white hover:opacity-90 disabled:opacity-60"
        >
          Activer
        </button>
        <button
          onClick={() => handleDecision('rejected')}
          disabled={busy}
          className="rounded-pill border border-border px-3 py-1.5 text-xs text-content-secondary hover:bg-surface"
        >
          Refuser
        </button>
      </div>
    </div>
  );
}

MQEOF_SRC_APP_ADMIN_COMMERCES_OFFERMODERATION_JSX

mkdir -p "src/app/admin"
cat > "src/app/admin/page.jsx" << 'MQEOF_SRC_APP_ADMIN_PAGE_JSX'
import Link from 'next/link';
import { requireAdmin } from '@/lib/requireAdmin';

export default async function AdminDashboard() {
  const { supabase, role, quartierId } = await requireAdmin();

  // super_admin sans quartier propre = vue globale ; sinon toujours scopé
  // au quartier de l'admin (un quartier_admin ne voit jamais au-delà du sien).
  const isGlobalView = role === 'super_admin' && !quartierId;

  async function countFor(table, filters = (q) => q) {
    let query = supabase.from(table).select('*', { count: 'exact', head: true });
    if (!isGlobalView) query = query.eq('quartier_id', quartierId);
    query = filters(query);
    const { count } = await query;
    return count ?? 0;
  }

  const [membersCount, activePostsCount, openReportsCount, suspendedCount, quartiersCount] =
    await Promise.all([
      isGlobalView
        ? supabase.from('profiles').select('*', { count: 'exact', head: true }).then((r) => r.count ?? 0)
        : supabase
            .from('profiles')
            .select('*', { count: 'exact', head: true })
            .eq('quartier_id', quartierId)
            .then((r) => r.count ?? 0),
      countFor('posts', (q) => q.eq('status', 'active')),
      countFor('reports', (q) => q.eq('status', 'open')),
      countFor('neighborhood_memberships', (q) => q.eq('status', 'suspended')),
      isGlobalView
        ? supabase.from('quartiers').select('*', { count: 'exact', head: true }).then((r) => r.count ?? 0)
        : Promise.resolve(null),
    ]);

  return (
    <div className="flex flex-col gap-4 p-4">
      <h1 className="text-xl font-semibold text-content-primary">
        Administration {isGlobalView ? '— vue globale' : ''}
      </h1>

      <div className="grid grid-cols-2 gap-3">
        {isGlobalView && <StatCard label="Quartiers" value={quartiersCount} />}
        <StatCard label="Membres" value={membersCount} />
        <StatCard label="Annonces actives" value={activePostsCount} />
        <StatCard
          label="Signalements ouverts"
          value={openReportsCount}
          href="/admin/reports"
          highlight={openReportsCount > 0}
        />
        <StatCard label="Membres suspendus" value={suspendedCount} href="/admin/members" />
      </div>

      <div className="flex flex-col gap-2">
        <Link
          href="/admin/reports"
          className="rounded-card border border-border bg-surface-card p-4 font-medium text-content-primary transition-fast hover:bg-border/30"
        >
          Signalements →
        </Link>
        <Link
          href="/admin/posts"
          className="rounded-card border border-border bg-surface-card p-4 font-medium text-content-primary transition-fast hover:bg-border/30"
        >
          Annonces →
        </Link>
        <Link
          href="/admin/members"
          className="rounded-card border border-border bg-surface-card p-4 font-medium text-content-primary transition-fast hover:bg-border/30"
        >
          Membres →
        </Link>
        <Link
          href="/admin/commerces"
          className="rounded-card border border-border bg-surface-card p-4 font-medium text-content-primary transition-fast hover:bg-border/30"
        >
          Commerces — sponsoring & offres →
        </Link>
      </div>
    </div>
  );
}

function StatCard({ label, value, href, highlight }) {
  const content = (
    <div
      className={`rounded-card border p-4 ${
        highlight ? 'border-corail bg-corail/5' : 'border-border bg-surface-card'
      }`}
    >
      <p className={`text-2xl font-semibold ${highlight ? 'text-corail' : 'text-content-primary'}`}>
        {value}
      </p>
      <p className="text-sm text-content-secondary">{label}</p>
    </div>
  );

  if (href) {
    return (
      <Link href={href} className="transition-fast hover:opacity-80">
        {content}
      </Link>
    );
  }
  return content;
}

MQEOF_SRC_APP_ADMIN_PAGE_JSX

echo "Commerces sponsorises ajoutes avec succes."
echo "Prochaine etape : executer la migration 040, puis git add -A && git commit -m \"commerces sponsorises + offres ponctuelles\" && git push"
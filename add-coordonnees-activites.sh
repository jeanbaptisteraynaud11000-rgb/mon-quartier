#!/usr/bin/env bash
set -e
echo "Coordonnees + distance sur les activites..."

mkdir -p "src/app/activites/new"
cat > "src/app/activites/new/page.jsx" << 'MQEOF_SRC_APP_ACTIVITES_NEW_PAGE_JSX'
'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { EVENT_CATEGORIES } from '@/lib/eventCategories';
import { compressImage } from '@/lib/compressImage';
import { ImagePlus, Pencil, List, MapPin, Calendar, Clock, Minus, Plus, Send } from 'lucide-react';

const MAX_PHOTO_SIZE = 10 * 1024 * 1024;

export default function NewActivityPage() {
  const router = useRouter();

  const [quartierId, setQuartierId] = useState(null);
  const [loadingProfile, setLoadingProfile] = useState(true);

  const [category, setCategory] = useState('sortie');
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [location, setLocation] = useState('');
  const [locationCoords, setLocationCoords] = useState(null); // { lat, lng }
  const [locationSuggestions, setLocationSuggestions] = useState([]);
  const locationDebounceRef = useRef(null);
  const [date, setDate] = useState('');
  const [time, setTime] = useState('');
  const [maxAttendees, setMaxAttendees] = useState(10);

  const [photoFile, setPhotoFile] = useState(null);
  const [photoPreview, setPhotoPreview] = useState(null);
  const [photoError, setPhotoError] = useState('');

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

  async function handlePhotoSelect(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setPhotoError('');

    const accepted = ['image/jpeg', 'image/png', 'image/webp'];
    if (!accepted.includes(file.type)) {
      setPhotoError('Format accepté : JPEG, PNG ou WebP.');
      return;
    }
    if (file.size > MAX_PHOTO_SIZE) {
      setPhotoError('La photo doit faire moins de 10 Mo.');
      return;
    }

    try {
      const compressed = await compressImage(file, { maxWidth: 1600, maxHeight: 900 });
      setPhotoFile(compressed);
      setPhotoPreview(URL.createObjectURL(compressed));
    } catch {
      setPhotoFile(file);
      setPhotoPreview(URL.createObjectURL(file));
    }
  }

  function handleLocationChange(value) {
    setLocation(value);
    setLocationCoords(null);

    if (locationDebounceRef.current) clearTimeout(locationDebounceRef.current);
    if (value.trim().length < 4) {
      setLocationSuggestions([]);
      return;
    }

    locationDebounceRef.current = setTimeout(async () => {
      try {
        const res = await fetch(
          `https://api-adresse.data.gouv.fr/search/?q=${encodeURIComponent(value)}&limit=5`
        );
        const json = await res.json();
        setLocationSuggestions(json.features || []);
      } catch {
        setLocationSuggestions([]);
      }
    }, 300);
  }

  function handleSelectLocation(feature) {
    const [lng, lat] = feature.geometry.coordinates;
    setLocation(feature.properties.label);
    setLocationCoords({ lat, lng });
    setLocationSuggestions([]);
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');

    if (hasSubmittedRef.current) return;

    if (!title.trim()) {
      setError('Le titre est obligatoire.');
      return;
    }
    if (!date || !time) {
      setError('La date et l\'heure sont obligatoires.');
      return;
    }

    const isoDate = new Date(`${date}T${time}`).toISOString();
    if (new Date(isoDate) <= new Date()) {
      setError('La date doit être dans le futur.');
      return;
    }

    hasSubmittedRef.current = true;
    setSubmitting(true);

    const { data: { user } } = await supabase.auth.getUser();

    const { data: newEvent, error: insertError } = await supabase
      .from('events')
      .insert({
        user_id: user.id,
        quartier_id: quartierId,
        category,
        title: title.trim(),
        description: description.trim() || null,
        location: location.trim() || null,
        lat: locationCoords?.lat || null,
        lng: locationCoords?.lng || null,
        event_date: isoDate,
        max_attendees: maxAttendees,
        status: 'active',
      })
      .select('id')
      .single();

    if (insertError || !newEvent) {
      setSubmitting(false);
      hasSubmittedRef.current = false;
      setError('Une erreur est survenue lors de la création. Réessaie.');
      return;
    }

    if (photoFile) {
      const ext = photoFile.name.split('.').pop();
      const path = `${newEvent.id}/${crypto.randomUUID()}.${ext}`;
      const { error: uploadError } = await supabase.storage.from('events').upload(path, photoFile);
      if (!uploadError) {
        const publicUrl = supabase.storage.from('events').getPublicUrl(path).data.publicUrl;
        await supabase.from('events').update({ photo_url: publicUrl }).eq('id', newEvent.id);
      }
    }

    setSubmitting(false);
    router.push(`/activites/${newEvent.id}`);
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
      <h1 className="text-xl font-semibold text-content-primary">Organiser une activité</h1>
      <p className="mt-1 text-sm text-content-secondary">Propose un moment convivial à tes voisins.</p>

      <form onSubmit={handleSubmit} className="mt-6 flex flex-col gap-5">
        {/* Photo de couverture */}
        <div>
          <label className="mb-1 block text-sm font-medium text-content-primary">Photo de couverture</label>
          {photoPreview ? (
            <div className="relative h-40 w-full overflow-hidden rounded-card">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={photoPreview} alt="" className="h-full w-full object-cover" />
            </div>
          ) : (
            <label className="flex h-40 w-full cursor-pointer flex-col items-center justify-center gap-2 rounded-card border border-dashed border-corail/40 bg-corail/5 text-center transition-fast hover:bg-corail/10">
              <span className="flex h-11 w-11 items-center justify-center rounded-pill bg-corail/10 text-corail">
                <ImagePlus size={20} />
              </span>
              <span className="text-sm font-medium text-corail">Ajouter une photo</span>
              <span className="text-xs text-content-secondary">Format conseillé : 16:9, max 10 Mo</span>
              <input
                type="file"
                accept="image/jpeg,image/png,image/webp"
                onChange={handlePhotoSelect}
                className="hidden"
              />
            </label>
          )}
          {photoError && <p className="mt-1 text-xs text-corail">{photoError}</p>}
        </div>

        {/* Catégorie */}
        <div>
          <label className="mb-1 block text-sm font-medium text-content-primary">Catégorie</label>
          <div className="grid grid-cols-2 gap-2">
            {EVENT_CATEGORIES.map((cat) => {
              const Icon = cat.icon;
              const active = category === cat.category;
              return (
                <button
                  key={cat.category}
                  type="button"
                  onClick={() => setCategory(cat.category)}
                  className={`flex items-center gap-2 rounded-card border px-3 py-3 text-sm font-medium transition-fast ${
                    active
                      ? 'border-corail bg-corail/5 text-corail'
                      : 'border-border bg-surface text-content-primary hover:bg-surface-card'
                  }`}
                >
                  <span
                    className={`flex h-7 w-7 flex-shrink-0 items-center justify-center rounded-pill ${
                      active ? 'bg-corail/15 text-corail' : 'bg-vert/10 text-vert'
                    }`}
                  >
                    <Icon size={15} />
                  </span>
                  {cat.label}
                </button>
              );
            })}
          </div>
        </div>

        {/* Titre */}
        <div>
          <label htmlFor="title" className="mb-1 block text-sm font-medium text-content-primary">
            Titre
          </label>
          <div className="relative">
            <span className="absolute left-1.5 top-1.5 flex h-8 w-8 items-center justify-center rounded-pill bg-corail/10 text-corail">
              <Pencil size={14} />
            </span>
            <input
              id="title"
              type="text"
              required
              maxLength={100}
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Ex : Partie de belote entre voisins"
              className="w-full rounded-card border border-border bg-surface py-3 pl-12 pr-4 text-content-primary outline-none transition-fast focus:border-corail"
            />
          </div>
        </div>

        {/* Description */}
        <div>
          <label htmlFor="description" className="mb-1 block text-sm font-medium text-content-primary">
            Description <span className="text-content-secondary">(optionnel)</span>
          </label>
          <div className="relative">
            <span className="absolute left-1.5 top-1.5 flex h-8 w-8 items-center justify-center rounded-pill bg-vert/10 text-vert">
              <List size={14} />
            </span>
            <textarea
              id="description"
              rows={3}
              maxLength={200}
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Décris ton activité en quelques mots..."
              className="w-full resize-none rounded-card border border-border bg-surface py-3 pl-12 pr-4 text-content-primary outline-none transition-fast focus:border-corail"
            />
          </div>
          <p className="mt-1 text-right text-xs text-content-secondary">{description.length}/200</p>
        </div>

        {/* Lieu */}
        <div>
          <label htmlFor="location" className="mb-1 block text-sm font-medium text-content-primary">
            Lieu <span className="text-content-secondary">(optionnel)</span>
          </label>
          <div className="relative">
            <span className="absolute left-1.5 top-1.5 flex h-8 w-8 items-center justify-center rounded-pill bg-vert/10 text-vert">
              <MapPin size={14} />
            </span>
            <input
              id="location"
              type="text"
              maxLength={150}
              value={location}
              onChange={(e) => handleLocationChange(e.target.value)}
              placeholder="Ex : Parc Olbius Riquier, devant l'entrée"
              className="w-full rounded-card border border-border bg-surface py-3 pl-12 pr-4 text-content-primary outline-none transition-fast focus:border-corail"
            />
            {locationSuggestions.length > 0 && (
              <ul className="absolute z-10 mt-1 w-full overflow-hidden rounded-card border border-border bg-surface shadow-soft">
                {locationSuggestions.map((feature) => (
                  <li key={feature.properties.id}>
                    <button
                      type="button"
                      onClick={() => handleSelectLocation(feature)}
                      className="w-full px-4 py-3 text-left text-sm text-content-primary hover:bg-surface-card"
                    >
                      {feature.properties.label}
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>

        {/* Date et heure séparées */}
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label htmlFor="date" className="mb-1 block text-sm font-medium text-content-primary">
              Date
            </label>
            <div className="relative">
              <span className="absolute left-1.5 top-1.5 flex h-8 w-8 items-center justify-center rounded-pill bg-corail/10 text-corail">
                <Calendar size={14} />
              </span>
              <input
                id="date"
                type="date"
                required
                value={date}
                onChange={(e) => setDate(e.target.value)}
                className="w-full rounded-card border border-border bg-surface py-3 pl-12 pr-2 text-content-primary outline-none transition-fast focus:border-corail"
              />
            </div>
          </div>
          <div>
            <label htmlFor="time" className="mb-1 block text-sm font-medium text-content-primary">
              Heure
            </label>
            <div className="relative">
              <span className="absolute left-1.5 top-1.5 flex h-8 w-8 items-center justify-center rounded-pill bg-vert/10 text-vert">
                <Clock size={14} />
              </span>
              <input
                id="time"
                type="time"
                required
                value={time}
                onChange={(e) => setTime(e.target.value)}
                className="w-full rounded-card border border-border bg-surface py-3 pl-12 pr-2 text-content-primary outline-none transition-fast focus:border-corail"
              />
            </div>
          </div>
        </div>

        {/* Nombre de places — stepper */}
        <div>
          <label className="mb-1 block text-sm font-medium text-content-primary">Nombre de places</label>
          <div className="flex items-center justify-between rounded-card border border-border bg-surface p-3">
            <button
              type="button"
              onClick={() => setMaxAttendees((n) => Math.max(1, n - 1))}
              className="flex h-9 w-9 items-center justify-center rounded-pill bg-surface-card text-content-primary hover:bg-border/50"
            >
              <Minus size={16} />
            </button>
            <div className="text-center">
              <p className="text-lg font-semibold text-content-primary">{maxAttendees}</p>
              <p className="text-xs text-content-secondary">places disponibles</p>
            </div>
            <button
              type="button"
              onClick={() => setMaxAttendees((n) => Math.min(500, n + 1))}
              className="flex h-9 w-9 items-center justify-center rounded-pill bg-surface-card text-content-primary hover:bg-border/50"
            >
              <Plus size={16} />
            </button>
          </div>
        </div>

        {error && <p className="text-sm text-corail">{error}</p>}

        <button
          type="submit"
          disabled={submitting}
          className="flex h-tap w-full items-center justify-center gap-2 rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
        >
          <Send size={16} />
          {submitting ? 'Publication...' : "Publier l'activité"}
        </button>
      </form>
    </div>
  );
}

MQEOF_SRC_APP_ACTIVITES_NEW_PAGE_JSX

mkdir -p "src/app/activites"
cat > "src/app/activites/page.jsx" << 'MQEOF_SRC_APP_ACTIVITES_PAGE_JSX'
// Server Component : activités à venir du quartier, triées par date,
// filtrable par catégorie via ?category=sortie|musee|sport|jeux_de_societe|autre.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { EVENT_CATEGORIES, getEventCategoryInfo, formatEventDate } from '@/lib/eventCategories';
import { getPlaceholderImage } from '@/lib/placeholderImages';
import PostDistanceBadge from '@/components/PostDistanceBadge';
import EventCardMenu from './EventCardMenu';

export default async function ActivitesPage({ searchParams }) {
  const params = await searchParams;
  const activeCategory = params?.category;

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: profile } = await supabase
    .from('profiles')
    .select('quartier_id')
    .eq('user_id', user.id)
    .single();

  if (!profile?.quartier_id) {
    return (
      <div className="p-4">
        <div className="rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">
            Termine d'abord ton inscription pour voir les activités de ton quartier.
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

  let query = supabase
    .from('events')
    .select('id, category, title, location, event_date, max_attendees, user_id, photo_url, lat, lng')
    .eq('quartier_id', profile.quartier_id)
    .eq('status', 'active')
    .gte('event_date', new Date().toISOString())
    .order('event_date', { ascending: true })
    .limit(30);

  if (activeCategory) {
    query = query.eq('category', activeCategory);
  }

  const { data: events, error } = await query;

  let attendeeCounts = {};
  let organizerInfo = {};
  if (events?.length > 0) {
    const [{ data: attendees }, { data: organizers }] = await Promise.all([
      supabase.from('event_attendees').select('event_id').in('event_id', events.map((e) => e.id)),
      supabase
        .from('profiles')
        .select('user_id, display_name, photo_url, photo_visible')
        .in('user_id', [...new Set(events.map((e) => e.user_id))]),
    ]);
    for (const a of attendees || []) {
      attendeeCounts[a.event_id] = (attendeeCounts[a.event_id] || 0) + 1;
    }
    organizerInfo = Object.fromEntries((organizers || []).map((o) => [o.user_id, o]));
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-content-primary">Activités</h1>
        <Link
          href="/activites/new"
          className="rounded-pill bg-corail px-4 py-2 text-sm font-medium text-white transition-fast hover:bg-corail-hover"
        >
          Organiser
        </Link>
      </div>

      {/* Filtres de catégorie — même traitement que /annonces */}
      <div className="grid grid-cols-3 gap-2">
        <FilterTile href="/activites" label="Toutes" active={!activeCategory} />
        {EVENT_CATEGORIES.map((cat) => (
          <FilterTile
            key={cat.category}
            href={`/activites?category=${cat.category}`}
            image={getPlaceholderImage(cat.category)}
            label={cat.label}
            active={activeCategory === cat.category}
          />
        ))}
      </div>

      {error && (
        <p className="text-sm text-corail">Impossible de charger les activités pour le moment.</p>
      )}

      {!error && events?.length === 0 && (
        <div className="rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">Aucune activité prévue pour l'instant.</p>
          <p className="mt-1 text-sm text-content-secondary">
            Sortie, sport, jeux de société... lance la première !
          </p>
          <Link
            href="/activites/new"
            className="mt-4 inline-block h-tap rounded-pill bg-corail px-6 py-3 font-medium text-white transition-fast hover:bg-corail-hover"
          >
            Organiser une activité
          </Link>
        </div>
      )}

      <div className="flex flex-col gap-3">
        {events?.map((event) => {
          const catInfo = getEventCategoryInfo(event.category);
          const count = attendeeCounts[event.id] || 0;
          const isFull = count >= event.max_attendees;
          const organizer = organizerInfo[event.user_id];
          const isOrganizer = event.user_id === user.id;

          return (
            <div key={event.id} className="rounded-card border border-border bg-surface-card p-3 shadow-soft">
              <div className="flex gap-3">
                <Link href={`/activites/${event.id}`} className="relative h-20 w-20 flex-shrink-0 overflow-hidden rounded-card">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={event.photo_url || getPlaceholderImage(event.category)}
                    alt=""
                    className="h-full w-full object-cover"
                  />
                  <PostDistanceBadge lat={event.lat} lng={event.lng} />
                </Link>

                <div className="min-w-0 flex-1">
                  <div className="flex items-center justify-between gap-2">
                    <Link href={`/activites/${event.id}`} className="flex min-w-0 items-center gap-1.5">
                      <div className="flex h-5 w-5 flex-shrink-0 items-center justify-center overflow-hidden rounded-pill bg-vert/10 text-[9px] font-semibold text-vert">
                        {organizer?.photo_visible && organizer?.photo_url ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img src={organizer.photo_url} alt="" className="h-full w-full object-cover" />
                        ) : (
                          (organizer?.display_name || '?').charAt(0).toUpperCase()
                        )}
                      </div>
                      <span className="truncate text-xs font-medium text-content-secondary">
                        {organizer?.display_name || 'Voisin'} · {formatEventDate(event.event_date)}
                      </span>
                    </Link>
                    <EventCardMenu eventId={event.id} isOrganizer={isOrganizer} />
                  </div>

                  <Link href={`/activites/${event.id}`}>
                    <p className="mt-1 font-semibold text-content-primary">{event.title}</p>
                    {event.location && (
                      <p className="mt-0.5 truncate text-sm text-content-secondary">{event.location}</p>
                    )}
                  </Link>

                  <div className="mt-2 flex items-center gap-1.5">
                    <span className="rounded-pill bg-surface px-2 py-0.5 text-[11px] font-medium text-content-secondary">
                      {catInfo.label}
                    </span>
                    <span className={`text-[11px] font-medium ${isFull ? 'text-corail' : 'text-content-secondary'}`}>
                      {isFull ? 'Complet' : `${count} / ${event.max_attendees} places`}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function FilterTile({ href, label, image, active }) {
  return (
    <Link
      href={href}
      className={`relative overflow-hidden rounded-card transition-fast ${
        active ? 'ring-2 ring-corail ring-offset-2 ring-offset-surface' : ''
      }`}
    >
      {image ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={image} alt={label} className="aspect-square w-full object-cover" />
      ) : (
        <div
          className={`flex aspect-square w-full items-center justify-center text-sm font-semibold ${
            active ? 'bg-corail text-white' : 'bg-surface-card text-content-primary'
          }`}
        >
          Toutes
        </div>
      )}
    </Link>
  );
}

MQEOF_SRC_APP_ACTIVITES_PAGE_JSX

echo "Coordonnees activites ajoutees avec succes."
echo "Prochaine etape : executer la migration 030, puis git add -A && git commit -m \"activites : coordonnees + distance\" && git push"
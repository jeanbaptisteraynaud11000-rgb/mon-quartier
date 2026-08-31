#!/usr/bin/env bash
set -e
echo "Formulaire activite redessine + photo de couverture..."

mkdir -p "src/app/activites/new"
cat > "src/app/activites/new/page.jsx" << 'MQEOF_SRC_APP_ACTIVITES_NEW_PAGE_JSX'
'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { EVENT_CATEGORIES } from '@/lib/eventCategories';
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

  function handlePhotoSelect(e) {
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

    setPhotoFile(file);
    setPhotoPreview(URL.createObjectURL(file));
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
              onChange={(e) => setLocation(e.target.value)}
              placeholder="Ex : Parc Olbius Riquier, devant l'entrée"
              className="w-full rounded-card border border-border bg-surface py-3 pl-12 pr-4 text-content-primary outline-none transition-fast focus:border-corail"
            />
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

mkdir -p "src/app/activites/[id]"
cat > "src/app/activites/[id]/page.jsx" << 'MQEOF_SRC_APP_ACTIVITES_ID_PAGE_JSX'
'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';
import { getEventCategoryInfo, formatEventDate } from '@/lib/eventCategories';
import { getPlaceholderImage } from '@/lib/placeholderImages';

const JOIN_ERROR_MESSAGES = {
  invalid: "Cette activité n'existe plus.",
  past: 'Cette activité est déjà passée.',
  wrong_quartier: "Tu dois faire partie de ce quartier pour t'inscrire.",
  already_joined: 'Tu es déjà inscrit(e).',
  full: "C'est complet.",
};

export default function ActivityDetailPage() {
  const { id } = useParams();
  const router = useRouter();

  const [currentUserId, setCurrentUserId] = useState(null);
  const [event, setEvent] = useState(null);
  const [organizerName, setOrganizerName] = useState('Voisin');
  const [attendees, setAttendees] = useState([]);
  const [loading, setLoading] = useState(true);
  const [notFoundState, setNotFoundState] = useState(false);
  const [actionError, setActionError] = useState('');
  const [busy, setBusy] = useState(false);

  async function load() {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      router.push('/login');
      return;
    }
    setCurrentUserId(user.id);

    const { data: ev, error } = await supabase
      .from('events')
      .select('id, category, title, description, location, event_date, max_attendees, status, user_id, photo_url')
      .eq('id', id)
      .single();

    if (error || !ev) {
      setNotFoundState(true);
      setLoading(false);
      return;
    }
    setEvent(ev);

    const { data: organizerProfile } = await supabase
      .from('profiles')
      .select('display_name')
      .eq('user_id', ev.user_id)
      .single();
    setOrganizerName(organizerProfile?.display_name || 'Voisin');

    const { data: attendeeRows } = await supabase
      .from('event_attendees')
      .select('user_id, joined_at')
      .eq('event_id', id)
      .order('joined_at', { ascending: true });

    const userIds = (attendeeRows || []).map((a) => a.user_id);
    const { data: attendeeProfiles } = await supabase
      .from('profiles')
      .select('user_id, display_name')
      .in('user_id', userIds.length > 0 ? userIds : ['00000000-0000-0000-0000-000000000000']);

    const nameByUserId = Object.fromEntries((attendeeProfiles || []).map((p) => [p.user_id, p.display_name]));
    setAttendees((attendeeRows || []).map((a) => ({ ...a, name: nameByUserId[a.user_id] || 'Voisin' })));

    setLoading(false);
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  async function handleJoin() {
    setBusy(true);
    setActionError('');
    const { data, error } = await supabase.rpc('join_event', { p_event_id: id });
    setBusy(false);

    const result = data?.[0];
    if (error || !result?.success) {
      setActionError(JOIN_ERROR_MESSAGES[result?.reason] || 'Impossible de rejoindre pour le moment.');
      return;
    }
    load();
  }

  async function handleLeave() {
    setBusy(true);
    await supabase.from('event_attendees').delete().eq('event_id', id).eq('user_id', currentUserId);
    setBusy(false);
    load();
  }

  async function handleCancel() {
    if (!confirm('Annuler cette activité ? Les inscrits seront informés que ça n\'a plus lieu.')) return;
    setBusy(true);
    await supabase.rpc('cancel_event', { p_event_id: id });
    setBusy(false);
    load();
  }

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="skeleton h-4 w-40" />
      </div>
    );
  }

  if (notFoundState) {
    return (
      <div className="p-6 text-center text-content-secondary">
        Cette activité n'existe pas.
      </div>
    );
  }

  const catInfo = getEventCategoryInfo(event.category);
  const Icon = catInfo.icon;
  const isOrganizer = event.user_id === currentUserId;
  const alreadyJoined = attendees.some((a) => a.user_id === currentUserId);
  const isFull = attendees.length >= event.max_attendees;
  const isCancelled = event.status === 'cancelled';

  return (
    <div className="flex flex-col gap-5 p-4">
      <Link href="/activites" className="text-sm font-medium text-content-secondary">
        ← Retour aux activités
      </Link>

      <div className="relative h-40 w-full overflow-hidden rounded-card bg-surface-card">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={event.photo_url || getPlaceholderImage(event.category)}
          alt=""
          className="h-full w-full object-cover"
        />
      </div>

      <div className="rounded-card border border-border bg-surface-card p-5">
        {isCancelled && (
          <div className="mb-3 rounded-card bg-corail/10 px-3 py-2 text-sm font-medium text-corail">
            Cette activité a été annulée
          </div>
        )}

        <div className="flex items-center gap-2">
          <span className="flex h-8 w-8 items-center justify-center rounded-pill bg-vert/10 text-vert">
            <Icon size={16} />
          </span>
          <span className="text-sm font-medium text-content-secondary">{catInfo.label}</span>
        </div>

        <h1 className="mt-3 text-xl font-semibold text-content-primary">{event.title}</h1>

        <p className="mt-2 text-sm text-content-secondary">
          Organisé par {organizerName} · {formatEventDate(event.event_date)}
        </p>

        {event.location && (
          <p className="mt-3 text-sm text-content-secondary">
            <span className="font-medium text-content-primary">Lieu : </span>
            {event.location}
          </p>
        )}

        {event.description && (
          <p className="mt-3 whitespace-pre-wrap text-content-primary">{event.description}</p>
        )}

        <p className="mt-3 text-sm font-medium text-content-secondary">
          {attendees.length} / {event.max_attendees} places
        </p>
      </div>

      {actionError && <p className="text-sm text-corail">{actionError}</p>}

      {!isCancelled && !isOrganizer && (
        <button
          onClick={alreadyJoined ? handleLeave : handleJoin}
          disabled={busy || (!alreadyJoined && isFull)}
          className={`h-tap w-full rounded-pill font-medium transition-fast disabled:opacity-60 ${
            alreadyJoined
              ? 'border border-border text-content-primary hover:bg-surface-card'
              : 'bg-corail text-white hover:bg-corail-hover'
          }`}
        >
          {alreadyJoined ? 'Se désinscrire' : isFull ? 'Complet' : 'Je participe'}
        </button>
      )}

      {isOrganizer && !isCancelled && (
        <button
          onClick={handleCancel}
          disabled={busy}
          className="h-tap w-full rounded-pill border border-corail font-medium text-corail transition-fast hover:bg-corail/5 disabled:opacity-60"
        >
          Annuler l'activité
        </button>
      )}

      {attendees.length > 0 && (
        <div>
          <h2 className="mb-2 text-sm font-medium text-content-secondary">Participants</h2>
          <div className="flex flex-col gap-2">
            {attendees.map((a) => (
              <div key={a.user_id} className="rounded-card border border-border bg-surface-card p-3 text-sm text-content-primary">
                {a.name} {a.user_id === currentUserId && '(toi)'}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

MQEOF_SRC_APP_ACTIVITES_ID_PAGE_JSX

mkdir -p "src/app/activites"
cat > "src/app/activites/page.jsx" << 'MQEOF_SRC_APP_ACTIVITES_PAGE_JSX'
// Server Component : activités à venir du quartier, triées par date,
// filtrable par catégorie via ?category=sortie|musee|sport|jeux_de_societe|autre.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { EVENT_CATEGORIES, getEventCategoryInfo, formatEventDate } from '@/lib/eventCategories';
import { getPlaceholderImage } from '@/lib/placeholderImages';
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
    .select('id, category, title, location, event_date, max_attendees, user_id, photo_url')
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
                <Link href={`/activites/${event.id}`} className="h-20 w-20 flex-shrink-0 overflow-hidden rounded-card">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={event.photo_url || getPlaceholderImage(event.category)}
                    alt=""
                    className="h-full w-full object-cover"
                  />
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

echo "Formulaire activite mis a jour avec succes."
echo "Prochaine etape : executer la migration 025, puis git add -A && git commit -m \"formulaire activite redessine + photo couverture\" && git push"
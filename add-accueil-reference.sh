#!/usr/bin/env bash
set -e
echo "Refonte accueil selon reference + illustrations..."

mkdir -p "src/components"
cat > "src/components/AvatarStack.jsx" << 'MQEOF_SRC_COMPONENTS_AVATARSTACK_JSX'
// Petite pile d'avatars qui se chevauchent (participants à une activité,
// aperçu des voisins...). Respecte photo_visible comme partout ailleurs.

export default function AvatarStack({ people, max = 4, size = 24 }) {
  const shown = people.slice(0, max);
  const remaining = people.length - shown.length;

  return (
    <div className="flex items-center">
      {shown.map((person, i) => (
        <div
          key={person.user_id || i}
          className="flex items-center justify-center overflow-hidden rounded-pill border-2 border-surface bg-corail/10 font-medium text-corail"
          style={{
            width: size,
            height: size,
            fontSize: size * 0.4,
            marginLeft: i === 0 ? 0 : -size * 0.3,
          }}
        >
          {person.photo_visible && person.photo_url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={person.photo_url} alt="" className="h-full w-full object-cover" />
          ) : (
            (person.display_name || '?').charAt(0).toUpperCase()
          )}
        </div>
      ))}
      {remaining > 0 && (
        <div
          className="flex items-center justify-center rounded-pill border-2 border-surface bg-border font-medium text-content-secondary"
          style={{ width: size, height: size, fontSize: size * 0.35, marginLeft: -size * 0.3 }}
        >
          +{remaining}
        </div>
      )}
    </div>
  );
}

MQEOF_SRC_COMPONENTS_AVATARSTACK_JSX

mkdir -p "src/app"
cat > "src/app/page.jsx" << 'MQEOF_SRC_APP_PAGE_JSX'
// Page d'accueil — Server Component.
//
// Direction visuelle : pastilles de catégories pleinement colorées,
// cartes horizontales avec vraies photos (illustration générique en
// secours), pile d'avatars pour les activités et les voisins.
//
// Volontairement exclu (cohérent avec la section 80 du prompt maître) :
// pas de notation/étoiles (aucun système d'avis n'existe côté base), pas
// de tri algorithmique par popularité, pas de notification-appât.

import Link from 'next/link';
import { Search, Users, Store } from 'lucide-react';
import { createClient } from '@/lib/supabase/server';
import { POST_TYPES, getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';
import { formatEventDate } from '@/lib/eventCategories';
import { getPlaceholderImage } from '@/lib/placeholderImages';
import AvatarStack from '@/components/AvatarStack';

const POST_ATTRIBUTION = {
  don: 'Don par',
  entraide: 'Entraide proposée par',
  covoiturage: 'Covoiturage par',
  cherche: 'Recherché par',
};

function formatEventDateBadge(dateString) {
  const date = new Date(dateString);
  return {
    day: date.toLocaleDateString('fr-FR', { weekday: 'short' }).toUpperCase().replace('.', ''),
    date: date.getDate(),
    month: date.toLocaleDateString('fr-FR', { month: 'short' }).toUpperCase().replace('.', ''),
  };
}

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

  const [neighborsCount, featuredAlertResult, feedResult, upcomingEventsResult, neighborPreviewResult] =
    await Promise.all([
      supabase.from('profiles').select('*', { count: 'exact', head: true }).eq('quartier_id', quartierId),
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
        .select('id, category, title, location, event_date, max_attendees')
        .eq('quartier_id', quartierId)
        .eq('status', 'active')
        .gte('event_date', new Date().toISOString())
        .order('event_date', { ascending: true })
        .limit(3),
      supabase
        .from('profiles')
        .select('user_id, display_name, photo_url, photo_visible')
        .eq('quartier_id', quartierId)
        .neq('map_visibility', 'off')
        .limit(4),
    ]);

  const featuredAlert = featuredAlertResult.data;
  const feed = feedResult.data || [];
  const upcomingEvents = upcomingEventsResult.data || [];
  const neighborPreview = neighborPreviewResult.data || [];

  const relevantUserIds = [
    ...new Set([featuredAlert?.user_id, ...feed.map((p) => p.user_id)].filter(Boolean)),
  ];
  const feedPostIds = feed.map((p) => p.id);
  const eventIds = upcomingEvents.map((e) => e.id);

  const [{ data: authors }, { data: images }, { data: attendeeRows }] = await Promise.all([
    relevantUserIds.length > 0
      ? supabase.from('profiles').select('user_id, display_name').in('user_id', relevantUserIds)
      : Promise.resolve({ data: [] }),
    feedPostIds.length > 0
      ? supabase.from('post_images').select('post_id, storage_path, position').in('post_id', feedPostIds).order('position', { ascending: true })
      : Promise.resolve({ data: [] }),
    eventIds.length > 0
      ? supabase.from('event_attendees').select('event_id, user_id').in('event_id', eventIds)
      : Promise.resolve({ data: [] }),
  ]);

  const authorName = Object.fromEntries((authors || []).map((a) => [a.user_id, a.display_name]));

  const thumbnailByPost = {};
  for (const img of images || []) {
    if (!thumbnailByPost[img.post_id]) {
      thumbnailByPost[img.post_id] = supabase.storage.from('posts').getPublicUrl(img.storage_path).data.publicUrl;
    }
  }

  // Profils des participants pour la pile d'avatars de chaque activité.
  const attendeeUserIds = [...new Set((attendeeRows || []).map((a) => a.user_id))];
  const { data: attendeeProfiles } =
    attendeeUserIds.length > 0
      ? await supabase.from('profiles').select('user_id, display_name, photo_url, photo_visible').in('user_id', attendeeUserIds)
      : { data: [] };
  const attendeeProfileById = Object.fromEntries((attendeeProfiles || []).map((p) => [p.user_id, p]));

  const attendeesByEvent = {};
  for (const row of attendeeRows || []) {
    if (!attendeesByEvent[row.event_id]) attendeesByEvent[row.event_id] = [];
    const p = attendeeProfileById[row.user_id];
    if (p) attendeesByEvent[row.event_id].push(p);
  }

  return (
    <div className="flex flex-col p-4">
      <h1 className="text-xl font-semibold text-content-primary">
        {firstName ? `Bonjour ${firstName} 👋` : 'Bonjour 👋'}
      </h1>
      <p className="mt-1 text-sm text-content-secondary">
        Ravi de te revoir dans ton quartier.
      </p>

      <Link
        href="/annonces"
        className="mt-5 flex items-center gap-3 rounded-pill border border-border bg-surface-card px-4 py-3 shadow-soft transition-fast hover:shadow-none"
      >
        <Search size={17} className="text-content-secondary" />
        <span className="text-sm text-content-secondary">Rechercher dans le quartier</span>
      </Link>

      {/* Catégories — pastilles pleinement colorées */}
      <div className="-mx-4 mt-5 flex gap-2 overflow-x-auto px-4 pb-1">
        {POST_TYPES.map((cat, i) => {
          const Icon = cat.icon;
          const solid = i % 2 === 0 ? 'bg-corail text-white' : 'bg-vert text-white';
          return (
            <Link
              key={cat.type}
              href={`/annonces?type=${cat.type}`}
              className={`flex flex-shrink-0 items-center gap-1.5 rounded-pill px-3.5 py-2 text-xs font-medium shadow-soft transition-fast active:scale-95 ${solid}`}
            >
              <Icon size={14} />
              {cat.label}
            </Link>
          );
        })}
      </div>

      {/* Alerte la plus récente */}
      {featuredAlert && (
        <Link
          href={`/annonces/${featuredAlert.id}`}
          className="mt-5 flex items-center gap-3 rounded-card bg-corail/10 p-4 shadow-soft transition-fast hover:shadow-none"
        >
          <div className="h-10 w-10 flex-shrink-0 overflow-hidden rounded-pill">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={getPlaceholderImage('alerte')} alt="" className="h-full w-full object-cover" />
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

      {/* Près de chez toi — cartes horizontales avec vraie photo */}
      {feed.length > 0 && (
        <section className="mt-7">
          <div className="mb-3 flex items-baseline justify-between">
            <h2 className="text-base font-semibold text-content-primary">Près de chez toi</h2>
            <Link href="/annonces" className="text-xs text-content-secondary">
              Voir tout
            </Link>
          </div>

          <div className="-mx-4 flex gap-3 overflow-x-auto px-4 pb-1">
            {feed.map((post) => {
              const thumbnail = thumbnailByPost[post.id] || getPlaceholderImage(post.type);
              const attribution = POST_ATTRIBUTION[post.type] || 'Publié par';
              return (
                <Link key={post.id} href={`/annonces/${post.id}`} className="w-40 flex-shrink-0">
                  <div className="relative h-28 w-full overflow-hidden rounded-card bg-surface-card shadow-soft">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={thumbnail} alt="" className="h-full w-full object-cover" />
                  </div>
                  <p className="mt-2 line-clamp-2 text-sm font-medium text-content-primary">
                    {post.title}
                  </p>
                  <p className="mt-0.5 text-xs text-content-secondary">
                    {attribution} {authorName[post.user_id] || 'Voisin'}
                  </p>
                </Link>
              );
            })}
          </div>
        </section>
      )}

      {feed.length === 0 && !featuredAlert && (
        <div className="mt-7 rounded-card border border-border bg-surface-card p-6 text-center text-sm text-content-secondary">
          Rien de nouveau pour l'instant.
          <div className="mt-2">
            <Link href="/new" className="font-medium text-corail">
              Sois le premier à publier →
            </Link>
          </div>
        </div>
      )}

      {/* Prochaines activités — badge date + pile de participants */}
      {upcomingEvents.length > 0 && (
        <section className="mt-7">
          <div className="mb-3 flex items-baseline justify-between">
            <h2 className="text-base font-semibold text-content-primary">Prochaines activités</h2>
            <Link href="/activites" className="text-xs text-content-secondary">
              Voir tout
            </Link>
          </div>

          <div className="flex flex-col gap-3">
            {upcomingEvents.map((event) => {
              const badge = formatEventDateBadge(event.event_date);
              const attendees = attendeesByEvent[event.id] || [];
              return (
                <Link
                  key={event.id}
                  href={`/activites/${event.id}`}
                  className="flex gap-3 rounded-card border border-border bg-surface-card p-3 shadow-soft transition-fast hover:shadow-none"
                >
                  <div className="flex h-14 w-14 flex-shrink-0 flex-col items-center justify-center rounded-card bg-surface">
                    <span className="text-[10px] font-medium text-corail">{badge.day}</span>
                    <span className="text-lg font-semibold leading-none text-content-primary">{badge.date}</span>
                    <span className="text-[10px] text-content-secondary">{badge.month}</span>
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-medium text-content-primary">{event.title}</p>
                    <p className="mt-0.5 truncate text-xs text-content-secondary">
                      {new Date(event.event_date).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}
                      {event.location ? ` · ${event.location}` : ''}
                    </p>
                    {attendees.length > 0 && (
                      <div className="mt-1.5">
                        <AvatarStack people={attendees} size={20} />
                      </div>
                    )}
                  </div>
                </Link>
              );
            })}
          </div>
        </section>
      )}

      {/* Résumé communauté — deux cartes avec illustration de fond */}
      <div className="mt-7 grid grid-cols-2 gap-3">
        <Link
          href="/voisins"
          className="relative flex h-32 flex-col justify-end overflow-hidden rounded-card p-3 shadow-soft"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={getPlaceholderImage('communaute')}
            alt=""
            className="absolute inset-0 h-full w-full object-cover"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-black/55 to-transparent" />
          <div className="relative">
            <AvatarStack people={neighborPreview} size={22} />
            <p className="mt-1.5 text-xs font-medium text-white">
              {neighborsCount.count ?? 0} voisins peuvent aider
            </p>
          </div>
        </Link>

        <Link
          href="/commerces"
          className="relative flex h-32 flex-col justify-end overflow-hidden rounded-card p-3 shadow-soft"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={getPlaceholderImage('commerce')}
            alt=""
            className="absolute inset-0 h-full w-full object-cover"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-black/55 to-transparent" />
          <div className="relative flex items-center gap-1.5">
            <Store size={14} className="text-white" />
            <p className="text-xs font-medium text-white">Soutenons nos commerces</p>
          </div>
        </Link>
      </div>
    </div>
  );
}

MQEOF_SRC_APP_PAGE_JSX

mkdir -p "src/app/commerces/new"
cat > "src/app/commerces/new/page.jsx" << 'MQEOF_SRC_APP_COMMERCES_NEW_PAGE_JSX'
'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { PLACE_CATEGORIES } from '@/lib/placeCategories';

const MAX_PHOTO_SIZE = 5 * 1024 * 1024;

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

  const [photoFile, setPhotoFile] = useState(null);
  const [photoPreview, setPhotoPreview] = useState(null);
  const [photoError, setPhotoError] = useState('');

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
      setPhotoError('La photo doit faire moins de 5 Mo.');
      return;
    }

    setPhotoFile(file);
    setPhotoPreview(URL.createObjectURL(file));
  }

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

    if (photoFile) {
      const ext = photoFile.name.split('.').pop();
      const path = `${newPlace.id}/${crypto.randomUUID()}.${ext}`;
      const { error: uploadError } = await supabase.storage.from('places').upload(path, photoFile);
      if (!uploadError) {
        const publicUrl = supabase.storage.from('places').getPublicUrl(path).data.publicUrl;
        await supabase.from('places').update({ photo_url: publicUrl }).eq('id', newPlace.id);
      }
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
          <label className="mb-1 block text-sm font-medium text-content-primary">
            Photo <span className="text-content-secondary">(optionnel)</span>
          </label>
          {photoPreview ? (
            <div className="relative h-32 w-full overflow-hidden rounded-card">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={photoPreview} alt="" className="h-full w-full object-cover" />
            </div>
          ) : (
            <label className="flex h-32 w-full cursor-pointer flex-col items-center justify-center gap-1 rounded-card border border-dashed border-border text-content-secondary transition-fast hover:bg-surface-card">
              <span className="text-xl">+</span>
              <span className="text-xs">Ajouter une photo</span>
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

mkdir -p "src/app/commerces"
cat > "src/app/commerces/page.jsx" << 'MQEOF_SRC_APP_COMMERCES_PAGE_JSX'
'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';
import { PLACE_CATEGORIES, getPlaceCategoryInfo } from '@/lib/placeCategories';
import { sortByDistance, formatDistance } from '@/lib/distanceCalculator';
import { getPlaceholderImage } from '@/lib/placeholderImages';

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
        .select('id, category, name, description, address, lat, lng, photo_url')
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
          const distance = place._distance !== undefined ? formatDistance(place._distance) : null;
          return (
            <Link
              key={place.id}
              href={`/commerces/${place.id}`}
              className="flex items-center gap-3 rounded-card border border-border bg-surface-card p-3 transition-fast hover:bg-border/20"
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
import { getPlaceholderImage } from '@/lib/placeholderImages';

export default async function PlaceDetailPage({ params }) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: place, error } = await supabase
    .from('places')
    .select('id, category, name, description, address, phone, website, added_by, photo_url')
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

      <div className="relative h-44 w-full overflow-hidden rounded-card bg-surface-card">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={place.photo_url || getPlaceholderImage(place.category)}
          alt=""
          className="h-full w-full object-cover"
        />
      </div>

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

mkdir -p "src/app/annonces"
cat > "src/app/annonces/page.jsx" << 'MQEOF_SRC_APP_ANNONCES_PAGE_JSX'
// Server Component : liste des annonces du quartier de l'utilisateur,
// filtrable par type via ?type=don|entraide|covoiturage|cherche|alerte.

import Link from 'next/link';
import Image from 'next/image';
import { createClient } from '@/lib/supabase/server';
import { POST_TYPES, formatRelativeTime } from '@/lib/postTypes';
import { getPlaceholderImage } from '@/lib/placeholderImages';

export default async function AnnoncesPage({ searchParams }) {
  const params = await searchParams;
  const activeType = params?.type;

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
            Termine d'abord ton inscription pour voir les annonces de ton quartier.
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
    .from('posts')
    .select('id, type, title, description, created_at, user_id')
    .eq('quartier_id', profile.quartier_id)
    .eq('status', 'active')
    .order('created_at', { ascending: false })
    .limit(30);

  if (activeType) {
    query = query.eq('type', activeType);
  }

  const { data: posts, error } = await query;

  // Requêtes séparées : pas de clé étrangère directe posts → profiles, et
  // on récupère seulement la 1ère photo de chaque annonce pour la vignette.
  let authorNames = {};
  let thumbnailByPost = {};
  if (posts?.length > 0) {
    const userIds = [...new Set(posts.map((p) => p.user_id))];
    const postIds = posts.map((p) => p.id);

    const [{ data: authors }, { data: images }] = await Promise.all([
      supabase.from('profiles').select('user_id, display_name').in('user_id', userIds),
      supabase
        .from('post_images')
        .select('post_id, storage_path, position')
        .in('post_id', postIds)
        .order('position', { ascending: true }),
    ]);

    authorNames = Object.fromEntries((authors || []).map((a) => [a.user_id, a.display_name]));

    for (const img of images || []) {
      if (!thumbnailByPost[img.post_id]) {
        thumbnailByPost[img.post_id] = supabase.storage.from('posts').getPublicUrl(img.storage_path).data.publicUrl;
      }
    }
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      {/* Filtres de catégorie */}
      <div className="flex gap-2 overflow-x-auto pb-1">
        <FilterPill href="/annonces" label="Toutes" active={!activeType} />
        {POST_TYPES.map((cat) => (
          <FilterPill
            key={cat.type}
            href={`/annonces?type=${cat.type}`}
            label={cat.label}
            icon={cat.icon}
            active={activeType === cat.type}
          />
        ))}
      </div>

      {error && (
        <p className="text-sm text-corail">
          Impossible de charger les annonces pour le moment.
        </p>
      )}

      {!error && posts?.length === 0 && (
        <div className="mt-6 rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">
            Aucune annonce {activeType ? `dans cette catégorie` : ''} pour l'instant.
          </p>
          <p className="mt-1 text-sm text-content-secondary">
            Sois le premier à publier quelque chose dans ton quartier !
          </p>
          <Link
            href={activeType ? `/new?type=${activeType}` : '/new'}
            className="mt-4 inline-block h-tap rounded-pill bg-corail px-6 py-3 font-medium text-white transition-fast hover:bg-corail-hover"
          >
            Publier une annonce
          </Link>
        </div>
      )}

      <div className="flex flex-col gap-3">
        {posts?.map((post) => {
          const thumbnail = thumbnailByPost[post.id] || getPlaceholderImage(post.type);
          return (
            <Link
              key={post.id}
              href={`/annonces/${post.id}`}
              className="flex gap-3 rounded-card border border-border bg-surface-card p-4 shadow-soft transition-fast hover:bg-border/30 active:scale-[0.99]"
            >
              <div className="relative h-14 w-14 flex-shrink-0 overflow-hidden rounded-card bg-surface">
                <Image src={thumbnail} alt="" fill sizes="56px" className="object-cover" />
              </div>
              <div className="min-w-0 flex-1">
                <div className="flex items-center justify-between gap-2">
                  <span className="truncate text-sm font-medium text-content-secondary">
                    {authorNames[post.user_id] || 'Voisin'}
                  </span>
                  <span className="flex-shrink-0 text-xs text-content-secondary">
                    {formatRelativeTime(post.created_at)}
                  </span>
                </div>
                <p className="mt-0.5 truncate font-semibold text-content-primary">
                  {post.title}
                </p>
                {post.description && (
                  <p className="mt-0.5 line-clamp-2 text-sm text-content-secondary">
                    {post.description}
                  </p>
                )}
              </div>
            </Link>
          );
        })}
      </div>
    </div>
  );
}

function FilterPill({ href, label, icon: Icon, active }) {
  return (
    <Link
      href={href}
      className={`flex flex-shrink-0 items-center gap-1.5 rounded-pill border px-4 py-2 text-sm font-medium transition-fast ${
        active
          ? 'border-corail bg-corail text-white'
          : 'border-border bg-surface text-content-primary hover:bg-surface-card'
      }`}
    >
      {Icon && <Icon size={14} />}
      {label}
    </Link>
  );
}

MQEOF_SRC_APP_ANNONCES_PAGE_JSX

mkdir -p "src/app/annonces/[id]"
cat > "src/app/annonces/[id]/page.jsx" << 'MQEOF_SRC_APP_ANNONCES_ID_PAGE_JSX'
// Server Component : détail d'une annonce. La policy RLS "posts_select_own_quartier"
// garantit déjà qu'on ne peut pas voir l'annonce d'un autre quartier — si
// jamais quelqu'un force une URL /annonces/[id] hors de son quartier, la
// requête retourne simplement "non trouvé", jamais les données.

import Link from 'next/link';
import Image from 'next/image';
import { notFound } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';
import { getPlaceholderImage } from '@/lib/placeholderImages';
import { getLevel } from '@/lib/levels';
import ContactActions from './ContactActions';

export default async function AnnonceDetailPage({ params }) {
  const { id } = await params;
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: post, error } = await supabase
    .from('posts')
    .select('id, type, title, description, availability, approx_zone, created_at, user_id')
    .eq('id', id)
    .single();

  if (error || !post) {
    notFound();
  }

  // Requête séparée pour l'auteur : il n'existe pas de clé étrangère directe
  // entre `posts` et `profiles` (les deux référencent `auth.users`
  // séparément), donc une jointure imbriquée `profiles(...)` échouerait.
  const { data: authorProfile } = await supabase
    .from('profiles')
    .select('display_name, points, photo_url, photo_visible')
    .eq('user_id', post.user_id)
    .single();

  const { data: images } = await supabase
    .from('post_images')
    .select('storage_path, position')
    .eq('post_id', post.id)
    .order('position', { ascending: true });

  const photoUrls = (images || []).map(
    (img) => supabase.storage.from('posts').getPublicUrl(img.storage_path).data.publicUrl
  );

  const typeInfo = getPostTypeInfo(post.type);
  const TypeIcon = typeInfo.icon;
  const isOwnPost = post.user_id === user.id;
  const authorName = authorProfile?.display_name || 'Voisin';

  // Autres annonces du même auteur (hors celle-ci)
  const { data: otherPosts } = await supabase
    .from('posts')
    .select('id, title, type')
    .eq('user_id', post.user_id)
    .eq('status', 'active')
    .neq('id', post.id)
    .limit(3);

  return (
    <div className="flex flex-col gap-5 p-4">
      <Link href="/annonces" className="text-sm font-medium text-content-secondary">
        ← Retour aux annonces
      </Link>

      {photoUrls.length > 0 ? (
        <div className="-mx-4 flex gap-2 overflow-x-auto px-4">
          {photoUrls.map((url, i) => (
            <div key={i} className="relative h-56 w-full flex-shrink-0 overflow-hidden rounded-card bg-surface-card">
              <Image src={url} alt="" fill sizes="100vw" className="object-cover" />
            </div>
          ))}
        </div>
      ) : (
        <div className="relative h-48 w-full overflow-hidden rounded-card bg-surface-card">
          <Image src={getPlaceholderImage(post.type)} alt="" fill sizes="100vw" className="object-cover" />
        </div>
      )}

      <div className="rounded-card border border-border bg-surface-card p-5">
        <div className="flex items-center gap-2">
          <span className="flex h-8 w-8 items-center justify-center rounded-pill bg-surface text-content-primary">
            <TypeIcon size={16} />
          </span>
          <span className="text-sm font-medium text-content-secondary">{typeInfo.label}</span>
        </div>

        <h1 className="mt-3 text-xl font-semibold text-content-primary">{post.title}</h1>

        <div className="mt-2 flex items-center gap-2 text-sm text-content-secondary">
          <div className="flex h-6 w-6 flex-shrink-0 items-center justify-center overflow-hidden rounded-pill bg-corail/10 text-[10px] font-semibold text-corail">
            {authorProfile?.photo_visible && authorProfile?.photo_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={authorProfile.photo_url} alt="" className="h-full w-full object-cover" />
            ) : (
              authorName.charAt(0).toUpperCase()
            )}
          </div>
          <span>{authorName}</span>
          <span className="rounded-pill bg-surface px-2 py-0.5 text-xs font-medium text-content-secondary">
            {getLevel(authorProfile?.points || 0).label}
          </span>
          <span>·</span>
          <span>{formatRelativeTime(post.created_at)}</span>
        </div>

        {post.description && (
          <p className="mt-4 whitespace-pre-wrap text-content-primary">{post.description}</p>
        )}

        {post.availability && (
          <p className="mt-3 text-sm text-content-secondary">
            <span className="font-medium text-content-primary">Disponibilité : </span>
            {post.availability}
          </p>
        )}

        {post.approx_zone && (
          <p className="mt-1 text-sm text-content-secondary">
            <span className="font-medium text-content-primary">Zone : </span>
            {post.approx_zone}
          </p>
        )}
      </div>

      {!isOwnPost && (
        <ContactActions postId={post.id} postAuthorId={post.user_id} postTitle={post.title} />
      )}

      {isOwnPost && (
        <div className="rounded-card border border-border bg-surface-card p-4 text-center text-sm text-content-secondary">
          C'est ta propre annonce.{' '}
          <Link href="/mes-annonces" className="font-medium text-corail">
            Gérer mes annonces
          </Link>
        </div>
      )}

      {otherPosts?.length > 0 && (
        <div>
          <h2 className="mb-2 text-sm font-medium text-content-secondary">
            Autres annonces de {authorName}
          </h2>
          <div className="flex flex-col gap-2">
            {otherPosts.map((op) => {
              const OpIcon = getPostTypeInfo(op.type).icon;
              return (
                <Link
                  key={op.id}
                  href={`/annonces/${op.id}`}
                  className="flex items-center gap-2 rounded-card border border-border bg-surface-card p-3 text-sm text-content-primary transition-fast hover:bg-border/30"
                >
                  <OpIcon size={16} /> {op.title}
                </Link>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}

MQEOF_SRC_APP_ANNONCES_ID_PAGE_JSX

mkdir -p "src/app/activites"
cat > "src/app/activites/page.jsx" << 'MQEOF_SRC_APP_ACTIVITES_PAGE_JSX'
// Server Component : activités à venir du quartier, triées par date.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { getEventCategoryInfo, formatEventDate } from '@/lib/eventCategories';
import { getPlaceholderImage } from '@/lib/placeholderImages';

export default async function ActivitesPage() {
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

  const { data: events, error } = await supabase
    .from('events')
    .select('id, category, title, location, event_date, max_attendees, user_id')
    .eq('quartier_id', profile.quartier_id)
    .eq('status', 'active')
    .gte('event_date', new Date().toISOString())
    .order('event_date', { ascending: true })
    .limit(30);

  let attendeeCounts = {};
  if (events?.length > 0) {
    const { data: attendees } = await supabase
      .from('event_attendees')
      .select('event_id')
      .in('event_id', events.map((e) => e.id));
    for (const a of attendees || []) {
      attendeeCounts[a.event_id] = (attendeeCounts[a.event_id] || 0) + 1;
    }
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
          return (
            <Link
              key={event.id}
              href={`/activites/${event.id}`}
              className="flex gap-3 rounded-card border border-border bg-surface-card p-4 shadow-soft transition-fast hover:bg-border/20 active:scale-[0.99]"
            >
              <div className="h-14 w-14 flex-shrink-0 overflow-hidden rounded-card">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={getPlaceholderImage(event.category)}
                  alt=""
                  className="h-full w-full object-cover"
                />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-xs font-medium text-content-secondary">
                  {formatEventDate(event.event_date)} · {catInfo.label}
                </p>
                <p className="mt-0.5 font-semibold text-content-primary">{event.title}</p>
                {event.location && (
                  <p className="mt-0.5 truncate text-sm text-content-secondary">{event.location}</p>
                )}
                <p className={`mt-1 text-xs font-medium ${isFull ? 'text-corail' : 'text-content-secondary'}`}>
                  {isFull ? 'Complet' : `${count} / ${event.max_attendees} places`}
                </p>
              </div>
            </Link>
          );
        })}
      </div>
    </div>
  );
}

MQEOF_SRC_APP_ACTIVITES_PAGE_JSX

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
      .select('id, category, title, description, location, event_date, max_attendees, status, user_id')
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
        <img src={getPlaceholderImage(event.category)} alt="" className="h-full w-full object-cover" />
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

mkdir -p "src/lib"
cat > "src/lib/placeholderImages.js" << 'MQEOF_SRC_LIB_PLACEHOLDERIMAGES_JS'
// Illustration générique affichée automatiquement quand une annonce ou une
// activité n'a pas de vraie photo — évite les cases vides.

export function getPlaceholderImage(type) {
  return `/placeholders/${type}.png`;
}

MQEOF_SRC_LIB_PLACEHOLDERIMAGES_JS

mkdir -p "public/placeholders"
base64 -d > "public/placeholders/don.png" << 'MQB64EOF_PUBLIC_PLACEHOLDERS_DON_PNG'
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
MQB64EOF_PUBLIC_PLACEHOLDERS_DON_PNG

mkdir -p "public/placeholders"
base64 -d > "public/placeholders/entraide.png" << 'MQB64EOF_PUBLIC_PLACEHOLDERS_ENTRAIDE_PNG'
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
MQB64EOF_PUBLIC_PLACEHOLDERS_ENTRAIDE_PNG

mkdir -p "public/placeholders"
base64 -d > "public/placeholders/covoiturage.png" << 'MQB64EOF_PUBLIC_PLACEHOLDERS_COVOITURAGE_PNG'
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
MQB64EOF_PUBLIC_PLACEHOLDERS_COVOITURAGE_PNG

mkdir -p "public/placeholders"
base64 -d > "public/placeholders/cherche.png" << 'MQB64EOF_PUBLIC_PLACEHOLDERS_CHERCHE_PNG'
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
MQB64EOF_PUBLIC_PLACEHOLDERS_CHERCHE_PNG

mkdir -p "public/placeholders"
base64 -d > "public/placeholders/alerte.png" << 'MQB64EOF_PUBLIC_PLACEHOLDERS_ALERTE_PNG'
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
MQB64EOF_PUBLIC_PLACEHOLDERS_ALERTE_PNG

mkdir -p "public/placeholders"
base64 -d > "public/placeholders/sortie.png" << 'MQB64EOF_PUBLIC_PLACEHOLDERS_SORTIE_PNG'
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
MQB64EOF_PUBLIC_PLACEHOLDERS_SORTIE_PNG

mkdir -p "public/placeholders"
base64 -d > "public/placeholders/musee.png" << 'MQB64EOF_PUBLIC_PLACEHOLDERS_MUSEE_PNG'
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
MQB64EOF_PUBLIC_PLACEHOLDERS_MUSEE_PNG

mkdir -p "public/placeholders"
base64 -d > "public/placeholders/sport.png" << 'MQB64EOF_PUBLIC_PLACEHOLDERS_SPORT_PNG'
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
MQB64EOF_PUBLIC_PLACEHOLDERS_SPORT_PNG

mkdir -p "public/placeholders"
base64 -d > "public/placeholders/jeux_de_societe.png" << 'MQB64EOF_PUBLIC_PLACEHOLDERS_JEUX_DE_SOCIETE_PNG'
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
MQB64EOF_PUBLIC_PLACEHOLDERS_JEUX_DE_SOCIETE_PNG

mkdir -p "public/placeholders"
base64 -d > "public/placeholders/autre.png" << 'MQB64EOF_PUBLIC_PLACEHOLDERS_AUTRE_PNG'
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
MQB64EOF_PUBLIC_PLACEHOLDERS_AUTRE_PNG

mkdir -p "public/placeholders"
base64 -d > "public/placeholders/commerce.png" << 'MQB64EOF_PUBLIC_PLACEHOLDERS_COMMERCE_PNG'
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
MQB64EOF_PUBLIC_PLACEHOLDERS_COMMERCE_PNG

mkdir -p "public/placeholders"
base64 -d > "public/placeholders/restaurant.png" << 'MQB64EOF_PUBLIC_PLACEHOLDERS_RESTAURANT_PNG'
iVBORw0KGgoAAAANSUhEUgAAAZAAAAGQCAIAAAAP3aGbAAAFhklEQVR4nO3duw3CQBBAQUAUQkfkFOicjtwDIqcBxFdwPDwTW9bawdMGJ3s9n08rgILN6AEAHiVYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkLEdPcD/2B2n2xfM+8MS7hBy92Hf8U8v6nfYsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8gQLCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8gQLCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8gQLCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8gQLCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8gQLCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyBAsIEOwgAzBAjIEC8gQLCBDsIAMwQIyBAvIECwgQ7CADMECMgQLyNiOHiBsd5w+ev1v3gEGsmHxhHl/GD0CiyZYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVk+AkFy3X1E/Uv/KfDp+6/xoYFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkOOn+ui+fb3YCG2xYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkrOfzafQMAA+xYQEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkCBaQIVhAhmABGYIFZAgWkCFYQIZgARmCBWQIFpAhWECGYAEZggVkXABM9CgunRPahAAAAABJRU5ErkJggg==
MQB64EOF_PUBLIC_PLACEHOLDERS_RESTAURANT_PNG

mkdir -p "public/placeholders"
base64 -d > "public/placeholders/sante.png" << 'MQB64EOF_PUBLIC_PLACEHOLDERS_SANTE_PNG'
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
MQB64EOF_PUBLIC_PLACEHOLDERS_SANTE_PNG

mkdir -p "public/placeholders"
base64 -d > "public/placeholders/loisirs.png" << 'MQB64EOF_PUBLIC_PLACEHOLDERS_LOISIRS_PNG'
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
MQB64EOF_PUBLIC_PLACEHOLDERS_LOISIRS_PNG

mkdir -p "public/placeholders"
base64 -d > "public/placeholders/service.png" << 'MQB64EOF_PUBLIC_PLACEHOLDERS_SERVICE_PNG'
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
MQB64EOF_PUBLIC_PLACEHOLDERS_SERVICE_PNG

mkdir -p "public/placeholders"
base64 -d > "public/placeholders/site_touristique.png" << 'MQB64EOF_PUBLIC_PLACEHOLDERS_SITE_TOURISTIQUE_PNG'
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
MQB64EOF_PUBLIC_PLACEHOLDERS_SITE_TOURISTIQUE_PNG

mkdir -p "public/placeholders"
base64 -d > "public/placeholders/communaute.png" << 'MQB64EOF_PUBLIC_PLACEHOLDERS_COMMUNAUTE_PNG'
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
MQB64EOF_PUBLIC_PLACEHOLDERS_COMMUNAUTE_PNG

echo "Accueil refondu avec succes."
echo "Prochaine etape : executer la migration 022, puis git add -A && git commit -m \"accueil selon reference + illustrations + photos commerces\" && git push"
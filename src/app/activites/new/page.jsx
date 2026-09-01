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


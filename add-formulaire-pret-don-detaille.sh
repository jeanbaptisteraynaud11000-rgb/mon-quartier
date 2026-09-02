#!/usr/bin/env bash
set -e
echo "Formulaire detaille Pret/Don..."

mkdir -p "src/app/new"
cat > "src/app/new/page.jsx" << 'MQEOF_SRC_APP_NEW_PAGE_JSX'
'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { POST_TYPES } from '@/lib/postTypes';
import { compressImage } from '@/lib/compressImage';
import { X, ChevronDown, ChevronUp } from 'lucide-react';

const MAX_PHOTOS = 5;
const MAX_PHOTO_SIZE = 5 * 1024 * 1024; // 5 Mo, aligné sur la limite du bucket

const AVAILABILITY_PRESETS = ["Aujourd'hui", 'Cette semaine', 'Flexible'];
const CONDITIONS = [
  { value: 'neuf', label: 'Neuf' },
  { value: 'tres_bon', label: 'Très bon' },
  { value: 'bon', label: 'Bon' },
  { value: 'a_reparer', label: 'À réparer' },
];
const LOAN_DURATIONS = [
  { value: '1_a_3_jours', label: '1 à 3 jours' },
  { value: '1_semaine', label: '1 semaine' },
  { value: 'flexible', label: 'Flexible' },
];

export default function NewPostPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const initialType = searchParams.get('type');

  const [quartierId, setQuartierId] = useState(null);
  const [loadingProfile, setLoadingProfile] = useState(true);
  const [myPhone, setMyPhone] = useState('');

  const [selectedType, setSelectedType] = useState(initialType || null);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [availability, setAvailability] = useState('');
  const [approxZone, setApproxZone] = useState('');
  const [zoneCoords, setZoneCoords] = useState(null); // { lat, lng }
  const [zoneSuggestions, setZoneSuggestions] = useState([]);
  const zoneDebounceRef = useRef(null);

  // Champs spécifiques Prêt/Don uniquement.
  const [loanType, setLoanType] = useState('pret');
  const [itemCondition, setItemCondition] = useState(null);
  const [brandModel, setBrandModel] = useState('');
  const [loanDuration, setLoanDuration] = useState(null);
  const [depositRequired, setDepositRequired] = useState(false);
  const [pickupPreference, setPickupPreference] = useState('chez_moi');
  const [showPhone, setShowPhone] = useState(false);
  const [extraNotes, setExtraNotes] = useState('');
  const [showMoreOptions, setShowMoreOptions] = useState(false);

  const [photos, setPhotos] = useState([]); // [{ file, previewUrl }]
  const [photoError, setPhotoError] = useState('');

  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  // Verrou synchrone en plus du state React : `submitting` ne se propage
  // qu'au prochain rendu, ce qui laisse une fenêtre où un double-clic très
  // rapide peut déclencher handleSubmit deux fois avant que le bouton ne
  // soit visuellement désactivé. Une ref, elle, est lue/écrite immédiatement.
  const hasSubmittedRef = useRef(false);

  const isDonType = selectedType === 'don';

  useEffect(() => {
    async function loadProfile() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        router.push('/login');
        return;
      }
      const { data: profile } = await supabase
        .from('profiles')
        .select('quartier_id, phone')
        .eq('user_id', user.id)
        .single();

      if (!profile?.quartier_id) {
        router.push('/onboarding');
        return;
      }

      setQuartierId(profile.quartier_id);
      setMyPhone(profile.phone || '');
      setLoadingProfile(false);
    }
    loadProfile();
  }, [router]);

  // Nettoyage des URLs de prévisualisation à la destruction du composant,
  // pour ne pas accumuler de fuite mémoire côté navigateur.
  useEffect(() => {
    return () => {
      photos.forEach((p) => URL.revokeObjectURL(p.previewUrl));
    };
  }, [photos]);

  async function handlePhotoSelect(e) {
    const files = Array.from(e.target.files || []);
    setPhotoError('');
    e.target.value = ''; // permet de re-sélectionner le même fichier après suppression

    const accepted = ['image/jpeg', 'image/png', 'image/webp'];
    const toAdd = [];

    for (const file of files) {
      if (!accepted.includes(file.type)) {
        setPhotoError('Seules les images JPEG, PNG ou WebP sont acceptées.');
        continue;
      }
      if (file.size > MAX_PHOTO_SIZE) {
        setPhotoError('Chaque photo doit faire moins de 5 Mo.');
        continue;
      }
      try {
        const compressed = await compressImage(file);
        toAdd.push({ file: compressed, previewUrl: URL.createObjectURL(compressed) });
      } catch {
        toAdd.push({ file, previewUrl: URL.createObjectURL(file) });
      }
    }

    setPhotos((prev) => {
      const combined = [...prev, ...toAdd];
      if (combined.length > MAX_PHOTOS) {
        setPhotoError(`Maximum ${MAX_PHOTOS} photos.`);
        return combined.slice(0, MAX_PHOTOS);
      }
      return combined;
    });
  }

  function removePhoto(index) {
    setPhotos((prev) => {
      URL.revokeObjectURL(prev[index].previewUrl);
      return prev.filter((_, i) => i !== index);
    });
  }

  function handleZoneChange(value) {
    setApproxZone(value);
    setZoneCoords(null);

    if (zoneDebounceRef.current) clearTimeout(zoneDebounceRef.current);
    if (value.trim().length < 4) {
      setZoneSuggestions([]);
      return;
    }

    const queryAtCallTime = value;

    zoneDebounceRef.current = setTimeout(async () => {
      try {
        const res = await fetch(
          `https://api-adresse.data.gouv.fr/search/?q=${encodeURIComponent(queryAtCallTime)}&limit=5`
        );
        const json = await res.json();
        setApproxZone((current) => {
          if (current === queryAtCallTime) {
            setZoneSuggestions(json.features || []);
          }
          return current;
        });
      } catch {
        setZoneSuggestions([]);
      }
    }, 300);
  }

  function handleSelectZone(feature) {
    const [lng, lat] = feature.geometry.coordinates;
    setApproxZone(feature.properties.label);
    setZoneCoords({ lat, lng });
    setZoneSuggestions([]);
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');

    if (hasSubmittedRef.current) return;

    if (!title.trim()) {
      setError('Le titre est obligatoire.');
      return;
    }
    if (showPhone && !myPhone) {
      setError("Ajoute d'abord un numéro dans ton profil pour pouvoir le partager sur cette annonce.");
      return;
    }

    hasSubmittedRef.current = true;
    setSubmitting(true);

    const { data: { user } } = await supabase.auth.getUser();

    const { data: newPost, error: insertError } = await supabase
      .from('posts')
      .insert({
        user_id: user.id,
        quartier_id: quartierId,
        type: selectedType,
        title: title.trim(),
        description: description.trim() || null,
        availability: availability.trim() || null,
        approx_zone: approxZone.trim() || null,
        lat: zoneCoords?.lat || null,
        lng: zoneCoords?.lng || null,
        status: 'active',
        ...(isDonType && {
          loan_type: loanType,
          item_condition: itemCondition,
          brand_model: brandModel.trim() || null,
          loan_duration: loanType === 'pret' ? loanDuration : null,
          deposit_required: depositRequired,
          pickup_preference: pickupPreference,
          show_phone: showPhone,
          extra_notes: extraNotes.trim() || null,
        }),
      })
      .select('id')
      .single();

    if (insertError || !newPost) {
      setSubmitting(false);
      hasSubmittedRef.current = false;
      setError("Une erreur est survenue lors de la publication. Réessaie.");
      return;
    }

    if (photos.length > 0) {
      for (let i = 0; i < photos.length; i++) {
        const { file } = photos[i];
        const ext = file.name.split('.').pop();
        const randomName = `${crypto.randomUUID()}.${ext}`;
        const path = `${newPost.id}/${randomName}`;

        const { error: uploadError } = await supabase.storage.from('posts').upload(path, file);

        if (!uploadError) {
          await supabase.from('post_images').insert({
            post_id: newPost.id,
            storage_path: path,
            position: i,
          });
        }
      }
    }

    setSubmitting(false);
    router.push(`/annonces/${newPost.id}`);
  }

  if (loadingProfile) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="skeleton h-4 w-40" />
      </div>
    );
  }

  if (!selectedType) {
    return (
      <div className="flex flex-col gap-3 p-6">
        <h1 className="mb-2 text-xl font-semibold text-content-primary">
          Que souhaitez-vous partager ?
        </h1>
        {POST_TYPES.map((cat) => {
          const Icon = cat.icon;
          return (
            <button
              key={cat.type}
              onClick={() => setSelectedType(cat.type)}
              className="flex items-center gap-4 rounded-card border border-border bg-surface-card px-4 py-4 text-left transition-fast hover:bg-border/40 active:scale-[0.98]"
            >
              <span className="flex h-10 w-10 items-center justify-center rounded-pill bg-surface text-content-primary">
                <Icon size={20} />
              </span>
              <span className="font-medium text-content-primary">{cat.label}</span>
            </button>
          );
        })}
      </div>
    );
  }

  const typeInfo = POST_TYPES.find((t) => t.type === selectedType);

  return (
    <div className="p-6">
      <button
        onClick={() => setSelectedType(null)}
        className="mb-4 text-sm font-medium text-content-secondary"
      >
        ← Changer de catégorie
      </button>

      <div className="mb-1 flex items-center gap-2">
        <span className="flex h-10 w-10 items-center justify-center rounded-pill bg-surface-card text-content-primary">
          {typeInfo && <typeInfo.icon size={20} />}
        </span>
        <h1 className="text-xl font-semibold text-content-primary">Déposer une annonce</h1>
      </div>
      <p className="mb-6 text-sm text-content-secondary">Simple et rapide — 30 secondes</p>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        {/* Sous-choix Prêt / Don, uniquement pour cette catégorie */}
        {isDonType && (
          <div>
            <label className="mb-1 block text-sm font-medium text-content-primary">Type</label>
            <div className="grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={() => setLoanType('pret')}
                className={`rounded-card border px-3 py-3 text-sm font-medium transition-fast ${
                  loanType === 'pret'
                    ? 'border-corail bg-corail/5 text-corail'
                    : 'border-border bg-surface text-content-primary hover:bg-surface-card'
                }`}
              >
                🎁 Prêt
              </button>
              <button
                type="button"
                onClick={() => setLoanType('don')}
                className={`rounded-card border px-3 py-3 text-sm font-medium transition-fast ${
                  loanType === 'don'
                    ? 'border-corail bg-corail/5 text-corail'
                    : 'border-border bg-surface text-content-primary hover:bg-surface-card'
                }`}
              >
                🤍 Don
              </button>
            </div>
          </div>
        )}

        <div>
          <label htmlFor="title" className="mb-1 block text-sm font-medium text-content-primary">
            Titre
          </label>
          <input
            id="title"
            type="text"
            required
            maxLength={100}
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Ex : Perceuse à prêter"
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium text-content-primary">
            Photos <span className="text-content-secondary">(optionnel, {MAX_PHOTOS} max)</span>
          </label>

          <div className="flex flex-wrap gap-2">
            {photos.map((photo, i) => (
              <div key={i} className="relative h-20 w-20 overflow-hidden rounded-card bg-surface-card">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={photo.previewUrl} alt="" className="h-full w-full object-cover" />
                <button
                  type="button"
                  onClick={() => removePhoto(i)}
                  aria-label="Retirer la photo"
                  className="absolute right-1 top-1 flex h-5 w-5 items-center justify-center rounded-pill bg-black/60 text-white"
                >
                  <X size={12} />
                </button>
              </div>
            ))}

            {photos.length < MAX_PHOTOS && (
              <label className="flex h-20 w-20 cursor-pointer flex-col items-center justify-center gap-1 rounded-card border border-dashed border-border text-content-secondary transition-fast hover:bg-surface-card">
                <span className="text-xl">+</span>
                <span className="text-[10px]">Ajouter</span>
                <input
                  type="file"
                  accept="image/jpeg,image/png,image/webp"
                  multiple
                  onChange={handlePhotoSelect}
                  className="hidden"
                />
              </label>
            )}
          </div>

          {photoError && <p className="mt-1 text-xs text-corail">{photoError}</p>}

          <p className="mt-2 text-xs text-content-secondary">
            Attention à ne pas montrer d'informations personnelles (adresse complète, plaque
            d'immatriculation...) sur tes photos.
          </p>
        </div>

        <div>
          <label htmlFor="description" className="mb-1 block text-sm font-medium text-content-primary">
            Description <span className="text-content-secondary">(optionnel)</span>
          </label>
          <textarea
            id="description"
            rows={4}
            maxLength={1000}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Décrivez votre objet en quelques mots..."
            className="w-full resize-none rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        {/* État de l'objet — uniquement Prêt/Don */}
        {isDonType && (
          <div>
            <label className="mb-1 block text-sm font-medium text-content-primary">État</label>
            <div className="grid grid-cols-2 gap-2">
              {CONDITIONS.map((c) => (
                <button
                  key={c.value}
                  type="button"
                  onClick={() => setItemCondition(c.value)}
                  className={`rounded-card border px-3 py-2.5 text-sm font-medium transition-fast ${
                    itemCondition === c.value
                      ? 'border-corail bg-corail/5 text-corail'
                      : 'border-border bg-surface text-content-primary hover:bg-surface-card'
                  }`}
                >
                  {c.label}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Disponibilité — préréglages rapides, valable pour tous les types */}
        <div>
          <label className="mb-1 block text-sm font-medium text-content-primary">
            Disponibilité <span className="text-content-secondary">(optionnel)</span>
          </label>
          <div className="flex flex-wrap gap-2">
            {AVAILABILITY_PRESETS.map((preset) => (
              <button
                key={preset}
                type="button"
                onClick={() => setAvailability(availability === preset ? '' : preset)}
                className={`rounded-pill border px-4 py-2 text-sm font-medium transition-fast ${
                  availability === preset
                    ? 'border-corail bg-corail/5 text-corail'
                    : 'border-border bg-surface text-content-primary hover:bg-surface-card'
                }`}
              >
                {preset}
              </button>
            ))}
          </div>
        </div>

        <div className="relative">
          <label htmlFor="approxZone" className="mb-1 block text-sm font-medium text-content-primary">
            Zone approximative <span className="text-content-secondary">(optionnel)</span>
          </label>
          <input
            id="approxZone"
            type="text"
            maxLength={100}
            value={approxZone}
            onChange={(e) => handleZoneChange(e.target.value)}
            placeholder="Ex : proche de la mairie"
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
          {zoneSuggestions.length > 0 && (
            <ul className="absolute z-10 mt-1 w-full overflow-hidden rounded-card border border-border bg-surface shadow-soft">
              {zoneSuggestions.map((feature) => (
                <li key={feature.properties.id}>
                  <button
                    type="button"
                    onClick={() => handleSelectZone(feature)}
                    className="w-full px-4 py-3 text-left text-sm text-content-primary hover:bg-surface-card"
                  >
                    {feature.properties.label}
                  </button>
                </li>
              ))}
            </ul>
          )}
          <p className="mt-1 text-xs text-content-secondary">
            Visible par tout ton quartier, quelle que soit la zone choisie — ça sert juste à
            calculer une distance approximative pour les autres.
          </p>
          {zoneCoords && (
            <p className="mt-1 text-xs text-vert">
              ✓ Position capturée : {zoneCoords.lat.toFixed(4)}, {zoneCoords.lng.toFixed(4)}
            </p>
          )}
        </div>

        {/* Plus d'options — uniquement Prêt/Don, repliable */}
        {isDonType && (
          <div className="rounded-card border border-border bg-surface-card">
            <button
              type="button"
              onClick={() => setShowMoreOptions((v) => !v)}
              className="flex w-full items-center justify-between px-4 py-3 text-sm font-medium text-content-primary"
            >
              Plus d'options
              {showMoreOptions ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
            </button>

            {showMoreOptions && (
              <div className="flex flex-col gap-4 border-t border-border p-4">
                <div>
                  <label htmlFor="brandModel" className="mb-1 block text-xs font-medium text-content-secondary">
                    Marque / modèle (optionnel)
                  </label>
                  <input
                    id="brandModel"
                    type="text"
                    maxLength={60}
                    value={brandModel}
                    onChange={(e) => setBrandModel(e.target.value)}
                    placeholder="Ex : Bosch 18V"
                    className="w-full rounded-card border border-border bg-surface px-3 py-2 text-sm text-content-primary outline-none transition-fast focus:border-corail"
                  />
                </div>

                {loanType === 'pret' && (
                  <div>
                    <p className="mb-1 text-xs font-medium text-content-secondary">Durée du prêt</p>
                    <div className="flex flex-wrap gap-2">
                      {LOAN_DURATIONS.map((d) => (
                        <button
                          key={d.value}
                          type="button"
                          onClick={() => setLoanDuration(d.value)}
                          className={`rounded-pill border px-3 py-1.5 text-xs font-medium transition-fast ${
                            loanDuration === d.value
                              ? 'border-corail bg-corail/5 text-corail'
                              : 'border-border bg-surface text-content-primary hover:bg-surface-card'
                          }`}
                        >
                          {d.label}
                        </button>
                      ))}
                    </div>
                  </div>
                )}

                <div>
                  <p className="mb-1 text-xs font-medium text-content-secondary">Caution</p>
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={() => setDepositRequired(false)}
                      className={`rounded-pill border px-4 py-1.5 text-xs font-medium transition-fast ${
                        !depositRequired
                          ? 'border-corail bg-corail/5 text-corail'
                          : 'border-border bg-surface text-content-primary hover:bg-surface-card'
                      }`}
                    >
                      Aucune
                    </button>
                    <button
                      type="button"
                      onClick={() => setDepositRequired(true)}
                      className={`rounded-pill border px-4 py-1.5 text-xs font-medium transition-fast ${
                        depositRequired
                          ? 'border-corail bg-corail/5 text-corail'
                          : 'border-border bg-surface text-content-primary hover:bg-surface-card'
                      }`}
                    >
                      Oui
                    </button>
                  </div>
                </div>

                <div>
                  <p className="mb-1 text-xs font-medium text-content-secondary">Remise</p>
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={() => setPickupPreference('chez_moi')}
                      className={`rounded-pill border px-4 py-1.5 text-xs font-medium transition-fast ${
                        pickupPreference === 'chez_moi'
                          ? 'border-corail bg-corail/5 text-corail'
                          : 'border-border bg-surface text-content-primary hover:bg-surface-card'
                      }`}
                    >
                      Chez moi
                    </button>
                    <button
                      type="button"
                      onClick={() => setPickupPreference('je_peux_me_deplacer')}
                      className={`rounded-pill border px-4 py-1.5 text-xs font-medium transition-fast ${
                        pickupPreference === 'je_peux_me_deplacer'
                          ? 'border-corail bg-corail/5 text-corail'
                          : 'border-border bg-surface text-content-primary hover:bg-surface-card'
                      }`}
                    >
                      Je peux me déplacer
                    </button>
                  </div>
                </div>

                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-xs font-medium text-content-secondary">Contact</p>
                    <p className="text-xs text-content-secondary">
                      {showPhone ? 'Ton numéro sera visible sur cette annonce' : 'Chat Hoody uniquement'}
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => setShowPhone((v) => !v)}
                    role="switch"
                    aria-checked={showPhone}
                    className={`h-6 w-11 flex-shrink-0 rounded-pill transition-fast ${showPhone ? 'bg-vert' : 'bg-border'}`}
                  >
                    <span
                      className={`block h-5 w-5 translate-x-0.5 rounded-pill bg-white shadow-soft transition-fast ${
                        showPhone ? 'translate-x-[22px]' : ''
                      }`}
                    />
                  </button>
                </div>
                {showPhone && !myPhone && (
                  <p className="text-xs text-corail">
                    Ajoute d'abord un numéro dans ton profil pour activer cette option.
                  </p>
                )}

                <div>
                  <label htmlFor="extraNotes" className="mb-1 block text-xs font-medium text-content-secondary">
                    Précisions (optionnel)
                  </label>
                  <input
                    id="extraNotes"
                    type="text"
                    maxLength={150}
                    value={extraNotes}
                    onChange={(e) => setExtraNotes(e.target.value)}
                    placeholder="Ex : Merci de rendre l'objet propre"
                    className="w-full rounded-card border border-border bg-surface px-3 py-2 text-sm text-content-primary outline-none transition-fast focus:border-corail"
                  />
                </div>
              </div>
            )}
          </div>
        )}

        {error && <p className="text-sm text-corail">{error}</p>}

        <button
          type="submit"
          disabled={submitting}
          className="mt-2 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
        >
          {submitting ? 'Publication...' : "Publier l'annonce"}
        </button>
        <p className="text-center text-xs text-content-secondary">
          Seuls les voisins de votre quartier verront l'annonce.
        </p>
      </form>
    </div>
  );
}

MQEOF_SRC_APP_NEW_PAGE_JSX

mkdir -p "src/app/annonces/[id]"
cat > "src/app/annonces/[id]/page.jsx" << 'MQEOF_SRC_APP_ANNONCES_ID_PAGE_JSX'
// Server Component : détail d'une annonce. La policy RLS
// "posts_select_own_quartier" garantit déjà qu'on ne peut pas voir
// l'annonce d'un autre quartier.
//
// NOTE DE PORTÉE : plusieurs éléments d'inspiration (notes/avis, "% de
// prêts honorés", historique d'emprunts, réservation avec calendrier) ne
// sont pas construits — ce sont de vraies fonctionnalités à part entière,
// pas juste de la mise en page. Ce qui est affiché ici reflète toujours de
// vraies données.

import Link from 'next/link';
import Image from 'next/image';
import { notFound } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';
import { getPlaceholderImage } from '@/lib/placeholderImages';
import { getLevel } from '@/lib/levels';
import VerifiedBadge from '@/components/VerifiedBadge';
import PostHeaderActions from './PostHeaderActions';
import ContactActions from './ContactActions';

export default async function AnnonceDetailPage({ params }) {
  const { id } = await params;
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: post, error } = await supabase
    .from('posts')
    .select('id, type, title, description, availability, approx_zone, created_at, user_id, reserved, lat, lng, loan_type, item_condition, brand_model, loan_duration, deposit_required, pickup_preference, show_phone, extra_notes')
    .eq('id', id)
    .single();

  if (error || !post) {
    notFound();
  }

  const { data: authorProfile } = await supabase
    .from('profiles')
    .select('display_name, points, photo_url, photo_visible, verification_status, phone')
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
  const heroImage = photoUrls[0] || getPlaceholderImage(post.type);

  const typeInfo = getPostTypeInfo(post.type);
  const isOwnPost = post.user_id === user.id;
  const authorName = authorProfile?.display_name || 'Voisin';
  const authorInitial = authorName.charAt(0).toUpperCase();
  const level = getLevel(authorProfile?.points || 0);

  const { data: otherPosts } = await supabase
    .from('posts')
    .select('id, title, type')
    .eq('user_id', post.user_id)
    .eq('status', 'active')
    .neq('id', post.id)
    .limit(3);

  return (
    <div className="flex flex-col gap-5 pb-4">
      {/* Photo pleine largeur avec retour/favori/partage en overlay */}
      <div className="relative h-72 w-full">
        <Image src={heroImage} alt="" fill sizes="100vw" className="object-cover" priority />
        {post.reserved && (
          <span className="absolute left-3 top-14 rounded-pill bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-700 shadow-soft">
            Réservé
          </span>
        )}
        <PostHeaderActions postId={post.id} postTitle={post.title} />
      </div>

      <div className="flex flex-col gap-5 px-4">
        <div>
          <span className="inline-block rounded-pill bg-surface-card px-3 py-1 text-xs font-semibold uppercase tracking-wide text-content-secondary">
            {typeInfo.label}
          </span>
          <h1 className="mt-2 text-xl font-semibold text-content-primary">{post.title}</h1>
          {post.description && (
            <p className="mt-1 text-sm text-content-secondary">{post.description}</p>
          )}
        </div>

        {/* Auteur + niveau (factuel, pas de note/avis — pas de systeme de notation) */}
        <Link
          href={isOwnPost ? '/profile' : '#'}
          className="flex items-center gap-3 rounded-card border border-border bg-surface-card p-3"
        >
          <div className="flex h-11 w-11 flex-shrink-0 items-center justify-center overflow-hidden rounded-pill bg-corail/10 font-semibold text-corail">
            {authorProfile?.photo_visible && authorProfile?.photo_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={authorProfile.photo_url} alt="" className="h-full w-full object-cover" />
            ) : (
              authorInitial
            )}
          </div>
          <div className="min-w-0 flex-1">
            <p className="flex items-center gap-1 font-medium text-content-primary">
              {authorName}
              {authorProfile?.verification_status === 'verified' && <VerifiedBadge />}
            </p>
            <p className="text-xs text-content-secondary">{level.label}</p>
          </div>
        </Link>

        {/* Infos structurées — uniquement des champs réels */}
        {(post.availability || post.approx_zone) && (
          <div className="grid grid-cols-2 gap-3 rounded-card border border-border bg-surface-card p-4">
            {post.availability && (
              <div>
                <p className="text-xs text-content-secondary">Disponibilité</p>
                <p className="mt-0.5 text-sm font-medium text-content-primary">{post.availability}</p>
              </div>
            )}
            {post.approx_zone && (
              <div>
                <p className="text-xs text-content-secondary">Zone</p>
                <p className="mt-0.5 text-sm font-medium text-content-primary">{post.approx_zone}</p>
              </div>
            )}
            <div>
              <p className="text-xs text-content-secondary">Publié</p>
              <p className="mt-0.5 text-sm font-medium text-content-primary">
                {formatRelativeTime(post.created_at)}
              </p>
            </div>
          </div>
        )}

        {/* Détails Prêt/Don — uniquement si ce type et au moins un champ rempli */}
        {post.type === 'don' && (post.item_condition || post.brand_model || post.loan_duration || post.deposit_required || post.pickup_preference) && (
          <div className="rounded-card border border-border bg-surface-card p-4">
            <h2 className="mb-2 text-sm font-semibold text-content-primary">
              {post.loan_type === 'don' ? 'Détails du don' : 'Détails du prêt'}
            </h2>
            <div className="grid grid-cols-2 gap-3">
              {post.item_condition && (
                <div>
                  <p className="text-xs text-content-secondary">État</p>
                  <p className="mt-0.5 text-sm font-medium text-content-primary">
                    {{ neuf: 'Neuf', tres_bon: 'Très bon', bon: 'Bon', a_reparer: 'À réparer' }[post.item_condition]}
                  </p>
                </div>
              )}
              {post.brand_model && (
                <div>
                  <p className="text-xs text-content-secondary">Marque / modèle</p>
                  <p className="mt-0.5 text-sm font-medium text-content-primary">{post.brand_model}</p>
                </div>
              )}
              {post.loan_type === 'pret' && post.loan_duration && (
                <div>
                  <p className="text-xs text-content-secondary">Durée du prêt</p>
                  <p className="mt-0.5 text-sm font-medium text-content-primary">
                    {{ '1_a_3_jours': '1 à 3 jours', '1_semaine': '1 semaine', flexible: 'Flexible' }[post.loan_duration]}
                  </p>
                </div>
              )}
              {post.loan_type === 'pret' && (
                <div>
                  <p className="text-xs text-content-secondary">Caution</p>
                  <p className="mt-0.5 text-sm font-medium text-content-primary">
                    {post.deposit_required ? 'Oui' : 'Aucune'}
                  </p>
                </div>
              )}
              {post.pickup_preference && (
                <div>
                  <p className="text-xs text-content-secondary">Remise</p>
                  <p className="mt-0.5 text-sm font-medium text-content-primary">
                    {post.pickup_preference === 'chez_moi' ? 'Chez le propriétaire' : 'Peut se déplacer'}
                  </p>
                </div>
              )}
            </div>
            {post.extra_notes && (
              <p className="mt-3 border-t border-border pt-3 text-sm text-content-secondary">
                {post.extra_notes}
              </p>
            )}
            {post.show_phone && authorProfile?.phone && (
              <a
                href={`tel:${authorProfile.phone}`}
                className="mt-3 block border-t border-border pt-3 text-sm font-medium text-corail"
              >
                📞 {authorProfile.phone}
              </a>
            )}
          </div>
        )}

        {!isOwnPost && (
          <>
            {post.reserved && (
              <p className="text-center text-xs text-amber-700">
                Cette annonce a été marquée comme réservée — tu peux quand même contacter au
                cas où ça ne se concrétiserait pas.
              </p>
            )}
            <ContactActions postId={post.id} postAuthorId={post.user_id} />
          </>
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
    </div>
  );
}

MQEOF_SRC_APP_ANNONCES_ID_PAGE_JSX

echo "Formulaire mis a jour avec succes."
echo "Prochaine etape : executer la migration 037, puis git add -A && git commit -m \"formulaire pret-don detaille\" && git push"
#!/usr/bin/env bash
set -e
echo "Compression photos + accueil selon reference..."

mkdir -p "src/lib"
cat > "src/lib/compressImage.js" << 'MQEOF_SRC_LIB_COMPRESSIMAGE_JS'
// Compresse et redimensionne une image côté navigateur AVANT l'upload.
// C'est la cause la plus probable de lenteur perçue : une photo de
// smartphone moderne pèse souvent 3 à 8 Mo à 4000px de large — on la
// ramène à un poids raisonnable pour le web sans perte visible sur mobile.

export async function compressImage(file, { maxWidth = 1600, maxHeight = 1600, quality = 0.8 } = {}) {
  return new Promise((resolve, reject) => {
    const img = new window.Image();
    const objectUrl = URL.createObjectURL(file);

    img.onload = () => {
      let { width, height } = img;

      if (width > maxWidth || height > maxHeight) {
        const ratio = Math.min(maxWidth / width, maxHeight / height);
        width = Math.round(width * ratio);
        height = Math.round(height * ratio);
      }

      const canvas = document.createElement('canvas');
      canvas.width = width;
      canvas.height = height;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(img, 0, 0, width, height);

      canvas.toBlob(
        (blob) => {
          URL.revokeObjectURL(objectUrl);
          if (!blob) {
            reject(new Error('Compression échouée'));
            return;
          }
          const compressedFile = new File(
            [blob],
            file.name.replace(/\.[^.]+$/, '.jpg'),
            { type: 'image/jpeg' }
          );
          resolve(compressedFile);
        },
        'image/jpeg',
        quality
      );
    };

    img.onerror = () => {
      URL.revokeObjectURL(objectUrl);
      reject(new Error("Impossible de lire l'image"));
    };

    img.src = objectUrl;
  });
}

MQEOF_SRC_LIB_COMPRESSIMAGE_JS

mkdir -p "src/app/new"
cat > "src/app/new/page.jsx" << 'MQEOF_SRC_APP_NEW_PAGE_JSX'
'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { POST_TYPES } from '@/lib/postTypes';
import { compressImage } from '@/lib/compressImage';
import { X } from 'lucide-react';

const MAX_PHOTOS = 5;
const MAX_PHOTO_SIZE = 5 * 1024 * 1024; // 5 Mo, aligné sur la limite du bucket

export default function NewPostPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const initialType = searchParams.get('type');

  const [quartierId, setQuartierId] = useState(null);
  const [loadingProfile, setLoadingProfile] = useState(true);

  const [selectedType, setSelectedType] = useState(initialType || null);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [availability, setAvailability] = useState('');
  const [approxZone, setApproxZone] = useState('');

  const [photos, setPhotos] = useState([]); // [{ file, previewUrl }]
  const [photoError, setPhotoError] = useState('');

  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  // Verrou synchrone en plus du state React : `submitting` ne se propage
  // qu'au prochain rendu, ce qui laisse une fenêtre où un double-clic très
  // rapide peut déclencher handleSubmit deux fois avant que le bouton ne
  // soit visuellement désactivé. Une ref, elle, est lue/écrite immédiatement.
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
        // En cas d'échec de compression, on garde le fichier original plutôt
        // que de bloquer complètement l'utilisateur.
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

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');

    if (hasSubmittedRef.current) return;

    if (!title.trim()) {
      setError('Le titre est obligatoire.');
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
        status: 'active',
      })
      .select('id')
      .single();

    if (insertError || !newPost) {
      setSubmitting(false);
      hasSubmittedRef.current = false;
      setError("Une erreur est survenue lors de la publication. Réessaie.");
      return;
    }

    // Upload des photos APRÈS la création de l'annonce (on a besoin de son
    // id pour construire le chemin de stockage et satisfaire la policy RLS
    // du bucket). Un échec d'upload ne bloque pas la publication : l'annonce
    // existe déjà, on affiche juste un avertissement.
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

  // Étape 1 : choix du type (seulement si aucun type n'est déjà précisé
  // dans l'URL — cas où l'utilisateur arrive directement sur /new).
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

      <div className="mb-6 flex items-center gap-2">
        <span className="flex h-10 w-10 items-center justify-center rounded-pill bg-surface-card text-content-primary">
          {typeInfo && <typeInfo.icon size={20} />}
        </span>
        <h1 className="text-xl font-semibold text-content-primary">{typeInfo?.label}</h1>
      </div>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
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
          <label htmlFor="description" className="mb-1 block text-sm font-medium text-content-primary">
            Description
          </label>
          <textarea
            id="description"
            rows={4}
            maxLength={1000}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Donne quelques détails utiles..."
            className="w-full resize-none rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
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
          <label htmlFor="availability" className="mb-1 block text-sm font-medium text-content-primary">
            Disponibilité <span className="text-content-secondary">(optionnel)</span>
          </label>
          <input
            id="availability"
            type="text"
            maxLength={100}
            value={availability}
            onChange={(e) => setAvailability(e.target.value)}
            placeholder="Ex : le week-end, en soirée..."
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        <div>
          <label htmlFor="approxZone" className="mb-1 block text-sm font-medium text-content-primary">
            Zone approximative <span className="text-content-secondary">(optionnel)</span>
          </label>
          <input
            id="approxZone"
            type="text"
            maxLength={100}
            value={approxZone}
            onChange={(e) => setApproxZone(e.target.value)}
            placeholder="Ex : proche de la mairie"
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        {error && <p className="text-sm text-corail">{error}</p>}

        <button
          type="submit"
          disabled={submitting}
          className="mt-2 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
        >
          {submitting ? 'Publication...' : 'Publier gratuitement'}
        </button>
      </form>
    </div>
  );
}

MQEOF_SRC_APP_NEW_PAGE_JSX

mkdir -p "src/app/profile/edit"
cat > "src/app/profile/edit/page.jsx" << 'MQEOF_SRC_APP_PROFILE_EDIT_PAGE_JSX'
'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { compressImage } from '@/lib/compressImage';

const MAX_AVATAR_SIZE = 2 * 1024 * 1024;
const PRESET_AVATARS = [
  '/avatars/preset-1.png',
  '/avatars/preset-2.png',
  '/avatars/preset-3.png',
  '/avatars/preset-4.png',
  '/avatars/preset-5.png',
  '/avatars/preset-6.png',
];

export default function EditProfilePage() {
  const router = useRouter();
  const [userId, setUserId] = useState(null);
  const [loading, setLoading] = useState(true);

  const [displayName, setDisplayName] = useState('');
  const [bio, setBio] = useState('');
  const [phone, setPhone] = useState('');
  const [photoUrl, setPhotoUrl] = useState(null);
  const [photoVisible, setPhotoVisible] = useState(true);
  const [phoneVisible, setPhoneVisible] = useState(false);

  const [avatarFile, setAvatarFile] = useState(null);
  const [avatarPreview, setAvatarPreview] = useState(null);
  const [showPresets, setShowPresets] = useState(false);
  const [photoError, setPhotoError] = useState('');

  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  useEffect(() => {
    async function load() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        router.push('/login');
        return;
      }
      setUserId(user.id);

      const { data: profile } = await supabase
        .from('profiles')
        .select('display_name, bio, phone, photo_url, photo_visible, phone_visible')
        .eq('user_id', user.id)
        .single();

      setDisplayName(profile?.display_name || '');
      setBio(profile?.bio || '');
      setPhone(profile?.phone || '');
      setPhotoUrl(profile?.photo_url || null);
      setPhotoVisible(profile?.photo_visible ?? true);
      setPhoneVisible(profile?.phone_visible ?? false);
      setLoading(false);
    }
    load();
  }, [router]);

  async function handleAvatarSelect(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setPhotoError('');

    const accepted = ['image/jpeg', 'image/png', 'image/webp'];
    if (!accepted.includes(file.type)) {
      setPhotoError('Format accepté : JPEG, PNG ou WebP.');
      return;
    }
    if (file.size > MAX_AVATAR_SIZE) {
      setPhotoError('La photo doit faire moins de 2 Mo.');
      return;
    }

    try {
      const compressed = await compressImage(file, { maxWidth: 600, maxHeight: 600 });
      setAvatarFile(compressed);
      setAvatarPreview(URL.createObjectURL(compressed));
    } catch {
      setAvatarFile(file);
      setAvatarPreview(URL.createObjectURL(file));
    }
    setShowPresets(false);
  }

  function handleChoosePreset(presetPath) {
    setAvatarFile(null);
    setAvatarPreview(null);
    setPhotoUrl(presetPath);
    setShowPresets(false);
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setSuccess(false);

    if (!displayName.trim()) {
      setError('Le prénom est obligatoire.');
      return;
    }

    setSubmitting(true);

    let newPhotoUrl = photoUrl;

    if (avatarFile) {
      const ext = avatarFile.name.split('.').pop();
      const path = `${userId}/${crypto.randomUUID()}.${ext}`;
      const { error: uploadError } = await supabase.storage.from('avatars').upload(path, avatarFile);

      if (uploadError) {
        setSubmitting(false);
        setError("Impossible d'envoyer la photo. Réessaie.");
        return;
      }

      newPhotoUrl = supabase.storage.from('avatars').getPublicUrl(path).data.publicUrl;
    }

    const { error: updateError } = await supabase
      .from('profiles')
      .update({
        display_name: displayName.trim(),
        bio: bio.trim() || null,
        phone: phone.trim() || null,
        photo_url: newPhotoUrl,
        photo_visible: photoVisible,
        phone_visible: phoneVisible,
      })
      .eq('user_id', userId);

    setSubmitting(false);

    if (updateError) {
      setError('Une erreur est survenue. Réessaie.');
      return;
    }

    setSuccess(true);
    setTimeout(() => router.push('/profile'), 1000);
  }

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="skeleton h-4 w-40" />
      </div>
    );
  }

  const initial = (displayName || '?').charAt(0).toUpperCase();
  const currentAvatar = avatarPreview || photoUrl;

  return (
    <div className="p-6">
      <h1 className="mb-6 text-xl font-semibold text-content-primary">Modifier mon profil</h1>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <div className="flex flex-col items-center gap-2">
          {currentAvatar ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={currentAvatar} alt="" className="h-24 w-24 rounded-pill object-cover" />
          ) : (
            <div className="flex h-24 w-24 items-center justify-center rounded-pill bg-corail/10 text-2xl font-semibold text-corail">
              {initial}
            </div>
          )}

          <div className="flex gap-3">
            <label className="cursor-pointer text-xs font-medium text-corail">
              Importer une photo
              <input
                type="file"
                accept="image/jpeg,image/png,image/webp"
                onChange={handleAvatarSelect}
                className="hidden"
              />
            </label>
            <span className="text-xs text-content-secondary">·</span>
            <button
              type="button"
              onClick={() => setShowPresets((v) => !v)}
              className="text-xs font-medium text-corail"
            >
              Choisir un avatar
            </button>
          </div>
          {photoError && <p className="text-xs text-corail">{photoError}</p>}

          {showPresets && (
            <div className="mt-2 grid grid-cols-6 gap-2">
              {PRESET_AVATARS.map((preset) => (
                <button
                  key={preset}
                  type="button"
                  onClick={() => handleChoosePreset(preset)}
                  className="overflow-hidden rounded-pill transition-fast hover:scale-105"
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={preset} alt="" className="h-10 w-10" />
                </button>
              ))}
            </div>
          )}

          <p className="mt-1 text-center text-xs text-content-secondary">
            Pas envie de mettre ta tête ? Choisis un avatar illustré à la place.
          </p>
        </div>

        <div>
          <label htmlFor="displayName" className="mb-1 block text-sm font-medium text-content-primary">
            Prénom affiché
          </label>
          <input
            id="displayName"
            type="text"
            required
            maxLength={50}
            value={displayName}
            onChange={(e) => setDisplayName(e.target.value)}
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        <div>
          <label htmlFor="bio" className="mb-1 block text-sm font-medium text-content-primary">
            Bio <span className="text-content-secondary">(optionnel)</span>
          </label>
          <textarea
            id="bio"
            rows={3}
            maxLength={300}
            value={bio}
            onChange={(e) => setBio(e.target.value)}
            placeholder="Quelques mots sur toi..."
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

        {/* Préférences de confidentialité — section 32 du prompt maître */}
        <div className="rounded-card border border-border bg-surface-card p-4">
          <h2 className="mb-3 text-sm font-semibold text-content-primary">Confidentialité</h2>

          <label className="flex items-center justify-between py-2">
            <div>
              <p className="text-sm text-content-primary">Photo visible par mes voisins</p>
              <p className="text-xs text-content-secondary">
                Sinon, une icône générique s'affiche à ta place.
              </p>
            </div>
            <input
              type="checkbox"
              checked={photoVisible}
              onChange={(e) => setPhotoVisible(e.target.checked)}
              className="h-5 w-5 accent-corail"
            />
          </label>

          <label className="flex items-center justify-between border-t border-border py-2 pt-3">
            <div>
              <p className="text-sm text-content-primary">Téléphone visible par mes voisins</p>
              <p className="text-xs text-content-secondary">
                Désactivé par défaut. Aucune fonctionnalité actuelle ne l'affiche encore
                publiquement, ce réglage prépare une future mise en relation directe.
              </p>
            </div>
            <input
              type="checkbox"
              checked={phoneVisible}
              onChange={(e) => setPhoneVisible(e.target.checked)}
              className="h-5 w-5 flex-shrink-0 accent-corail"
            />
          </label>
        </div>

        {error && <p className="text-sm text-corail">{error}</p>}
        {success && <p className="text-sm text-vert">✓ Profil mis à jour</p>}

        <button
          type="submit"
          disabled={submitting}
          className="mt-2 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
        >
          {submitting ? 'Enregistrement...' : 'Enregistrer'}
        </button>
      </form>
    </div>
  );
}

MQEOF_SRC_APP_PROFILE_EDIT_PAGE_JSX

mkdir -p "src/app/commerces/new"
cat > "src/app/commerces/new/page.jsx" << 'MQEOF_SRC_APP_COMMERCES_NEW_PAGE_JSX'
'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { PLACE_CATEGORIES } from '@/lib/placeCategories';
import { compressImage } from '@/lib/compressImage';

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
      setPhotoError('La photo doit faire moins de 5 Mo.');
      return;
    }

    try {
      const compressed = await compressImage(file);
      setPhotoFile(compressed);
      setPhotoPreview(URL.createObjectURL(compressed));
    } catch {
      setPhotoFile(file);
      setPhotoPreview(URL.createObjectURL(file));
    }
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

MQEOF_SRC_APP_ACTIVITES_NEW_PAGE_JSX

mkdir -p "src/components"
cat > "src/components/FavoriteHeartButton.jsx" << 'MQEOF_SRC_COMPONENTS_FAVORITEHEARTBUTTON_JSX'
'use client';

import { useEffect, useState } from 'react';
import { Heart } from 'lucide-react';
import { supabase } from '@/lib/supabaseClient';

export default function FavoriteHeartButton({ postId }) {
  const [favorited, setFavorited] = useState(false);
  const [userId, setUserId] = useState(null);

  useEffect(() => {
    async function load() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;
      setUserId(user.id);

      const { data } = await supabase
        .from('favorites')
        .select('post_id')
        .eq('user_id', user.id)
        .eq('post_id', postId)
        .maybeSingle();
      setFavorited(!!data);
    }
    load();
  }, [postId]);

  async function handleClick(e) {
    e.preventDefault();
    e.stopPropagation();
    if (!userId) return;

    if (favorited) {
      await supabase.from('favorites').delete().eq('user_id', userId).eq('post_id', postId);
      setFavorited(false);
    } else {
      await supabase.from('favorites').insert({ user_id: userId, post_id: postId });
      setFavorited(true);
    }
  }

  return (
    <button
      onClick={handleClick}
      aria-label={favorited ? 'Retirer des favoris' : 'Ajouter aux favoris'}
      className="absolute right-2 top-2 flex h-7 w-7 items-center justify-center rounded-pill bg-white/90 shadow-soft"
    >
      <Heart size={14} fill={favorited ? '#FF5A5F' : 'none'} className={favorited ? 'text-corail' : 'text-content-primary'} />
    </button>
  );
}

MQEOF_SRC_COMPONENTS_FAVORITEHEARTBUTTON_JSX

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
import { Search, Users, Store, MessageCircle } from 'lucide-react';
import { createClient } from '@/lib/supabase/server';
import { POST_TYPES, getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';
import { formatEventDate } from '@/lib/eventCategories';
import { getPlaceholderImage } from '@/lib/placeholderImages';
import AvatarStack from '@/components/AvatarStack';
import FavoriteHeartButton from '@/components/FavoriteHeartButton';

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
        .limit(3),
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

  const [{ data: authors }, { data: images }, { data: attendeeRows }, { data: convCounts }] = await Promise.all([
    relevantUserIds.length > 0
      ? supabase.from('profiles').select('user_id, display_name, photo_url, photo_visible').in('user_id', relevantUserIds)
      : Promise.resolve({ data: [] }),
    feedPostIds.length > 0
      ? supabase.from('post_images').select('post_id, storage_path, position').in('post_id', feedPostIds).order('position', { ascending: true })
      : Promise.resolve({ data: [] }),
    eventIds.length > 0
      ? supabase.from('event_attendees').select('event_id, user_id').in('event_id', eventIds)
      : Promise.resolve({ data: [] }),
    feedPostIds.length > 0
      ? supabase.rpc('get_conversation_counts', { p_post_ids: feedPostIds })
      : Promise.resolve({ data: [] }),
  ]);

  const authorName = Object.fromEntries((authors || []).map((a) => [a.user_id, a.display_name]));
  const authorPhoto = Object.fromEntries((authors || []).map((a) => [a.user_id, a]));
  const conversationCounts = Object.fromEntries((convCounts || []).map((c) => [c.post_id, c.count]));

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

      {/* Catégories — vraies illustrations, grille 3 colonnes (2 lignes, pas de scroll) */}
      <div className="mt-5 grid grid-cols-3 gap-2.5">
        {POST_TYPES.map((cat) => (
          <Link
            key={cat.type}
            href={`/annonces?type=${cat.type}`}
            className="overflow-hidden rounded-card shadow-soft transition-fast active:scale-95"
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={`/categories/${cat.type}.png`}
              alt={cat.label}
              className="aspect-square w-full object-cover"
            />
          </Link>
        ))}
      </div>

      {/* Alerte la plus récente */}
      {featuredAlert && (
        <Link
          href={`/annonces/${featuredAlert.id}`}
          className="mt-5 flex items-center gap-3 rounded-card bg-corail/10 p-4 shadow-soft transition-fast hover:shadow-none"
        >
          <div className="h-10 w-10 flex-shrink-0 overflow-hidden rounded-pill">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/categories/alerte.png" alt="" className="h-full w-full object-cover" />
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

      {/* Près de chez toi — grille de 3, triée par date de publication */}
      {feed.length > 0 && (
        <section className="mt-7">
          <div className="mb-3 flex items-baseline justify-between">
            <h2 className="text-base font-semibold text-content-primary">Près de chez toi</h2>
            <Link href="/annonces" className="text-xs text-content-secondary">
              Voir tout
            </Link>
          </div>

          <div className="grid grid-cols-2 gap-3">
            {feed.map((post) => {
              const thumbnail = thumbnailByPost[post.id] || getPlaceholderImage(post.type);
              const typeInfo = getPostTypeInfo(post.type);
              const author = authorPhoto[post.user_id];
              const msgCount = conversationCounts[post.id] || 0;

              return (
                <Link key={post.id} href={`/annonces/${post.id}`}>
                  <div className="relative h-24 w-full overflow-hidden rounded-card bg-surface-card shadow-soft">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={thumbnail} alt="" className="h-full w-full object-cover" />
                    <FavoriteHeartButton postId={post.id} />
                  </div>

                  <span className="mt-2 inline-block rounded-pill bg-surface-card px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-content-secondary">
                    {typeInfo.label}
                  </span>

                  <p className="mt-1 line-clamp-2 text-sm font-medium text-content-primary">
                    {post.title}
                  </p>

                  <div className="mt-1 flex items-center gap-1.5">
                    <div className="flex h-[18px] w-[18px] flex-shrink-0 items-center justify-center overflow-hidden rounded-pill bg-corail/10 text-[8px] font-semibold text-corail">
                      {author?.photo_visible && author?.photo_url ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={author.photo_url} alt="" className="h-full w-full object-cover" />
                      ) : (
                        (author?.display_name || '?').charAt(0).toUpperCase()
                      )}
                    </div>
                    <span className="truncate text-[11px] text-content-secondary">
                      {author?.display_name || 'Voisin'}
                    </span>
                  </div>

                  <div className="mt-1 flex items-center justify-between text-[11px] text-content-secondary">
                    <span>{formatRelativeTime(post.created_at)}</span>
                    {msgCount > 0 && (
                      <span className="flex items-center gap-0.5">
                        <MessageCircle size={11} />
                        {msgCount}
                      </span>
                    )}
                  </div>
                </Link>
              );
            })}
          </div>

          <Link
            href="/annonces"
            className="mt-4 block w-full rounded-pill border border-border py-2.5 text-center text-sm font-medium text-content-primary transition-fast hover:border-content-secondary"
          >
            Voir plus
          </Link>
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
            src="/placeholders/voisins-card.jpg"
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
            src="/placeholders/commerce-card.jpg"
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

echo "Mise a jour appliquee avec succes."
echo "Prochaine etape : executer les migrations 027, puis git add -A && git commit -m \"perf: compression photos + accueil grille 3\" && git push"
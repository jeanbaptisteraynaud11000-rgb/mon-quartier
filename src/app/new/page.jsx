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


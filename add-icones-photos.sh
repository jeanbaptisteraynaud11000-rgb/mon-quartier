#!/usr/bin/env bash
set -e
echo "Icones Lucide + upload photos..."

mkdir -p "src/lib"
cat > "src/lib/postTypes.js" << 'MQEOF_SRC_LIB_POSTTYPES_JS'
// Constantes partagées entre /annonces, /new et /annonces/[id] pour garder
// les libellés et emojis cohérents partout dans l'app.

import { Gift, Handshake, Car, Search, AlertTriangle } from 'lucide-react';

export const POST_TYPES = [
  { type: 'don', label: 'Prêt / Don', icon: Gift },
  { type: 'entraide', label: 'Entraide', icon: Handshake },
  { type: 'covoiturage', label: 'Covoiturage', icon: Car },
  { type: 'cherche', label: 'Je cherche', icon: Search },
  { type: 'alerte', label: 'Alerte quartier', icon: AlertTriangle },
];

export function getPostTypeInfo(type) {
  return POST_TYPES.find((t) => t.type === type) || { label: type, icon: Search };
}

// Formatage relatif simple en français, sans dépendance externe.
export function formatRelativeTime(dateString) {
  const date = new Date(dateString);
  const diffMs = Date.now() - date.getTime();
  const diffMin = Math.floor(diffMs / 60000);

  if (diffMin < 1) return "à l'instant";
  if (diffMin < 60) return `il y a ${diffMin} min`;
  const diffH = Math.floor(diffMin / 60);
  if (diffH < 24) return `il y a ${diffH} h`;
  const diffJ = Math.floor(diffH / 24);
  if (diffJ < 7) return `il y a ${diffJ} j`;
  return date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' });
}

MQEOF_SRC_LIB_POSTTYPES_JS

mkdir -p "src/components/layout"
cat > "src/components/layout/CreateSheet.jsx" << 'MQEOF_SRC_COMPONENTS_LAYOUT_CREATESHEET_JSX'
'use client';

import { useEffect } from 'react';
import Link from 'next/link';
import { X } from 'lucide-react';
import { POST_TYPES } from '@/lib/postTypes';

export default function CreateSheet({ open, onClose }) {
  // Empêche le scroll du fond quand la sheet est ouverte
  useEffect(() => {
    if (open) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = '';
    }
    return () => {
      document.body.style.overflow = '';
    };
  }, [open]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50" role="dialog" aria-modal="true" aria-label="Créer une publication">
      {/* Overlay */}
      <button
        aria-label="Fermer"
        onClick={onClose}
        className="absolute inset-0 bg-black/40 transition-fast"
      />

      {/* Sheet */}
      <div className="safe-bottom absolute bottom-0 left-0 right-0 animate-in slide-in-from-bottom rounded-t-sheet bg-surface p-6 shadow-sheet">
        <div className="mx-auto mb-4 h-1 w-10 rounded-pill bg-border" />

        <div className="mb-5 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-content-primary">
            Que souhaitez-vous partager ?
          </h2>
          <button
            aria-label="Fermer"
            onClick={onClose}
            className="flex h-tap w-tap items-center justify-center rounded-pill text-content-secondary hover:bg-surface-card"
          >
            <X size={20} />
          </button>
        </div>

        <div className="flex flex-col gap-2">
          {POST_TYPES.map((option) => {
            const Icon = option.icon;
            return (
              <Link
                key={option.type}
                href={`/new?type=${option.type}`}
                onClick={onClose}
                className="flex items-center gap-4 rounded-card bg-surface-card px-4 py-4 transition-fast hover:bg-border/60 active:scale-[0.98]"
              >
                <span className="flex h-10 w-10 items-center justify-center rounded-pill bg-surface text-content-primary" aria-hidden="true">
                  <Icon size={20} />
                </span>
                <span className="text-base font-medium text-content-primary">
                  {option.label}
                </span>
              </Link>
            );
          })}
        </div>
      </div>
    </div>
  );
}

MQEOF_SRC_COMPONENTS_LAYOUT_CREATESHEET_JSX

mkdir -p "src/app/new"
cat > "src/app/new/page.jsx" << 'MQEOF_SRC_APP_NEW_PAGE_JSX'
'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { POST_TYPES } from '@/lib/postTypes';
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

  function handlePhotoSelect(e) {
    const files = Array.from(e.target.files || []);
    setPhotoError('');

    const accepted = ['image/jpeg', 'image/png', 'image/webp'];
    const valid = [];

    for (const file of files) {
      if (!accepted.includes(file.type)) {
        setPhotoError('Seules les images JPEG, PNG ou WebP sont acceptées.');
        continue;
      }
      if (file.size > MAX_PHOTO_SIZE) {
        setPhotoError('Chaque photo doit faire moins de 5 Mo.');
        continue;
      }
      valid.push(file);
    }

    setPhotos((prev) => {
      const combined = [...prev, ...valid.map((file) => ({ file, previewUrl: URL.createObjectURL(file) }))];
      if (combined.length > MAX_PHOTOS) {
        setPhotoError(`Maximum ${MAX_PHOTOS} photos.`);
        return combined.slice(0, MAX_PHOTOS);
      }
      return combined;
    });

    e.target.value = ''; // permet de re-sélectionner le même fichier après suppression
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

mkdir -p "src/app/annonces"
cat > "src/app/annonces/page.jsx" << 'MQEOF_SRC_APP_ANNONCES_PAGE_JSX'
// Server Component : liste des annonces du quartier de l'utilisateur,
// filtrable par type via ?type=don|entraide|covoiturage|cherche|alerte.

import Link from 'next/link';
import Image from 'next/image';
import { createClient } from '@/lib/supabase/server';
import { POST_TYPES, getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';

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
          const typeInfo = getPostTypeInfo(post.type);
          const Icon = typeInfo.icon;
          const thumbnail = thumbnailByPost[post.id];
          return (
            <Link
              key={post.id}
              href={`/annonces/${post.id}`}
              className="flex gap-3 rounded-card border border-border bg-surface-card p-4 shadow-soft transition-fast hover:bg-border/30 active:scale-[0.99]"
            >
              {thumbnail ? (
                <div className="relative h-14 w-14 flex-shrink-0 overflow-hidden rounded-card bg-surface">
                  <Image src={thumbnail} alt="" fill sizes="56px" className="object-cover" />
                </div>
              ) : (
                <div className="flex h-14 w-14 flex-shrink-0 items-center justify-center rounded-card bg-surface text-content-primary">
                  <Icon size={22} />
                </div>
              )}
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
    .select('display_name')
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

      {photoUrls.length > 0 && (
        <div className="-mx-4 flex gap-2 overflow-x-auto px-4">
          {photoUrls.map((url, i) => (
            <div key={i} className="relative h-56 w-full flex-shrink-0 overflow-hidden rounded-card bg-surface-card">
              <Image src={url} alt="" fill sizes="100vw" className="object-cover" />
            </div>
          ))}
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
          <span>{authorName}</span>
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

mkdir -p "src/app/annonces/[id]/edit"
cat > "src/app/annonces/[id]/edit/page.jsx" << 'MQEOF_SRC_APP_ANNONCES_ID_EDIT_PAGE_JSX'
'use client';

import { useEffect, useState } from 'react';
import { useRouter, useParams } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { getPostTypeInfo } from '@/lib/postTypes';

export default function EditPostPage() {
  const router = useRouter();
  const { id } = useParams();

  const [loading, setLoading] = useState(true);
  const [notFoundOrForbidden, setNotFoundOrForbidden] = useState(false);
  const [type, setType] = useState(null);

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [availability, setAvailability] = useState('');
  const [approxZone, setApproxZone] = useState('');

  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    async function loadPost() {
      const { data: { user } } = await supabase.auth.getUser();

      const { data: post, error: fetchError } = await supabase
        .from('posts')
        .select('id, type, title, description, availability, approx_zone, user_id')
        .eq('id', id)
        .single();

      // La policy RLS empêche déjà de lire l'annonce d'un autre quartier,
      // mais on vérifie aussi explicitement que c'est bien SON annonce —
      // un admin pourrait techniquement la voir sans en être l'auteur.
      if (fetchError || !post || post.user_id !== user.id) {
        setNotFoundOrForbidden(true);
        setLoading(false);
        return;
      }

      setType(post.type);
      setTitle(post.title);
      setDescription(post.description || '');
      setAvailability(post.availability || '');
      setApproxZone(post.approx_zone || '');
      setLoading(false);
    }
    loadPost();
  }, [id]);

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');

    if (!title.trim()) {
      setError('Le titre est obligatoire.');
      return;
    }

    setSubmitting(true);

    const { error: updateError } = await supabase
      .from('posts')
      .update({
        title: title.trim(),
        description: description.trim() || null,
        availability: availability.trim() || null,
        approx_zone: approxZone.trim() || null,
      })
      .eq('id', id);

    setSubmitting(false);

    if (updateError) {
      setError("Une erreur est survenue. Réessaie.");
      return;
    }

    router.push(`/annonces/${id}`);
  }

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="skeleton h-4 w-40" />
      </div>
    );
  }

  if (notFoundOrForbidden) {
    return (
      <div className="p-6 text-center">
        <p className="text-content-primary">
          Cette annonce n'existe pas ou tu n'as pas le droit de la modifier.
        </p>
      </div>
    );
  }

  const typeInfo = getPostTypeInfo(type);

  return (
    <div className="p-6">
      <div className="mb-6 flex items-center gap-2">
        <span className="flex h-10 w-10 items-center justify-center rounded-pill bg-surface-card text-content-primary">
          {typeInfo && <typeInfo.icon size={20} />}
        </span>
        <h1 className="text-xl font-semibold text-content-primary">Modifier l'annonce</h1>
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
            className="w-full resize-none rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
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
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        {error && <p className="text-sm text-corail">{error}</p>}

        <button
          type="submit"
          disabled={submitting}
          className="mt-2 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
        >
          {submitting ? 'Enregistrement...' : 'Enregistrer les modifications'}
        </button>
      </form>
    </div>
  );
}

MQEOF_SRC_APP_ANNONCES_ID_EDIT_PAGE_JSX

mkdir -p "src/app/mes-annonces"
cat > "src/app/mes-annonces/page.jsx" << 'MQEOF_SRC_APP_MES-ANNONCES_PAGE_JSX'
'use client';

import { useEffect, useState, useCallback } from 'react';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';
import { getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';

const TABS = [
  { key: 'active', label: 'Actives' },
  { key: 'draft', label: 'Brouillons' },
  { key: 'completed', label: 'Terminées' },
];

export default function MesAnnoncesPage() {
  const [activeTab, setActiveTab] = useState('active');
  const [posts, setPosts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [actionError, setActionError] = useState('');

  const loadPosts = useCallback(async (status) => {
    setLoading(true);
    const { data: { user } } = await supabase.auth.getUser();

    // Les brouillons ne sont pas encore implémentés (nécessite une table
    // dédiée, voir prompt maître section 26) — on ne fait pas de requête
    // inutile et on affiche directement l'empty state.
    if (status === 'draft') {
      setPosts([]);
      setLoading(false);
      return;
    }

    const { data } = await supabase
      .from('posts')
      .select('id, type, title, description, status, created_at')
      .eq('user_id', user.id)
      .eq('status', status)
      .order('created_at', { ascending: false });

    setPosts(data || []);
    setLoading(false);
  }, []);

  useEffect(() => {
    loadPosts(activeTab);
  }, [activeTab, loadPosts]);

  async function handleMarkCompleted(postId) {
    setActionError('');
    const { error } = await supabase.from('posts').update({ status: 'completed' }).eq('id', postId);
    if (error) {
      setActionError("Impossible de mettre à jour cette annonce.");
      return;
    }
    loadPosts(activeTab);
  }

  async function handleRepublish(postId) {
    setActionError('');
    const { error } = await supabase.from('posts').update({ status: 'active' }).eq('id', postId);
    if (error) {
      setActionError("Impossible de republier cette annonce.");
      return;
    }
    loadPosts(activeTab);
  }

  async function handleDelete(postId) {
    if (!confirm('Supprimer définitivement cette annonce ?')) return;
    setActionError('');
    const { error } = await supabase.from('posts').update({ status: 'deleted' }).eq('id', postId);
    if (error) {
      setActionError("Impossible de supprimer cette annonce.");
      return;
    }
    loadPosts(activeTab);
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="flex gap-2">
        {TABS.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            className={`flex-1 rounded-pill border px-3 py-2 text-sm font-medium transition-fast ${
              activeTab === tab.key
                ? 'border-corail bg-corail text-white'
                : 'border-border bg-surface text-content-primary hover:bg-surface-card'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {actionError && <p className="text-sm text-corail">{actionError}</p>}

      {loading && <div className="skeleton h-20 w-full" />}

      {!loading && activeTab === 'draft' && (
        <div className="rounded-card border border-border bg-surface-card p-6 text-center text-sm text-content-secondary">
          Les brouillons arrivent dans un prochain chantier.
        </div>
      )}

      {!loading && activeTab !== 'draft' && posts.length === 0 && (
        <div className="rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">
            {activeTab === 'active' ? "Tu n'as pas d'annonce active." : 'Aucune annonce terminée.'}
          </p>
          {activeTab === 'active' && (
            <Link
              href="/new"
              className="mt-4 inline-block h-tap rounded-pill bg-corail px-6 py-3 font-medium text-white transition-fast hover:bg-corail-hover"
            >
              Publier une annonce
            </Link>
          )}
        </div>
      )}

      <div className="flex flex-col gap-3">
        {posts.map((post) => {
          const typeInfo = getPostTypeInfo(post.type);
          const Icon = typeInfo.icon;
          return (
            <div key={post.id} className="rounded-card border border-border bg-surface-card p-4">
              <Link href={`/annonces/${post.id}`} className="block">
                <div className="flex items-center gap-2 text-sm text-content-secondary">
                  <Icon size={14} />
                  <span>{typeInfo.label}</span>
                  <span>·</span>
                  <span>{formatRelativeTime(post.created_at)}</span>
                </div>
                <p className="mt-1 font-semibold text-content-primary">{post.title}</p>
              </Link>

              <div className="mt-3 flex flex-wrap gap-2">
                <Link
                  href={`/annonces/${post.id}/edit`}
                  className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-content-primary transition-fast hover:bg-surface"
                >
                  Modifier
                </Link>

                {activeTab === 'active' && (
                  <button
                    onClick={() => handleMarkCompleted(post.id)}
                    className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-content-primary transition-fast hover:bg-surface"
                  >
                    Marquer terminé
                  </button>
                )}

                {activeTab === 'completed' && (
                  <button
                    onClick={() => handleRepublish(post.id)}
                    className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-content-primary transition-fast hover:bg-surface"
                  >
                    Republier
                  </button>
                )}

                <button
                  onClick={() => handleDelete(post.id)}
                  className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-corail transition-fast hover:bg-surface"
                >
                  Supprimer
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

MQEOF_SRC_APP_MES-ANNONCES_PAGE_JSX

mkdir -p "src/app/admin/posts"
cat > "src/app/admin/posts/PostsAdminList.jsx" << 'MQEOF_SRC_APP_ADMIN_POSTS_POSTSADMINLIST_JSX'
'use client';

import { useEffect, useState, useCallback } from 'react';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';
import { getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';

// NOTE : pas de filtre explicite par quartier_id ici — la policy RLS
// "posts_select_own_quartier" s'en charge déjà (un quartier_admin ne voit
// que les annonces de son quartier, un super_admin les voit toutes).

export default function PostsAdminList() {
  const [posts, setPosts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('active');

  const load = useCallback(async (status) => {
    setLoading(true);
    const { data } = await supabase
      .from('posts')
      .select('id, type, title, user_id, status, created_at')
      .eq('status', status)
      .order('created_at', { ascending: false })
      .limit(50);
    setPosts(data || []);
    setLoading(false);
  }, []);

  useEffect(() => {
    load(filter);
  }, [filter, load]);

  async function handleHide(postId) {
    const reason = prompt('Motif du masquage (optionnel) :') || null;
    const { error } = await supabase.rpc('hide_post', { p_post_id: postId, p_reason: reason });
    if (!error) load(filter);
  }

  async function handleRestore(postId) {
    const { error } = await supabase.rpc('restore_post', { p_post_id: postId });
    if (!error) load(filter);
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <Link href="/admin" className="text-sm text-content-secondary">
        ← Administration
      </Link>
      <h1 className="text-xl font-semibold text-content-primary">Annonces</h1>

      <div className="flex gap-2">
        {['active', 'hidden'].map((s) => (
          <button
            key={s}
            onClick={() => setFilter(s)}
            className={`rounded-pill border px-3 py-1.5 text-sm font-medium transition-fast ${
              filter === s
                ? 'border-corail bg-corail text-white'
                : 'border-border bg-surface text-content-primary'
            }`}
          >
            {s === 'active' ? 'Actives' : 'Masquées'}
          </button>
        ))}
      </div>

      {loading && <div className="skeleton h-16 w-full" />}

      {!loading && posts.length === 0 && (
        <p className="text-sm text-content-secondary">Aucune annonce dans cette catégorie.</p>
      )}

      <div className="flex flex-col gap-2">
        {posts.map((post) => {
          const typeInfo = getPostTypeInfo(post.type);
          const Icon = typeInfo.icon;
          return (
            <div key={post.id} className="rounded-card border border-border bg-surface-card p-4">
              <div className="flex items-center justify-between text-sm text-content-secondary">
                <span className="flex items-center gap-1.5"><Icon size={14} /> {typeInfo.label}</span>
                <span>{formatRelativeTime(post.created_at)}</span>
              </div>
              <Link href={`/annonces/${post.id}`} className="mt-1 block font-medium text-content-primary">
                {post.title}
              </Link>

              <div className="mt-3">
                {post.status === 'active' ? (
                  <button
                    onClick={() => handleHide(post.id)}
                    className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-corail hover:bg-surface"
                  >
                    Masquer
                  </button>
                ) : (
                  <button
                    onClick={() => handleRestore(post.id)}
                    className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-content-primary hover:bg-surface"
                  >
                    Restaurer
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

MQEOF_SRC_APP_ADMIN_POSTS_POSTSADMINLIST_JSX

mkdir -p "src/app"
cat > "src/app/page.jsx" << 'MQEOF_SRC_APP_PAGE_JSX'
// Page d'accueil — Server Component.
//
// Parti pris UX : on montre un vrai fil d'activité récente du quartier
// (comme un feed), mais SANS mécaniques de réseau social classique — pas
// de likes, pas de compteurs de popularité, pas de followers (section 80
// du prompt maître). Le feed sert un seul but : "voici ce qui se passe
// concrètement autour de toi", pas "voici qui est populaire".

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { POST_TYPES, getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';

const CATEGORY_COLORS = {
  don: 'bg-corail/10 text-corail',
  entraide: 'bg-vert/10 text-vert',
  covoiturage: 'bg-corail/10 text-corail',
  cherche: 'bg-vert/10 text-vert',
  alerte: 'bg-amber-100 text-amber-700',
};

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
  const quartierName = profile.quartiers?.name ?? 'ton quartier';
  const firstName = profile.display_name?.split(' ')[0] || null;

  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);

  const [neighborsCount, postsTodayCount, entraideCount, feedResult] = await Promise.all([
    supabase
      .from('profiles')
      .select('*', { count: 'exact', head: true })
      .eq('quartier_id', quartierId),
    supabase
      .from('posts')
      .select('*', { count: 'exact', head: true })
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .gte('created_at', startOfToday.toISOString()),
    supabase
      .from('posts')
      .select('*', { count: 'exact', head: true })
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .eq('type', 'entraide'),
    supabase
      .from('posts')
      .select('id, type, title, description, created_at, user_id')
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .order('created_at', { ascending: false })
      .limit(8),
  ]);

  const feed = feedResult.data || [];

  // Requête séparée pour les auteurs (pas de FK directe posts → profiles).
  let authorNames = {};
  if (feed.length > 0) {
    const userIds = [...new Set(feed.map((p) => p.user_id))];
    const { data: authors } = await supabase
      .from('profiles')
      .select('user_id, display_name')
      .in('user_id', userIds);
    authorNames = Object.fromEntries((authors || []).map((a) => [a.user_id, a.display_name]));
  }

  return (
    <div className="flex flex-col gap-6 p-4">
      {/* Bienvenue */}
      <section className="rounded-card bg-gradient-to-br from-corail/10 via-surface-card to-vert/10 p-5">
        <h1 className="text-xl font-semibold text-content-primary">
          {firstName ? `Bonjour ${firstName} 👋` : 'Bonjour 👋'}
        </h1>
        <p className="mt-1 text-sm text-content-secondary">
          Que se passe-t-il dans {quartierName} ?
        </p>

        <div className="mt-4 flex gap-2 overflow-x-auto">
          <StatPill emoji="👥" value={neighborsCount.count ?? 0} label="voisins" href="/voisins" />
          <StatPill emoji="📋" value={postsTodayCount.count ?? 0} label="aujourd'hui" href="/annonces" />
          <StatPill emoji="🤝" value={entraideCount.count ?? 0} label="entraides" href="/annonces?type=entraide" />
        </div>
      </section>

      {/* Catégories — rangée horizontale, plus adaptée à 5 items qu'une grille 2x2 */}
      <section className="-mx-4 flex gap-3 overflow-x-auto px-4 pb-1">
        {POST_TYPES.map((cat) => {
          const Icon = cat.icon;
          return (
            <Link
              key={cat.type}
              href={`/annonces?type=${cat.type}`}
              className="flex flex-shrink-0 flex-col items-center gap-2 transition-fast active:scale-95"
            >
              <div
                className={`flex h-14 w-14 items-center justify-center rounded-pill ${CATEGORY_COLORS[cat.type]}`}
              >
                <Icon size={24} />
              </div>
              <span className="text-xs font-medium text-content-primary">{cat.label}</span>
            </Link>
          );
        })}
      </section>

      {/* Vie du quartier — fil d'activité réelle, pas de mécanique sociale */}
      <section>
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-base font-semibold text-content-primary">Vie du quartier</h2>
          <Link href="/annonces" className="text-sm font-medium text-corail">
            Tout voir
          </Link>
        </div>

        {feed.length === 0 ? (
          <div className="rounded-card border border-border bg-surface-card p-6 text-center text-sm text-content-secondary">
            Rien de nouveau pour l'instant.
            <div className="mt-2">
              <Link href="/new" className="font-medium text-corail">
                Sois le premier à publier →
              </Link>
            </div>
          </div>
        ) : (
          <div className="flex flex-col gap-2">
            {feed.map((post) => {
              const typeInfo = getPostTypeInfo(post.type);
              const Icon = typeInfo.icon;
              const isAlert = post.type === 'alerte';
              return (
                <Link
                  key={post.id}
                  href={`/annonces/${post.id}`}
                  className={`flex gap-3 rounded-card border p-3 shadow-soft transition-fast hover:bg-border/20 active:scale-[0.99] ${
                    isAlert ? 'border-amber-300 bg-amber-50' : 'border-border bg-surface-card'
                  }`}
                >
                  <div
                    className={`flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-pill ${CATEGORY_COLORS[post.type]}`}
                  >
                    <Icon size={18} />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center justify-between gap-2">
                      <span className="truncate text-xs font-medium text-content-secondary">
                        {authorNames[post.user_id] || 'Voisin'} · {typeInfo.label}
                      </span>
                      <span className="flex-shrink-0 text-xs text-content-secondary">
                        {formatRelativeTime(post.created_at)}
                      </span>
                    </div>
                    <p className="mt-0.5 truncate font-semibold text-content-primary">
                      {post.title}
                    </p>
                    {post.description && (
                      <p className="mt-0.5 line-clamp-1 text-sm text-content-secondary">
                        {post.description}
                      </p>
                    )}
                  </div>
                </Link>
              );
            })}
          </div>
        )}
      </section>
    </div>
  );
}

function StatPill({ emoji, value, label, href }) {
  return (
    <Link
      href={href}
      className="flex flex-shrink-0 items-center gap-1.5 rounded-pill bg-surface px-3 py-1.5 text-sm shadow-soft transition-fast hover:bg-surface-card"
    >
      <span>{emoji}</span>
      <span className="font-semibold text-content-primary">{value}</span>
      <span className="text-content-secondary">{label}</span>
    </Link>
  );
}

MQEOF_SRC_APP_PAGE_JSX

echo "Icones + photos ajoutees avec succes."
echo "Prochaine etape : executer la migration 015, puis git add -A && git commit -m \"icones lucide + upload photos annonces\" && git push"
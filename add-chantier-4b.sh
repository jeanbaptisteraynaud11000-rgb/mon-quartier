#!/usr/bin/env bash
set -e
echo "Ajout du chantier #4b (annonces : liste, detail, creation)..."

mkdir -p "src/lib"
cat > "src/lib/postTypes.js" << 'MQEOF_SRC_LIB_POSTTYPES_JS'
// Constantes partagées entre /annonces, /new et /annonces/[id] pour garder
// les libellés et emojis cohérents partout dans l'app.

export const POST_TYPES = [
  { type: 'don', label: 'Prêt / Don', emoji: '🎁' },
  { type: 'entraide', label: 'Entraide', emoji: '🤝' },
  { type: 'covoiturage', label: 'Covoiturage', emoji: '🚗' },
  { type: 'cherche', label: 'Je cherche', emoji: '🔎' },
];

export function getPostTypeInfo(type) {
  return POST_TYPES.find((t) => t.type === type) || { label: type, emoji: '📌' };
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

mkdir -p "src/app/annonces"
cat > "src/app/annonces/page.jsx" << 'MQEOF_SRC_APP_ANNONCES_PAGE_JSX'
// Server Component : liste des annonces du quartier de l'utilisateur,
// filtrable par type via ?type=don|entraide|covoiturage|cherche.

import Link from 'next/link';
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
    .select('id, type, title, description, created_at, user_id, profiles(display_name)')
    .eq('quartier_id', profile.quartier_id)
    .eq('status', 'active')
    .order('created_at', { ascending: false })
    .limit(30);

  if (activeType) {
    query = query.eq('type', activeType);
  }

  const { data: posts, error } = await query;

  return (
    <div className="flex flex-col gap-4 p-4">
      {/* Filtres de catégorie */}
      <div className="flex gap-2 overflow-x-auto pb-1">
        <FilterPill href="/annonces" label="Toutes" active={!activeType} />
        {POST_TYPES.map((cat) => (
          <FilterPill
            key={cat.type}
            href={`/annonces?type=${cat.type}`}
            label={`${cat.emoji} ${cat.label}`}
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
          return (
            <Link
              key={post.id}
              href={`/annonces/${post.id}`}
              className="flex gap-3 rounded-card border border-border bg-surface-card p-4 shadow-soft transition-fast hover:bg-border/30 active:scale-[0.99]"
            >
              <div className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-pill bg-surface text-lg">
                {typeInfo.emoji}
              </div>
              <div className="min-w-0 flex-1">
                <div className="flex items-center justify-between gap-2">
                  <span className="truncate text-sm font-medium text-content-secondary">
                    {post.profiles?.display_name || 'Voisin'}
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

function FilterPill({ href, label, active }) {
  return (
    <Link
      href={href}
      className={`flex-shrink-0 rounded-pill border px-4 py-2 text-sm font-medium transition-fast ${
        active
          ? 'border-corail bg-corail text-white'
          : 'border-border bg-surface text-content-primary hover:bg-surface-card'
      }`}
    >
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
    .select('id, type, title, description, availability, approx_zone, created_at, user_id, profiles(display_name)')
    .eq('id', id)
    .single();

  if (error || !post) {
    notFound();
  }

  const typeInfo = getPostTypeInfo(post.type);
  const isOwnPost = post.user_id === user.id;

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

      <div className="rounded-card border border-border bg-surface-card p-5">
        <div className="flex items-center gap-2">
          <span className="text-xl">{typeInfo.emoji}</span>
          <span className="text-sm font-medium text-content-secondary">{typeInfo.label}</span>
        </div>

        <h1 className="mt-3 text-xl font-semibold text-content-primary">{post.title}</h1>

        <div className="mt-2 flex items-center gap-2 text-sm text-content-secondary">
          <span>{post.profiles?.display_name || 'Voisin'}</span>
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

      {!isOwnPost && <ContactActions postId={post.id} postTitle={post.title} />}

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
            Autres annonces de {post.profiles?.display_name || 'ce voisin'}
          </h2>
          <div className="flex flex-col gap-2">
            {otherPosts.map((op) => (
              <Link
                key={op.id}
                href={`/annonces/${op.id}`}
                className="rounded-card border border-border bg-surface-card p-3 text-sm text-content-primary transition-fast hover:bg-border/30"
              >
                {getPostTypeInfo(op.type).emoji} {op.title}
              </Link>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

MQEOF_SRC_APP_ANNONCES_ID_PAGE_JSX

mkdir -p "src/app/annonces/[id]"
cat > "src/app/annonces/[id]/ContactActions.jsx" << 'MQEOF_SRC_APP_ANNONCES_ID_CONTACTACTIONS_JSX'
'use client';

import { useState } from 'react';

// NOTE : "Contacter" et "Signaler" nécessitent respectivement la messagerie
// (Phase 4) et la table `reports` + modération (Phase 5) — pas encore
// construites à ce stade de la roadmap (voir section 75 du prompt maître).
// On affiche honnêtement "bientôt disponible" plutôt que de faire semblant
// que ça fonctionne. "Partager" est réellement fonctionnel dès maintenant
// via la Web Share API du navigateur.

export default function ContactActions({ postId, postTitle }) {
  const [notice, setNotice] = useState('');

  async function handleShare() {
    const url = window.location.href;
    if (navigator.share) {
      try {
        await navigator.share({ title: postTitle, url });
      } catch {
        // L'utilisateur a annulé le partage — rien à faire.
      }
    } else {
      await navigator.clipboard.writeText(url);
      setNotice('Lien copié !');
      setTimeout(() => setNotice(''), 2000);
    }
  }

  return (
    <div className="flex flex-col gap-2">
      <div className="grid grid-cols-3 gap-2">
        <button
          onClick={() => setNotice('La messagerie arrive dans un prochain chantier.')}
          className="h-tap rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface-card"
        >
          Contacter
        </button>
        <button
          onClick={() => setNotice('Le signalement arrive dans un prochain chantier.')}
          className="h-tap rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface-card"
        >
          Signaler
        </button>
        <button
          onClick={handleShare}
          className="h-tap rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface-card"
        >
          Partager
        </button>
      </div>
      {notice && <p className="text-center text-sm text-content-secondary">{notice}</p>}
    </div>
  );
}

MQEOF_SRC_APP_ANNONCES_ID_CONTACTACTIONS_JSX

mkdir -p "src/app/new"
cat > "src/app/new/page.jsx" << 'MQEOF_SRC_APP_NEW_PAGE_JSX'
'use client';

import { useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { POST_TYPES } from '@/lib/postTypes';

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

  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

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

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');

    if (!title.trim()) {
      setError('Le titre est obligatoire.');
      return;
    }

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

    setSubmitting(false);

    if (insertError || !newPost) {
      setError("Une erreur est survenue lors de la publication. Réessaie.");
      return;
    }

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
        {POST_TYPES.map((cat) => (
          <button
            key={cat.type}
            onClick={() => setSelectedType(cat.type)}
            className="flex items-center gap-4 rounded-card border border-border bg-surface-card px-4 py-4 text-left transition-fast hover:bg-border/40 active:scale-[0.98]"
          >
            <span className="text-2xl">{cat.emoji}</span>
            <span className="font-medium text-content-primary">{cat.label}</span>
          </button>
        ))}
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
        <span className="text-2xl">{typeInfo?.emoji}</span>
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

        {/* NOTE : upload de photos prévu dans un chantier dédié (Storage,
            validation MIME/taille, sections 56-57 du prompt maître). */}

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

echo "Chantier #4b ajoute avec succes."
echo "Prochaine etape : git add -A && git commit -m \"chantier 4b : annonces\" && git push"
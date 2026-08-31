#!/usr/bin/env bash
set -e
echo "Refonte accueil + type alerte quartier..."

mkdir -p "src/lib"
cat > "src/lib/postTypes.js" << 'MQEOF_SRC_LIB_POSTTYPES_JS'
// Constantes partagées entre /annonces, /new et /annonces/[id] pour garder
// les libellés et emojis cohérents partout dans l'app.

export const POST_TYPES = [
  { type: 'don', label: 'Prêt / Don', emoji: '🎁' },
  { type: 'entraide', label: 'Entraide', emoji: '🤝' },
  { type: 'covoiturage', label: 'Covoiturage', emoji: '🚗' },
  { type: 'cherche', label: 'Je cherche', emoji: '🔎' },
  { type: 'alerte', label: 'Alerte quartier', emoji: '⚠️' },
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

mkdir -p "src/components/layout"
cat > "src/components/layout/CreateSheet.jsx" << 'MQEOF_SRC_COMPONENTS_LAYOUT_CREATESHEET_JSX'
'use client';

import { useEffect } from 'react';
import Link from 'next/link';
import { X } from 'lucide-react';

const OPTIONS = [
  { emoji: '🎁', label: 'Prêt / Don', type: 'don' },
  { emoji: '🤝', label: 'Entraide', type: 'entraide' },
  { emoji: '🚗', label: 'Covoiturage', type: 'covoiturage' },
  { emoji: '🔎', label: 'Je cherche', type: 'cherche' },
  { emoji: '⚠️', label: 'Alerte quartier', type: 'alerte' },
];

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
          {OPTIONS.map((option) => (
            <Link
              key={option.type}
              href={`/new?type=${option.type}`}
              onClick={onClose}
              className="flex items-center gap-4 rounded-card bg-surface-card px-4 py-4 transition-fast hover:bg-border/60 active:scale-[0.98]"
            >
              <span className="text-2xl" aria-hidden="true">
                {option.emoji}
              </span>
              <span className="text-base font-medium text-content-primary">
                {option.label}
              </span>
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
}

MQEOF_SRC_COMPONENTS_LAYOUT_CREATESHEET_JSX

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
        {POST_TYPES.map((cat) => (
          <Link
            key={cat.type}
            href={`/annonces?type=${cat.type}`}
            className="flex flex-shrink-0 flex-col items-center gap-2 transition-fast active:scale-95"
          >
            <div
              className={`flex h-14 w-14 items-center justify-center rounded-pill text-2xl ${CATEGORY_COLORS[cat.type]}`}
            >
              {cat.emoji}
            </div>
            <span className="text-xs font-medium text-content-primary">{cat.label}</span>
          </Link>
        ))}
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
                    className={`flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-pill text-lg ${CATEGORY_COLORS[post.type]}`}
                  >
                    {typeInfo.emoji}
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

echo "Refonte accueil appliquee avec succes."
echo "Prochaine etape : executer la migration 014, puis git add -A && git commit -m \"accueil : feed vie du quartier + alertes\" && git push"
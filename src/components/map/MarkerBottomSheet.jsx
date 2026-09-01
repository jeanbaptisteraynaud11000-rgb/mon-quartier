'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { X, Heart, CalendarDays } from 'lucide-react';
import { supabase } from '@/lib/supabaseClient';
import { getPostTypeInfo } from '@/lib/postTypes';
import { getEventCategoryInfo } from '@/lib/eventCategories';
import { getPlaceCategoryInfo } from '@/lib/placeCategories';

export default function MarkerBottomSheet({ point, onClose }) {
  const [favorited, setFavorited] = useState(false);
  const [userId, setUserId] = useState(null);

  useEffect(() => {
    if (!point || point.kind !== 'post') return;
    let cancelled = false;

    async function load() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user || cancelled) return;
      setUserId(user.id);

      const { data } = await supabase
        .from('favorites')
        .select('post_id')
        .eq('user_id', user.id)
        .eq('post_id', point.id)
        .maybeSingle();
      if (!cancelled) setFavorited(!!data);
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [point]);

  async function handleToggleFavorite() {
    if (!userId || !point) return;
    if (favorited) {
      await supabase.from('favorites').delete().eq('user_id', userId).eq('post_id', point.id);
      setFavorited(false);
    } else {
      await supabase.from('favorites').insert({ user_id: userId, post_id: point.id });
      setFavorited(true);
    }
  }

  if (!point) return null;

  let categoryLabel = '';
  let href = '#';
  let ctaLabel = 'Voir';
  let badgeTint = 'bg-surface-card text-content-secondary';

  if (point.kind === 'post') {
    categoryLabel = getPostTypeInfo(point.category).label;
    href = `/annonces/${point.id}`;
    ctaLabel = "Voir l'annonce";
    badgeTint = 'bg-corail/10 text-corail';
  } else if (point.kind === 'event') {
    categoryLabel = getEventCategoryInfo(point.category).label;
    href = `/activites/${point.id}`;
    ctaLabel = "Voir l'activité";
    badgeTint = 'bg-vert/10 text-vert';
  } else if (point.kind === 'place') {
    categoryLabel = getPlaceCategoryInfo(point.category).label;
    href = `/commerces/${point.id}`;
    ctaLabel = 'Voir la fiche';
    badgeTint = 'bg-surface-card text-content-secondary';
  }

  return (
    <div className="absolute inset-x-0 bottom-0 z-10 rounded-t-sheet bg-surface p-4 shadow-sheet">
      <div className="mx-auto mb-3 h-1 w-10 rounded-pill bg-border" />

      <div className="flex items-start justify-between">
        <span className={`inline-block rounded-pill px-2.5 py-1 text-xs font-semibold uppercase tracking-wide ${badgeTint}`}>
          {categoryLabel}
        </span>
        <div className="flex items-center gap-1">
          {point.kind === 'post' && (
            <button
              onClick={handleToggleFavorite}
              aria-label={favorited ? 'Retirer des favoris' : 'Ajouter aux favoris'}
              className="flex h-8 w-8 items-center justify-center rounded-pill text-content-secondary hover:bg-surface-card"
            >
              <Heart size={16} fill={favorited ? '#FF5A5F' : 'none'} className={favorited ? 'text-corail' : ''} />
            </button>
          )}
          <button
            onClick={onClose}
            aria-label="Fermer"
            className="flex h-8 w-8 items-center justify-center rounded-pill text-content-secondary hover:bg-surface-card"
          >
            <X size={16} />
          </button>
        </div>
      </div>

      <div className="mt-2 flex gap-3">
        <div className="min-w-0 flex-1">
          <p className="font-semibold text-content-primary">{point.title}</p>
          {point.description && (
            <p className="mt-1 line-clamp-2 text-sm text-content-secondary">{point.description}</p>
          )}
        </div>
        {point.photo && (
          <div className="h-16 w-16 flex-shrink-0 overflow-hidden rounded-card bg-surface-card">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={point.photo} alt="" className="h-full w-full object-cover" />
          </div>
        )}
      </div>

      {point.authorName && (
        <div className="mt-3 flex items-center gap-2">
          <div className="flex h-7 w-7 flex-shrink-0 items-center justify-center overflow-hidden rounded-pill bg-corail/10 text-[10px] font-semibold text-corail">
            {point.authorPhoto ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={point.authorPhoto} alt="" className="h-full w-full object-cover" />
            ) : (
              point.authorName.charAt(0).toUpperCase()
            )}
          </div>
          <p className="text-sm text-content-secondary">
            {point.authorName}
            {point.distanceLabel && ` · à ${point.distanceLabel}`}
            {point.zone && ` · ${point.zone}`}
          </p>
        </div>
      )}

      {!point.authorName && point.distanceLabel && (
        <p className="mt-3 text-sm text-content-secondary">à {point.distanceLabel}</p>
      )}

      {point.availability && (
        <div className="mt-3 flex items-center gap-1.5 rounded-card bg-surface-card px-3 py-2 text-xs font-medium text-content-primary">
          <CalendarDays size={13} className="text-content-secondary" />
          {point.availability}
        </div>
      )}

      <Link
        href={href}
        className="mt-4 block h-tap w-full rounded-pill bg-corail text-center leading-[2.75rem] font-medium text-white transition-fast hover:bg-corail-hover"
      >
        {ctaLabel}
      </Link>
    </div>
  );
}


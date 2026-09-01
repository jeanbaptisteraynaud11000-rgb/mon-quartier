'use client';

import Link from 'next/link';
import { X } from 'lucide-react';
import { getPostTypeInfo } from '@/lib/postTypes';
import { getEventCategoryInfo } from '@/lib/eventCategories';
import { getPlaceCategoryInfo } from '@/lib/placeCategories';

export default function MarkerBottomSheet({ point, onClose }) {
  if (!point) return null;

  let icon = null;
  let categoryLabel = '';
  let href = '#';
  let ctaLabel = 'Voir';

  if (point.kind === 'post') {
    const info = getPostTypeInfo(point.category);
    icon = info.icon;
    categoryLabel = info.label;
    href = `/annonces/${point.id}`;
    ctaLabel = "Voir l'annonce";
  } else if (point.kind === 'event') {
    const info = getEventCategoryInfo(point.category);
    icon = info.icon;
    categoryLabel = info.label;
    href = `/activites/${point.id}`;
    ctaLabel = "Voir l'activité";
  } else if (point.kind === 'place') {
    const info = getPlaceCategoryInfo(point.category);
    icon = info.icon;
    categoryLabel = info.label;
    href = `/commerces/${point.id}`;
    ctaLabel = 'Voir la fiche';
  }

  const Icon = icon;

  return (
    <div className="absolute inset-x-0 bottom-0 z-10 rounded-t-sheet bg-surface p-4 shadow-sheet">
      <div className="mb-3 flex items-start justify-between">
        <div className="flex items-center gap-2">
          {Icon && (
            <span className="flex h-9 w-9 items-center justify-center rounded-pill bg-surface-card text-content-primary">
              <Icon size={17} />
            </span>
          )}
          <div>
            <p className="text-xs text-content-secondary">{categoryLabel}</p>
            <p className="font-semibold text-content-primary">{point.title}</p>
          </div>
        </div>
        <button
          onClick={onClose}
          aria-label="Fermer"
          className="flex h-8 w-8 items-center justify-center rounded-pill text-content-secondary hover:bg-surface-card"
        >
          <X size={16} />
        </button>
      </div>

      {point.subtitle && (
        <p className="mb-3 text-sm text-content-secondary">{point.subtitle}</p>
      )}

      <Link
        href={href}
        className="block h-tap w-full rounded-pill bg-corail text-center leading-[2.75rem] font-medium text-white transition-fast hover:bg-corail-hover"
      >
        {ctaLabel}
      </Link>
    </div>
  );
}


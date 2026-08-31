'use client';

import { useEffect } from 'react';
import Link from 'next/link';
import { X, CalendarPlus } from 'lucide-react';
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

          <Link
            href="/activites/new"
            onClick={onClose}
            className="flex items-center gap-4 rounded-card bg-surface-card px-4 py-4 transition-fast hover:bg-border/60 active:scale-[0.98]"
          >
            <span className="flex h-10 w-10 items-center justify-center rounded-pill bg-surface text-content-primary" aria-hidden="true">
              <CalendarPlus size={20} />
            </span>
            <span className="text-base font-medium text-content-primary">
              Organiser une activité
            </span>
          </Link>
        </div>
      </div>
    </div>
  );
}


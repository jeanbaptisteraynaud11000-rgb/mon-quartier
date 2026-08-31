#!/usr/bin/env bash
set -e
echo "Bottom sheet de creation en grille visuelle..."

mkdir -p "src/components/layout"
cat > "src/components/layout/CreateSheet.jsx" << 'MQEOF_SRC_COMPONENTS_LAYOUT_CREATESHEET_JSX'
'use client';

import { useEffect } from 'react';
import Link from 'next/link';
import { X, CalendarPlus } from 'lucide-react';
import { POST_TYPES } from '@/lib/postTypes';

const DESCRIPTIONS = {
  don: "Prêtez ou donnez un objet",
  entraide: "Proposez ou demandez de l'aide",
  covoiturage: "Proposez ou rejoignez un trajet",
  cherche: "Recherchez un objet, un service ou une personne",
  alerte: "Signalez un problème ou informez vos voisins",
};

// Alternance corail/vert, cohérent avec le reste du design system.
const COLORS = ['text-corail', 'text-vert'];

export default function CreateSheet({ open, onClose }) {
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
      <button
        aria-label="Fermer"
        onClick={onClose}
        className="absolute inset-0 bg-black/40 transition-fast"
      />

      <div className="safe-bottom absolute bottom-0 left-0 right-0 max-h-[85vh] overflow-y-auto rounded-t-sheet bg-surface p-6 shadow-sheet">
        <div className="mx-auto mb-4 h-1 w-10 rounded-pill bg-border" />

        <div className="mb-1 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-content-primary">Créer sur Hoody</h2>
          <button
            aria-label="Fermer"
            onClick={onClose}
            className="flex h-tap w-tap items-center justify-center rounded-pill text-content-secondary hover:bg-surface-card"
          >
            <X size={20} />
          </button>
        </div>
        <p className="mb-5 text-sm text-content-secondary">Que voulez-vous faire ?</p>

        <div className="grid grid-cols-2 gap-3">
          {POST_TYPES.map((option, i) => (
            <Link
              key={option.type}
              href={`/new?type=${option.type}`}
              onClick={onClose}
              className="flex flex-col gap-2 rounded-card border border-border bg-surface-card p-3 transition-fast hover:bg-border/40 active:scale-[0.98]"
            >
              <div className="h-12 w-12 overflow-hidden rounded-card">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={`/categories/${option.type}.png`} alt="" className="h-full w-full object-cover" />
              </div>
              <div>
                <p className={`text-sm font-semibold ${COLORS[i % 2]}`}>{option.label}</p>
                <p className="mt-0.5 text-xs text-content-secondary">{DESCRIPTIONS[option.type]}</p>
              </div>
            </Link>
          ))}

          <Link
            href="/activites/new"
            onClick={onClose}
            className="flex flex-col gap-2 rounded-card border border-border bg-surface-card p-3 transition-fast hover:bg-border/40 active:scale-[0.98]"
          >
            <div className="flex h-12 w-12 items-center justify-center rounded-card bg-vert/10 text-vert">
              <CalendarPlus size={22} />
            </div>
            <div>
              <p className="text-sm font-semibold text-vert">Activité</p>
              <p className="mt-0.5 text-xs text-content-secondary">Proposez ou organisez une activité</p>
            </div>
          </Link>
        </div>
      </div>
    </div>
  );
}

MQEOF_SRC_COMPONENTS_LAYOUT_CREATESHEET_JSX

echo "CreateSheet mis a jour avec succes."
echo "Prochaine etape : git add -A && git commit -m \"bottom sheet creation : grille visuelle avec images\" && git push"
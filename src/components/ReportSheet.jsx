'use client';

import { useState } from 'react';
import { supabase } from '@/lib/supabaseClient';

const REASONS = [
  { value: 'inapproprie', label: 'Contenu inapproprié' },
  { value: 'spam', label: 'Spam' },
  { value: 'usurpation', label: 'Usurpation' },
  { value: 'harcelement', label: 'Harcèlement' },
  { value: 'arnaque', label: 'Arnaque' },
  { value: 'autre', label: 'Autre' },
];

export default function ReportSheet({ open, onClose, targetType, targetId }) {
  const [reason, setReason] = useState(null);
  const [details, setDetails] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState('');

  if (!open) return null;

  async function handleSubmit() {
    if (!reason) return;
    setSubmitting(true);
    setError('');

    const { data: { user } } = await supabase.auth.getUser();
    const { data: profile } = await supabase
      .from('profiles')
      .select('quartier_id')
      .eq('user_id', user.id)
      .single();

    const { error: insertError } = await supabase.from('reports').insert({
      reporter_id: user.id,
      quartier_id: profile.quartier_id,
      target_type: targetType,
      target_id: targetId,
      reason,
      details: details.trim() || null,
    });

    setSubmitting(false);

    if (insertError) {
      setError('Une erreur est survenue. Réessaie.');
      return;
    }

    setDone(true);
  }

  function handleClose() {
    setReason(null);
    setDetails('');
    setDone(false);
    setError('');
    onClose();
  }

  return (
    <div className="fixed inset-0 z-50" role="dialog" aria-modal="true">
      <button
        aria-label="Fermer"
        onClick={handleClose}
        className="absolute inset-0 bg-black/40"
      />
      <div className="safe-bottom absolute bottom-0 left-0 right-0 rounded-t-sheet bg-surface p-6 shadow-sheet">
        <div className="mx-auto mb-4 h-1 w-10 rounded-pill bg-border" />

        {done ? (
          <div className="py-4 text-center">
            <p className="font-medium text-content-primary">
              Merci, votre signalement a été pris en compte.
            </p>
            <p className="mt-1 text-sm text-content-secondary">
              La communauté et nos modérateurs veilleront à la suite.
            </p>
            <button
              onClick={handleClose}
              className="mt-4 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover"
            >
              Fermer
            </button>
          </div>
        ) : (
          <>
            <h2 className="mb-4 text-lg font-semibold text-content-primary">
              Pourquoi souhaitez-vous signaler ce contenu ?
            </h2>

            <div className="flex flex-col gap-2">
              {REASONS.map((r) => (
                <button
                  key={r.value}
                  onClick={() => setReason(r.value)}
                  className={`rounded-card border px-4 py-3 text-left transition-fast ${
                    reason === r.value
                      ? 'border-corail bg-corail/5 text-corail'
                      : 'border-border bg-surface-card text-content-primary hover:bg-border/30'
                  }`}
                >
                  {r.label}
                </button>
              ))}
            </div>

            <textarea
              value={details}
              onChange={(e) => setDetails(e.target.value)}
              placeholder="Préciser — optionnel"
              rows={3}
              className="mt-4 w-full resize-none rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
            />

            {error && <p className="mt-2 text-sm text-corail">{error}</p>}

            <button
              onClick={handleSubmit}
              disabled={!reason || submitting}
              className="mt-4 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
            >
              {submitting ? 'Envoi...' : 'Envoyer'}
            </button>
          </>
        )}
      </div>
    </div>
  );
}


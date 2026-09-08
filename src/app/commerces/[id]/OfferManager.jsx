'use client';

import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabaseClient';
import { Tag } from 'lucide-react';

const STATUS_LABELS = {
  pending: { label: 'En attente de validation', tint: 'bg-surface text-content-secondary' },
  active: { label: 'Active', tint: 'bg-vert/10 text-vert' },
  rejected: { label: 'Refusée', tint: 'bg-corail/10 text-corail' },
  expired: { label: 'Terminée', tint: 'bg-surface text-content-secondary' },
};

export default function OfferManager({ placeId }) {
  const [offers, setOffers] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [endsAt, setEndsAt] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  async function load() {
    const { data } = await supabase
      .from('place_offers')
      .select('id, title, description, ends_at, status')
      .eq('place_id', placeId)
      .order('created_at', { ascending: false });
    setOffers(data || []);
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [placeId]);

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');

    if (!title.trim() || !endsAt) {
      setError("Le titre de l'offre et la date de fin sont obligatoires.");
      return;
    }

    setSubmitting(true);
    const { error: insertError } = await supabase.from('place_offers').insert({
      place_id: placeId,
      title: title.trim(),
      description: description.trim() || null,
      ends_at: new Date(`${endsAt}T23:59:59`).toISOString(),
    });
    setSubmitting(false);

    if (insertError) {
      setError('Une erreur est survenue. Réessaie.');
      return;
    }

    setTitle('');
    setDescription('');
    setEndsAt('');
    setShowForm(false);
    setSuccess(true);
    load();
  }

  return (
    <div className="rounded-card border border-border bg-surface-card p-4">
      <div className="flex items-center justify-between">
        <h2 className="text-sm font-semibold text-content-primary">Mes offres</h2>
        <button
          onClick={() => setShowForm((v) => !v)}
          className="text-sm font-medium text-corail"
        >
          {showForm ? 'Annuler' : '+ Créer une offre'}
        </button>
      </div>

      <p className="mt-1 text-xs text-content-secondary">
        Une offre est visible par tout le quartier une fois validée. La validation se fait
        manuellement pour l'instant — contacte l'équipe Hoody pour organiser le paiement.
      </p>

      {success && (
        <p className="mt-2 text-xs text-vert">
          ✓ Demande envoyée, elle sera activée après validation.
        </p>
      )}

      {showForm && (
        <form onSubmit={handleSubmit} className="mt-3 flex flex-col gap-2 border-t border-border pt-3">
          <input
            type="text"
            maxLength={100}
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Ex : -20% ce week-end"
            className="w-full rounded-card border border-border bg-surface px-3 py-2 text-sm text-content-primary outline-none focus:border-corail"
          />
          <textarea
            rows={2}
            maxLength={300}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Détails (optionnel)"
            className="w-full resize-none rounded-card border border-border bg-surface px-3 py-2 text-sm text-content-primary outline-none focus:border-corail"
          />
          <div>
            <label className="mb-1 block text-xs text-content-secondary">Valable jusqu'au</label>
            <input
              type="date"
              value={endsAt}
              onChange={(e) => setEndsAt(e.target.value)}
              className="w-full rounded-card border border-border bg-surface px-3 py-2 text-sm text-content-primary outline-none focus:border-corail"
            />
          </div>
          {error && <p className="text-xs text-corail">{error}</p>}
          <button
            type="submit"
            disabled={submitting}
            className="h-tap rounded-pill bg-corail text-sm font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
          >
            {submitting ? 'Envoi...' : 'Envoyer la demande'}
          </button>
        </form>
      )}

      {offers.length > 0 && (
        <div className="mt-3 flex flex-col gap-2 border-t border-border pt-3">
          {offers.map((o) => (
            <div key={o.id} className="flex items-center gap-2 rounded-card bg-surface p-2">
              <Tag size={14} className="flex-shrink-0 text-content-secondary" />
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm text-content-primary">{o.title}</p>
              </div>
              <span className={`flex-shrink-0 rounded-pill px-2 py-0.5 text-[10px] font-medium ${STATUS_LABELS[o.status].tint}`}>
                {STATUS_LABELS[o.status].label}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}


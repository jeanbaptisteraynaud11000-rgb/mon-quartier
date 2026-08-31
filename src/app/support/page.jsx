'use client';

import { useState } from 'react';
import { supabase } from '@/lib/supabaseClient';

const CATEGORIES = ['Compte', 'Quartier', 'Annonces', 'Messagerie', 'Confidentialité', 'Sécurité', 'Autre'];

export default function SupportPage() {
  const [category, setCategory] = useState(CATEGORIES[0]);
  const [subject, setSubject] = useState('');
  const [description, setDescription] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState('');

  async function handleSubmit(e) {
    e.preventDefault();
    if (!subject.trim() || !description.trim()) return;

    setSubmitting(true);
    setError('');

    const { data: { user } } = await supabase.auth.getUser();
    const { error: insertError } = await supabase.from('support_requests').insert({
      user_id: user.id,
      category,
      subject: subject.trim(),
      description: description.trim(),
    });

    setSubmitting(false);

    if (insertError) {
      setError('Une erreur est survenue. Réessaie.');
      return;
    }

    setDone(true);
  }

  if (done) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center p-6 text-center">
        <div className="text-4xl">✓</div>
        <h1 className="mt-3 text-lg font-semibold text-content-primary">
          Ta demande a bien été envoyée
        </h1>
        <p className="mt-1 text-sm text-content-secondary">On te répondra au plus vite.</p>
      </div>
    );
  }

  return (
    <div className="p-6">
      <h1 className="mb-4 text-xl font-semibold text-content-primary">Contacter le support</h1>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <div>
          <label className="mb-1 block text-sm font-medium text-content-primary">Catégorie</label>
          <select
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none focus:border-corail"
          >
            {CATEGORIES.map((c) => (
              <option key={c} value={c}>{c}</option>
            ))}
          </select>
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium text-content-primary">Sujet</label>
          <input
            type="text"
            required
            value={subject}
            onChange={(e) => setSubject(e.target.value)}
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none focus:border-corail"
          />
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium text-content-primary">Description</label>
          <textarea
            required
            rows={5}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            className="w-full resize-none rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none focus:border-corail"
          />
        </div>

        {error && <p className="text-sm text-corail">{error}</p>}

        <button
          type="submit"
          disabled={submitting}
          className="h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
        >
          {submitting ? 'Envoi...' : 'Envoyer'}
        </button>
      </form>
    </div>
  );
}


'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { Plus, X } from 'lucide-react';

const MAX_OPTIONS = 5;

export default function NewPollPage() {
  const router = useRouter();
  const [quartierId, setQuartierId] = useState(null);
  const [loadingProfile, setLoadingProfile] = useState(true);

  const [question, setQuestion] = useState('');
  const [options, setOptions] = useState(['', '']);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const hasSubmittedRef = useRef(false);

  useEffect(() => {
    async function load() {
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
    load();
  }, [router]);

  function updateOption(index, value) {
    setOptions((prev) => prev.map((o, i) => (i === index ? value : o)));
  }

  function addOption() {
    if (options.length < MAX_OPTIONS) setOptions((prev) => [...prev, '']);
  }

  function removeOption(index) {
    if (options.length > 2) setOptions((prev) => prev.filter((_, i) => i !== index));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');

    if (hasSubmittedRef.current) return;

    const cleanOptions = options.map((o) => o.trim()).filter(Boolean);
    if (!question.trim()) {
      setError('La question est obligatoire.');
      return;
    }
    if (cleanOptions.length < 2) {
      setError('Il faut au moins 2 choix.');
      return;
    }

    hasSubmittedRef.current = true;
    setSubmitting(true);

    const { data: { user } } = await supabase.auth.getUser();

    const { data: poll, error: pollError } = await supabase
      .from('polls')
      .insert({ quartier_id: quartierId, user_id: user.id, question: question.trim() })
      .select('id')
      .single();

    if (pollError || !poll) {
      setSubmitting(false);
      hasSubmittedRef.current = false;
      setError('Une erreur est survenue. Réessaie.');
      return;
    }

    const { error: optionsError } = await supabase.from('poll_options').insert(
      cleanOptions.map((label, i) => ({ poll_id: poll.id, label, position: i }))
    );

    setSubmitting(false);

    if (optionsError) {
      setError('Le sondage a été créé mais les choix ont échoué. Contacte le support.');
      return;
    }

    router.push('/sondages');
  }

  if (loadingProfile) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="skeleton h-4 w-40" />
      </div>
    );
  }

  return (
    <div className="p-6">
      <h1 className="mb-1 text-xl font-semibold text-content-primary">Créer un sondage</h1>
      <p className="mb-6 text-sm text-content-secondary">Pose une question à tout ton quartier.</p>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <div>
          <label htmlFor="question" className="mb-1 block text-sm font-medium text-content-primary">
            Question
          </label>
          <input
            id="question"
            type="text"
            required
            maxLength={200}
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
            placeholder="Ex : Quel jour pour la fête des voisins ?"
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium text-content-primary">Choix</label>
          <div className="flex flex-col gap-2">
            {options.map((option, i) => (
              <div key={i} className="flex items-center gap-2">
                <input
                  type="text"
                  maxLength={100}
                  value={option}
                  onChange={(e) => updateOption(i, e.target.value)}
                  placeholder={`Choix ${i + 1}`}
                  className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
                />
                {options.length > 2 && (
                  <button
                    type="button"
                    onClick={() => removeOption(i)}
                    aria-label="Retirer ce choix"
                    className="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-pill text-content-secondary hover:bg-surface-card"
                  >
                    <X size={16} />
                  </button>
                )}
              </div>
            ))}
          </div>
          {options.length < MAX_OPTIONS && (
            <button
              type="button"
              onClick={addOption}
              className="mt-2 flex items-center gap-1.5 text-sm font-medium text-corail"
            >
              <Plus size={15} /> Ajouter un choix
            </button>
          )}
        </div>

        {error && <p className="text-sm text-corail">{error}</p>}

        <button
          type="submit"
          disabled={submitting}
          className="mt-2 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
        >
          {submitting ? 'Publication...' : 'Publier le sondage'}
        </button>
      </form>
    </div>
  );
}


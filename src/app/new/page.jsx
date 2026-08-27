'use client';

import { useEffect, useRef, useState } from 'react';
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
  // Verrou synchrone en plus du state React : `submitting` ne se propage
  // qu'au prochain rendu, ce qui laisse une fenêtre où un double-clic très
  // rapide peut déclencher handleSubmit deux fois avant que le bouton ne
  // soit visuellement désactivé. Une ref, elle, est lue/écrite immédiatement.
  const hasSubmittedRef = useRef(false);

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

    if (hasSubmittedRef.current) return;

    if (!title.trim()) {
      setError('Le titre est obligatoire.');
      return;
    }

    hasSubmittedRef.current = true;
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
      hasSubmittedRef.current = false;
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


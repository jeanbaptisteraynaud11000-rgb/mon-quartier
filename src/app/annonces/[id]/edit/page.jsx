'use client';

import { useEffect, useState } from 'react';
import { useRouter, useParams } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { getPostTypeInfo } from '@/lib/postTypes';

export default function EditPostPage() {
  const router = useRouter();
  const { id } = useParams();

  const [loading, setLoading] = useState(true);
  const [notFoundOrForbidden, setNotFoundOrForbidden] = useState(false);
  const [type, setType] = useState(null);

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [availability, setAvailability] = useState('');
  const [approxZone, setApproxZone] = useState('');

  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    async function loadPost() {
      const { data: { user } } = await supabase.auth.getUser();

      const { data: post, error: fetchError } = await supabase
        .from('posts')
        .select('id, type, title, description, availability, approx_zone, user_id')
        .eq('id', id)
        .single();

      // La policy RLS empêche déjà de lire l'annonce d'un autre quartier,
      // mais on vérifie aussi explicitement que c'est bien SON annonce —
      // un admin pourrait techniquement la voir sans en être l'auteur.
      if (fetchError || !post || post.user_id !== user.id) {
        setNotFoundOrForbidden(true);
        setLoading(false);
        return;
      }

      setType(post.type);
      setTitle(post.title);
      setDescription(post.description || '');
      setAvailability(post.availability || '');
      setApproxZone(post.approx_zone || '');
      setLoading(false);
    }
    loadPost();
  }, [id]);

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');

    if (!title.trim()) {
      setError('Le titre est obligatoire.');
      return;
    }

    setSubmitting(true);

    const { error: updateError } = await supabase
      .from('posts')
      .update({
        title: title.trim(),
        description: description.trim() || null,
        availability: availability.trim() || null,
        approx_zone: approxZone.trim() || null,
      })
      .eq('id', id);

    setSubmitting(false);

    if (updateError) {
      setError("Une erreur est survenue. Réessaie.");
      return;
    }

    router.push(`/annonces/${id}`);
  }

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="skeleton h-4 w-40" />
      </div>
    );
  }

  if (notFoundOrForbidden) {
    return (
      <div className="p-6 text-center">
        <p className="text-content-primary">
          Cette annonce n'existe pas ou tu n'as pas le droit de la modifier.
        </p>
      </div>
    );
  }

  const typeInfo = getPostTypeInfo(type);

  return (
    <div className="p-6">
      <div className="mb-6 flex items-center gap-2">
        <span className="text-2xl">{typeInfo?.emoji}</span>
        <h1 className="text-xl font-semibold text-content-primary">Modifier l'annonce</h1>
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
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        {error && <p className="text-sm text-corail">{error}</p>}

        <button
          type="submit"
          disabled={submitting}
          className="mt-2 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
        >
          {submitting ? 'Enregistrement...' : 'Enregistrer les modifications'}
        </button>
      </form>
    </div>
  );
}


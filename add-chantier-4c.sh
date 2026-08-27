#!/usr/bin/env bash
set -e
echo "Ajout du chantier #4c (mes-annonces + edition)..."

mkdir -p "src/app/mes-annonces"
cat > "src/app/mes-annonces/page.jsx" << 'MQEOF_SRC_APP_MES-ANNONCES_PAGE_JSX'
'use client';

import { useEffect, useState, useCallback } from 'react';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';
import { getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';

const TABS = [
  { key: 'active', label: 'Actives' },
  { key: 'draft', label: 'Brouillons' },
  { key: 'completed', label: 'Terminées' },
];

export default function MesAnnoncesPage() {
  const [activeTab, setActiveTab] = useState('active');
  const [posts, setPosts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [actionError, setActionError] = useState('');

  const loadPosts = useCallback(async (status) => {
    setLoading(true);
    const { data: { user } } = await supabase.auth.getUser();

    // Les brouillons ne sont pas encore implémentés (nécessite une table
    // dédiée, voir prompt maître section 26) — on ne fait pas de requête
    // inutile et on affiche directement l'empty state.
    if (status === 'draft') {
      setPosts([]);
      setLoading(false);
      return;
    }

    const { data } = await supabase
      .from('posts')
      .select('id, type, title, description, status, created_at')
      .eq('user_id', user.id)
      .eq('status', status)
      .order('created_at', { ascending: false });

    setPosts(data || []);
    setLoading(false);
  }, []);

  useEffect(() => {
    loadPosts(activeTab);
  }, [activeTab, loadPosts]);

  async function handleMarkCompleted(postId) {
    setActionError('');
    const { error } = await supabase.from('posts').update({ status: 'completed' }).eq('id', postId);
    if (error) {
      setActionError("Impossible de mettre à jour cette annonce.");
      return;
    }
    loadPosts(activeTab);
  }

  async function handleRepublish(postId) {
    setActionError('');
    const { error } = await supabase.from('posts').update({ status: 'active' }).eq('id', postId);
    if (error) {
      setActionError("Impossible de republier cette annonce.");
      return;
    }
    loadPosts(activeTab);
  }

  async function handleDelete(postId) {
    if (!confirm('Supprimer définitivement cette annonce ?')) return;
    setActionError('');
    const { error } = await supabase.from('posts').update({ status: 'deleted' }).eq('id', postId);
    if (error) {
      setActionError("Impossible de supprimer cette annonce.");
      return;
    }
    loadPosts(activeTab);
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="flex gap-2">
        {TABS.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            className={`flex-1 rounded-pill border px-3 py-2 text-sm font-medium transition-fast ${
              activeTab === tab.key
                ? 'border-corail bg-corail text-white'
                : 'border-border bg-surface text-content-primary hover:bg-surface-card'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {actionError && <p className="text-sm text-corail">{actionError}</p>}

      {loading && <div className="skeleton h-20 w-full" />}

      {!loading && activeTab === 'draft' && (
        <div className="rounded-card border border-border bg-surface-card p-6 text-center text-sm text-content-secondary">
          Les brouillons arrivent dans un prochain chantier.
        </div>
      )}

      {!loading && activeTab !== 'draft' && posts.length === 0 && (
        <div className="rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">
            {activeTab === 'active' ? "Tu n'as pas d'annonce active." : 'Aucune annonce terminée.'}
          </p>
          {activeTab === 'active' && (
            <Link
              href="/new"
              className="mt-4 inline-block h-tap rounded-pill bg-corail px-6 py-3 font-medium text-white transition-fast hover:bg-corail-hover"
            >
              Publier une annonce
            </Link>
          )}
        </div>
      )}

      <div className="flex flex-col gap-3">
        {posts.map((post) => {
          const typeInfo = getPostTypeInfo(post.type);
          return (
            <div key={post.id} className="rounded-card border border-border bg-surface-card p-4">
              <Link href={`/annonces/${post.id}`} className="block">
                <div className="flex items-center gap-2 text-sm text-content-secondary">
                  <span>{typeInfo.emoji}</span>
                  <span>{typeInfo.label}</span>
                  <span>·</span>
                  <span>{formatRelativeTime(post.created_at)}</span>
                </div>
                <p className="mt-1 font-semibold text-content-primary">{post.title}</p>
              </Link>

              <div className="mt-3 flex flex-wrap gap-2">
                <Link
                  href={`/annonces/${post.id}/edit`}
                  className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-content-primary transition-fast hover:bg-surface"
                >
                  Modifier
                </Link>

                {activeTab === 'active' && (
                  <button
                    onClick={() => handleMarkCompleted(post.id)}
                    className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-content-primary transition-fast hover:bg-surface"
                  >
                    Marquer terminé
                  </button>
                )}

                {activeTab === 'completed' && (
                  <button
                    onClick={() => handleRepublish(post.id)}
                    className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-content-primary transition-fast hover:bg-surface"
                  >
                    Republier
                  </button>
                )}

                <button
                  onClick={() => handleDelete(post.id)}
                  className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-corail transition-fast hover:bg-surface"
                >
                  Supprimer
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

MQEOF_SRC_APP_MES-ANNONCES_PAGE_JSX

mkdir -p "src/app/annonces/[id]/edit"
cat > "src/app/annonces/[id]/edit/page.jsx" << 'MQEOF_SRC_APP_ANNONCES_ID_EDIT_PAGE_JSX'
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

MQEOF_SRC_APP_ANNONCES_ID_EDIT_PAGE_JSX

echo "Chantier #4c ajoute avec succes."
echo "Prochaine etape : git add -A && git commit -m \"chantier 4c : mes-annonces\" && git push"
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
          const Icon = typeInfo.icon;
          return (
            <div key={post.id} className="rounded-card border border-border bg-surface-card p-4">
              <Link href={`/annonces/${post.id}`} className="block">
                <div className="flex items-center gap-2 text-sm text-content-secondary">
                  <Icon size={14} />
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


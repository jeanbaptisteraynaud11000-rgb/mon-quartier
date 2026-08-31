'use client';

import { useEffect, useState, useCallback } from 'react';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';
import { getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';

// NOTE : pas de filtre explicite par quartier_id ici — la policy RLS
// "posts_select_own_quartier" s'en charge déjà (un quartier_admin ne voit
// que les annonces de son quartier, un super_admin les voit toutes).

export default function PostsAdminList() {
  const [posts, setPosts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('active');

  const load = useCallback(async (status) => {
    setLoading(true);
    const { data } = await supabase
      .from('posts')
      .select('id, type, title, user_id, status, created_at')
      .eq('status', status)
      .order('created_at', { ascending: false })
      .limit(50);
    setPosts(data || []);
    setLoading(false);
  }, []);

  useEffect(() => {
    load(filter);
  }, [filter, load]);

  async function handleHide(postId) {
    const reason = prompt('Motif du masquage (optionnel) :') || null;
    const { error } = await supabase.rpc('hide_post', { p_post_id: postId, p_reason: reason });
    if (!error) load(filter);
  }

  async function handleRestore(postId) {
    const { error } = await supabase.rpc('restore_post', { p_post_id: postId });
    if (!error) load(filter);
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <Link href="/admin" className="text-sm text-content-secondary">
        ← Administration
      </Link>
      <h1 className="text-xl font-semibold text-content-primary">Annonces</h1>

      <div className="flex gap-2">
        {['active', 'hidden'].map((s) => (
          <button
            key={s}
            onClick={() => setFilter(s)}
            className={`rounded-pill border px-3 py-1.5 text-sm font-medium transition-fast ${
              filter === s
                ? 'border-corail bg-corail text-white'
                : 'border-border bg-surface text-content-primary'
            }`}
          >
            {s === 'active' ? 'Actives' : 'Masquées'}
          </button>
        ))}
      </div>

      {loading && <div className="skeleton h-16 w-full" />}

      {!loading && posts.length === 0 && (
        <p className="text-sm text-content-secondary">Aucune annonce dans cette catégorie.</p>
      )}

      <div className="flex flex-col gap-2">
        {posts.map((post) => {
          const typeInfo = getPostTypeInfo(post.type);
          const Icon = typeInfo.icon;
          return (
            <div key={post.id} className="rounded-card border border-border bg-surface-card p-4">
              <div className="flex items-center justify-between text-sm text-content-secondary">
                <span className="flex items-center gap-1.5"><Icon size={14} /> {typeInfo.label}</span>
                <span>{formatRelativeTime(post.created_at)}</span>
              </div>
              <Link href={`/annonces/${post.id}`} className="mt-1 block font-medium text-content-primary">
                {post.title}
              </Link>

              <div className="mt-3">
                {post.status === 'active' ? (
                  <button
                    onClick={() => handleHide(post.id)}
                    className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-corail hover:bg-surface"
                  >
                    Masquer
                  </button>
                ) : (
                  <button
                    onClick={() => handleRestore(post.id)}
                    className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-content-primary hover:bg-surface"
                  >
                    Restaurer
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}


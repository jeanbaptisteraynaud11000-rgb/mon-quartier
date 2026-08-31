'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { ChevronLeft, Share2, Heart } from 'lucide-react';
import { supabase } from '@/lib/supabaseClient';

export default function PostHeaderActions({ postId, postTitle }) {
  const router = useRouter();
  const [favorited, setFavorited] = useState(false);
  const [userId, setUserId] = useState(null);

  useEffect(() => {
    async function load() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;
      setUserId(user.id);

      const { data } = await supabase
        .from('favorites')
        .select('post_id')
        .eq('user_id', user.id)
        .eq('post_id', postId)
        .maybeSingle();
      setFavorited(!!data);
    }
    load();
  }, [postId]);

  async function handleToggleFavorite() {
    if (!userId) return;
    if (favorited) {
      await supabase.from('favorites').delete().eq('user_id', userId).eq('post_id', postId);
      setFavorited(false);
    } else {
      await supabase.from('favorites').insert({ user_id: userId, post_id: postId });
      setFavorited(true);
    }
  }

  async function handleShare() {
    const url = window.location.href;
    if (navigator.share) {
      try {
        await navigator.share({ title: postTitle, url });
      } catch {
        // Partage annulé — rien à faire.
      }
    } else {
      await navigator.clipboard.writeText(url);
    }
  }

  return (
    <div className="absolute inset-x-0 top-0 flex items-center justify-between p-3">
      <button
        onClick={() => router.back()}
        aria-label="Retour"
        className="flex h-9 w-9 items-center justify-center rounded-pill bg-white/90 text-content-primary shadow-soft"
      >
        <ChevronLeft size={20} />
      </button>
      <div className="flex gap-2">
        <button
          onClick={handleToggleFavorite}
          aria-label={favorited ? 'Retirer des favoris' : 'Ajouter aux favoris'}
          className="flex h-9 w-9 items-center justify-center rounded-pill bg-white/90 shadow-soft"
        >
          <Heart size={18} fill={favorited ? '#FF5A5F' : 'none'} className={favorited ? 'text-corail' : 'text-content-primary'} />
        </button>
        <button
          onClick={handleShare}
          aria-label="Partager"
          className="flex h-9 w-9 items-center justify-center rounded-pill bg-white/90 text-content-primary shadow-soft"
        >
          <Share2 size={17} />
        </button>
      </div>
    </div>
  );
}


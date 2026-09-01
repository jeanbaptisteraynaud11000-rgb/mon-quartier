'use client';

import { useEffect, useState } from 'react';
import { Heart } from 'lucide-react';
import { supabase } from '@/lib/supabaseClient';

export default function FavoriteHeartButton({ postId }) {
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

  async function handleClick(e) {
    e.preventDefault();
    e.stopPropagation();
    if (!userId) return;

    if (favorited) {
      await supabase.from('favorites').delete().eq('user_id', userId).eq('post_id', postId);
      setFavorited(false);
    } else {
      await supabase.from('favorites').insert({ user_id: userId, post_id: postId });
      setFavorited(true);
    }
  }

  return (
    <button
      onClick={handleClick}
      aria-label={favorited ? 'Retirer des favoris' : 'Ajouter aux favoris'}
      className="absolute right-2 top-2 flex h-7 w-7 items-center justify-center rounded-pill bg-white/90 shadow-soft"
    >
      <Heart size={14} fill={favorited ? '#FF5A5F' : 'none'} className={favorited ? 'text-corail' : 'text-content-primary'} />
    </button>
  );
}


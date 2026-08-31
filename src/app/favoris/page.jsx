// Server Component : mes annonces favorites.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';
import { getPlaceholderImage } from '@/lib/placeholderImages';

export default async function FavorisPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: favorites } = await supabase
    .from('favorites')
    .select('post_id, created_at')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false });

  const postIds = (favorites || []).map((f) => f.post_id);

  let posts = [];
  let thumbnailByPost = {};
  if (postIds.length > 0) {
    const { data } = await supabase
      .from('posts')
      .select('id, type, title, created_at, status')
      .in('id', postIds)
      .eq('status', 'active');
    posts = data || [];

    const { data: images } = await supabase
      .from('post_images')
      .select('post_id, storage_path, position')
      .in('post_id', postIds)
      .order('position', { ascending: true });

    for (const img of images || []) {
      if (!thumbnailByPost[img.post_id]) {
        thumbnailByPost[img.post_id] = supabase.storage.from('posts').getPublicUrl(img.storage_path).data.publicUrl;
      }
    }
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <h1 className="text-xl font-semibold text-content-primary">Mes favoris</h1>

      {posts.length === 0 && (
        <div className="rounded-card border border-border bg-surface-card p-6 text-center text-sm text-content-secondary">
          Aucune annonce en favori pour l'instant. Touche le cœur sur une annonce pour la
          retrouver ici.
        </div>
      )}

      <div className="flex flex-col gap-2">
        {posts.map((post) => {
          const thumbnail = thumbnailByPost[post.id] || getPlaceholderImage(post.type);
          return (
            <Link
              key={post.id}
              href={`/annonces/${post.id}`}
              className="flex items-center gap-3 rounded-card border border-border bg-surface-card p-3 transition-fast hover:bg-border/20"
            >
              <div className="h-12 w-12 flex-shrink-0 overflow-hidden rounded-card">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={thumbnail} alt="" className="h-full w-full object-cover" />
              </div>
              <div className="min-w-0 flex-1">
                <p className="truncate font-medium text-content-primary">{post.title}</p>
                <p className="text-xs text-content-secondary">{formatRelativeTime(post.created_at)}</p>
              </div>
            </Link>
          );
        })}
      </div>
    </div>
  );
}


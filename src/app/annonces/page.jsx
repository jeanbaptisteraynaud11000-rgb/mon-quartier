// Server Component : liste des annonces du quartier de l'utilisateur,
// filtrable par type via ?type=don|entraide|covoiturage|cherche|alerte.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { POST_TYPES, getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';
import { getPlaceholderImage } from '@/lib/placeholderImages';
import { Heart } from 'lucide-react';
import PostCardMenu from './PostCardMenu';

export default async function AnnoncesPage({ searchParams }) {
  const params = await searchParams;
  const activeType = params?.type;

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: profile } = await supabase
    .from('profiles')
    .select('quartier_id')
    .eq('user_id', user.id)
    .single();

  if (!profile?.quartier_id) {
    return (
      <div className="p-4">
        <div className="rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">
            Termine d'abord ton inscription pour voir les annonces de ton quartier.
          </p>
          <Link
            href="/onboarding"
            className="mt-4 inline-block h-tap rounded-pill bg-corail px-6 py-3 font-medium text-white transition-fast hover:bg-corail-hover"
          >
            Terminer mon inscription
          </Link>
        </div>
      </div>
    );
  }

  let query = supabase
    .from('posts')
    .select('id, type, title, description, approx_zone, created_at, user_id')
    .eq('quartier_id', profile.quartier_id)
    .eq('status', 'active')
    .order('created_at', { ascending: false })
    .limit(30);

  if (activeType) {
    query = query.eq('type', activeType);
  }

  const { data: posts, error } = await query;

  // Requêtes séparées : pas de clé étrangère directe posts → profiles.
  let authorInfo = {};
  let thumbnailByPost = {};
  let favoriteCounts = {};
  if (posts?.length > 0) {
    const userIds = [...new Set(posts.map((p) => p.user_id))];
    const postIds = posts.map((p) => p.id);

    const [{ data: authors }, { data: images }, { data: counts }] = await Promise.all([
      supabase.from('profiles').select('user_id, display_name, photo_url, photo_visible').in('user_id', userIds),
      supabase
        .from('post_images')
        .select('post_id, storage_path, position')
        .in('post_id', postIds)
        .order('position', { ascending: true }),
      supabase.rpc('get_favorite_counts', { p_post_ids: postIds }),
    ]);

    authorInfo = Object.fromEntries((authors || []).map((a) => [a.user_id, a]));

    for (const img of images || []) {
      if (!thumbnailByPost[img.post_id]) {
        thumbnailByPost[img.post_id] = supabase.storage.from('posts').getPublicUrl(img.storage_path).data.publicUrl;
      }
    }

    favoriteCounts = Object.fromEntries((counts || []).map((c) => [c.post_id, c.count]));
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      {/* Filtres de catégorie */}
      <div className="grid grid-cols-3 gap-2">
        <FilterTile href="/annonces" label="Toutes" active={!activeType} />
        {POST_TYPES.map((cat) => (
          <FilterTile
            key={cat.type}
            href={`/annonces?type=${cat.type}`}
            image={`/categories/${cat.type}.png`}
            active={activeType === cat.type}
          />
        ))}
      </div>

      {error && (
        <p className="text-sm text-corail">
          Impossible de charger les annonces pour le moment.
        </p>
      )}

      {!error && posts?.length === 0 && (
        <div className="mt-6 rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">
            Aucune annonce {activeType ? `dans cette catégorie` : ''} pour l'instant.
          </p>
          <p className="mt-1 text-sm text-content-secondary">
            Sois le premier à publier quelque chose dans ton quartier !
          </p>
          <Link
            href={activeType ? `/new?type=${activeType}` : '/new'}
            className="mt-4 inline-block h-tap rounded-pill bg-corail px-6 py-3 font-medium text-white transition-fast hover:bg-corail-hover"
          >
            Publier une annonce
          </Link>
        </div>
      )}

      <div className="flex flex-col gap-3">
        {posts?.map((post) => {
          const typeInfo = getPostTypeInfo(post.type);
          const thumbnail = thumbnailByPost[post.id] || getPlaceholderImage(post.type);
          const author = authorInfo[post.user_id];
          const isOwnPost = post.user_id === user.id;
          const favCount = favoriteCounts[post.id] || 0;

          return (
            <div
              key={post.id}
              className="flex gap-3 rounded-card border border-border bg-surface-card p-3 shadow-soft"
            >
              <Link href={`/annonces/${post.id}`} className="h-20 w-20 flex-shrink-0 overflow-hidden rounded-card bg-surface">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={thumbnail} alt="" className="h-full w-full object-cover" />
              </Link>

              <div className="min-w-0 flex-1">
                <div className="flex items-center justify-between gap-2">
                  <Link href={`/annonces/${post.id}`} className="flex min-w-0 items-center gap-1.5">
                    <div className="flex h-5 w-5 flex-shrink-0 items-center justify-center overflow-hidden rounded-pill bg-corail/10 text-[9px] font-semibold text-corail">
                      {author?.photo_visible && author?.photo_url ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={author.photo_url} alt="" className="h-full w-full object-cover" />
                      ) : (
                        (author?.display_name || '?').charAt(0).toUpperCase()
                      )}
                    </div>
                    <span className="truncate text-xs font-medium text-content-secondary">
                      {author?.display_name || 'Voisin'} · {formatRelativeTime(post.created_at)}
                    </span>
                  </Link>
                  <PostCardMenu postId={post.id} isOwnPost={isOwnPost} />
                </div>

                <Link href={`/annonces/${post.id}`}>
                  <p className="mt-1 truncate font-semibold text-content-primary">{post.title}</p>
                  {post.description && (
                    <p className="mt-0.5 line-clamp-2 text-sm text-content-secondary">
                      {post.description}
                    </p>
                  )}
                </Link>

                <div className="mt-2 flex items-center justify-between gap-2">
                  <div className="flex min-w-0 items-center gap-1.5">
                    <span className="flex-shrink-0 rounded-pill bg-surface px-2 py-0.5 text-[11px] font-medium text-content-secondary">
                      {typeInfo.label}
                    </span>
                    {post.approx_zone && (
                      <span className="truncate text-[11px] text-content-secondary">
                        {post.approx_zone}
                      </span>
                    )}
                  </div>
                  {favCount > 0 && (
                    <span className="flex flex-shrink-0 items-center gap-1 text-xs text-content-secondary">
                      <Heart size={13} />
                      {favCount}
                    </span>
                  )}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function FilterTile({ href, label, image, active }) {
  return (
    <Link
      href={href}
      className={`relative overflow-hidden rounded-card transition-fast ${
        active ? 'ring-2 ring-corail ring-offset-2 ring-offset-surface' : ''
      }`}
    >
      {image ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={image} alt={label} className="aspect-square w-full object-cover" />
      ) : (
        <div
          className={`flex aspect-square w-full items-center justify-center text-sm font-semibold ${
            active ? 'bg-corail text-white' : 'bg-surface-card text-content-primary'
          }`}
        >
          Toutes
        </div>
      )}
    </Link>
  );
}


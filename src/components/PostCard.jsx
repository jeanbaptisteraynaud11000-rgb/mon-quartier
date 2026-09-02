import Link from 'next/link';
import { MessageCircle } from 'lucide-react';
import { getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';
import { getPlaceholderImage } from '@/lib/placeholderImages';
import FavoriteHeartButton from './FavoriteHeartButton';
import PostDistanceBadge from './PostDistanceBadge';
import VerifiedBadge from './VerifiedBadge';
import PostCardMenu from '@/app/annonces/PostCardMenu';

// Composant serveur : pas d'état, juste de l'affichage. Le cœur favori et
// le menu ⋮ sont des petits composants client importés séparément.

export default function PostCard({ post, thumbnail, author, msgCount = 0, isOwnPost, showMenu = false }) {
  const typeInfo = getPostTypeInfo(post.type);
  const image = thumbnail || getPlaceholderImage(post.type);

  return (
    <div className="overflow-hidden rounded-card bg-surface-card p-2 shadow-soft">
      <Link href={`/annonces/${post.id}`} className="block">
        <div className="relative h-24 w-full overflow-hidden rounded-card bg-surface sm:h-32">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={image} alt="" className="h-full w-full object-cover" />
          {post.reserved && (
            <span className="absolute left-2 top-2 rounded-pill bg-amber-100 px-2 py-0.5 text-[10px] font-semibold text-amber-700">
              Réservé
            </span>
          )}
          <PostDistanceBadge lat={post.lat} lng={post.lng} />
          <FavoriteHeartButton postId={post.id} />
        </div>
      </Link>

      <div className="mt-2 flex items-start justify-between gap-1">
        <span className="inline-block rounded-pill bg-surface px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-content-secondary">
          {typeInfo.label}
        </span>
        {showMenu && <PostCardMenu postId={post.id} isOwnPost={isOwnPost} reserved={post.reserved} />}
      </div>

      <Link href={`/annonces/${post.id}`} className="block">
        <p className="mt-1 line-clamp-2 text-sm font-medium text-content-primary">
          {post.title}
        </p>

        <div className="mt-1 flex items-center gap-1.5">
          <div className="flex h-[18px] w-[18px] flex-shrink-0 items-center justify-center overflow-hidden rounded-pill bg-corail/10 text-[8px] font-semibold text-corail">
            {author?.photo_visible && author?.photo_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={author.photo_url} alt="" className="h-full w-full object-cover" />
            ) : (
              (author?.display_name || '?').charAt(0).toUpperCase()
            )}
          </div>
          <span className="truncate text-[11px] text-content-secondary">
            {author?.display_name || 'Voisin'}
          </span>
          {author?.verification_status === 'verified' && <VerifiedBadge size={11} />}
        </div>

        <div className="mt-1 flex items-center justify-between text-[11px] text-content-secondary">
          <span>{formatRelativeTime(post.created_at)}</span>
          {msgCount > 0 && (
            <span className="flex items-center gap-0.5">
              <MessageCircle size={11} />
              {msgCount}
            </span>
          )}
        </div>
      </Link>
    </div>
  );
}


// Server Component : liste des annonces du quartier de l'utilisateur,
// filtrable par type via ?type=don|entraide|covoiturage|cherche|alerte.
// Grille 2 colonnes, même style de carte que l'accueil.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { POST_TYPES } from '@/lib/postTypes';
import PostCard from '@/components/PostCard';
import { Map } from 'lucide-react';

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
    .select('id, type, title, description, approx_zone, created_at, user_id, reserved, lat, lng')
    .eq('quartier_id', profile.quartier_id)
    .eq('status', 'active')
    .order('created_at', { ascending: false })
    .limit(30);

  if (activeType) {
    query = query.eq('type', activeType);
  }

  const { data: posts, error } = await query;

  let authorInfo = {};
  let thumbnailByPost = {};
  let conversationCounts = {};
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
      supabase.rpc('get_conversation_counts', { p_post_ids: postIds }),
    ]);

    authorInfo = Object.fromEntries((authors || []).map((a) => [a.user_id, a]));

    for (const img of images || []) {
      if (!thumbnailByPost[img.post_id]) {
        thumbnailByPost[img.post_id] = supabase.storage.from('posts').getPublicUrl(img.storage_path).data.publicUrl;
      }
    }

    conversationCounts = Object.fromEntries((counts || []).map((c) => [c.post_id, c.count]));
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      {/* Filtres de catégorie */}
      <Link
        href="/carte"
        className="flex items-center justify-center gap-1.5 rounded-pill border border-border bg-surface-card py-2 text-sm font-medium text-content-primary transition-fast hover:bg-border/20"
      >
        <Map size={15} /> Voir sur la carte
      </Link>

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

      <div className="grid grid-cols-2 gap-3">
        {posts?.map((post) => (
          <PostCard
            key={post.id}
            post={post}
            thumbnail={thumbnailByPost[post.id]}
            author={authorInfo[post.user_id]}
            msgCount={conversationCounts[post.id] || 0}
            isOwnPost={post.user_id === user.id}
            showMenu
          />
        ))}
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


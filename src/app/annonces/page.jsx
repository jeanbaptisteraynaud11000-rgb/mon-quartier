// Server Component : liste des annonces du quartier de l'utilisateur,
// filtrable par type via ?type=don|entraide|covoiturage|cherche|alerte.

import Link from 'next/link';
import Image from 'next/image';
import { createClient } from '@/lib/supabase/server';
import { POST_TYPES, getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';

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
    .select('id, type, title, description, created_at, user_id')
    .eq('quartier_id', profile.quartier_id)
    .eq('status', 'active')
    .order('created_at', { ascending: false })
    .limit(30);

  if (activeType) {
    query = query.eq('type', activeType);
  }

  const { data: posts, error } = await query;

  // Requêtes séparées : pas de clé étrangère directe posts → profiles, et
  // on récupère seulement la 1ère photo de chaque annonce pour la vignette.
  let authorNames = {};
  let thumbnailByPost = {};
  if (posts?.length > 0) {
    const userIds = [...new Set(posts.map((p) => p.user_id))];
    const postIds = posts.map((p) => p.id);

    const [{ data: authors }, { data: images }] = await Promise.all([
      supabase.from('profiles').select('user_id, display_name').in('user_id', userIds),
      supabase
        .from('post_images')
        .select('post_id, storage_path, position')
        .in('post_id', postIds)
        .order('position', { ascending: true }),
    ]);

    authorNames = Object.fromEntries((authors || []).map((a) => [a.user_id, a.display_name]));

    for (const img of images || []) {
      if (!thumbnailByPost[img.post_id]) {
        thumbnailByPost[img.post_id] = supabase.storage.from('posts').getPublicUrl(img.storage_path).data.publicUrl;
      }
    }
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      {/* Filtres de catégorie */}
      <div className="flex gap-2 overflow-x-auto pb-1">
        <FilterPill href="/annonces" label="Toutes" active={!activeType} />
        {POST_TYPES.map((cat) => (
          <FilterPill
            key={cat.type}
            href={`/annonces?type=${cat.type}`}
            label={cat.label}
            icon={cat.icon}
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
          const Icon = typeInfo.icon;
          const thumbnail = thumbnailByPost[post.id];
          return (
            <Link
              key={post.id}
              href={`/annonces/${post.id}`}
              className="flex gap-3 rounded-card border border-border bg-surface-card p-4 shadow-soft transition-fast hover:bg-border/30 active:scale-[0.99]"
            >
              {thumbnail ? (
                <div className="relative h-14 w-14 flex-shrink-0 overflow-hidden rounded-card bg-surface">
                  <Image src={thumbnail} alt="" fill sizes="56px" className="object-cover" />
                </div>
              ) : (
                <div className="flex h-14 w-14 flex-shrink-0 items-center justify-center rounded-card bg-surface text-content-primary">
                  <Icon size={22} />
                </div>
              )}
              <div className="min-w-0 flex-1">
                <div className="flex items-center justify-between gap-2">
                  <span className="truncate text-sm font-medium text-content-secondary">
                    {authorNames[post.user_id] || 'Voisin'}
                  </span>
                  <span className="flex-shrink-0 text-xs text-content-secondary">
                    {formatRelativeTime(post.created_at)}
                  </span>
                </div>
                <p className="mt-0.5 truncate font-semibold text-content-primary">
                  {post.title}
                </p>
                {post.description && (
                  <p className="mt-0.5 line-clamp-2 text-sm text-content-secondary">
                    {post.description}
                  </p>
                )}
              </div>
            </Link>
          );
        })}
      </div>
    </div>
  );
}

function FilterPill({ href, label, icon: Icon, active }) {
  return (
    <Link
      href={href}
      className={`flex flex-shrink-0 items-center gap-1.5 rounded-pill border px-4 py-2 text-sm font-medium transition-fast ${
        active
          ? 'border-corail bg-corail text-white'
          : 'border-border bg-surface text-content-primary hover:bg-surface-card'
      }`}
    >
      {Icon && <Icon size={14} />}
      {label}
    </Link>
  );
}


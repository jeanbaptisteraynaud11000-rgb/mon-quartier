// Server Component : liste des annonces du quartier de l'utilisateur,
// filtrable par type via ?type=don|entraide|covoiturage|cherche.

import Link from 'next/link';
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

  // Requête séparée pour récupérer les noms des auteurs (pas de clé
  // étrangère directe entre posts et profiles, voir /annonces/[id]).
  let authorNames = {};
  if (posts?.length > 0) {
    const userIds = [...new Set(posts.map((p) => p.user_id))];
    const { data: authors } = await supabase
      .from('profiles')
      .select('user_id, display_name')
      .in('user_id', userIds);
    authorNames = Object.fromEntries((authors || []).map((a) => [a.user_id, a.display_name]));
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
            label={`${cat.emoji} ${cat.label}`}
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
          return (
            <Link
              key={post.id}
              href={`/annonces/${post.id}`}
              className="flex gap-3 rounded-card border border-border bg-surface-card p-4 shadow-soft transition-fast hover:bg-border/30 active:scale-[0.99]"
            >
              <div className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-pill bg-surface text-lg">
                {typeInfo.emoji}
              </div>
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

function FilterPill({ href, label, active }) {
  return (
    <Link
      href={href}
      className={`flex-shrink-0 rounded-pill border px-4 py-2 text-sm font-medium transition-fast ${
        active
          ? 'border-corail bg-corail text-white'
          : 'border-border bg-surface text-content-primary hover:bg-surface-card'
      }`}
    >
      {label}
    </Link>
  );
}


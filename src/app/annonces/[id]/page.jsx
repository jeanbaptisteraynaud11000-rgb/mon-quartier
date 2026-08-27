// Server Component : détail d'une annonce. La policy RLS "posts_select_own_quartier"
// garantit déjà qu'on ne peut pas voir l'annonce d'un autre quartier — si
// jamais quelqu'un force une URL /annonces/[id] hors de son quartier, la
// requête retourne simplement "non trouvé", jamais les données.

import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';
import ContactActions from './ContactActions';

export default async function AnnonceDetailPage({ params }) {
  const { id } = await params;
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: post, error } = await supabase
    .from('posts')
    .select('id, type, title, description, availability, approx_zone, created_at, user_id, profiles(display_name)')
    .eq('id', id)
    .single();

  if (error || !post) {
    notFound();
  }

  const typeInfo = getPostTypeInfo(post.type);
  const isOwnPost = post.user_id === user.id;

  // Autres annonces du même auteur (hors celle-ci)
  const { data: otherPosts } = await supabase
    .from('posts')
    .select('id, title, type')
    .eq('user_id', post.user_id)
    .eq('status', 'active')
    .neq('id', post.id)
    .limit(3);

  return (
    <div className="flex flex-col gap-5 p-4">
      <Link href="/annonces" className="text-sm font-medium text-content-secondary">
        ← Retour aux annonces
      </Link>

      <div className="rounded-card border border-border bg-surface-card p-5">
        <div className="flex items-center gap-2">
          <span className="text-xl">{typeInfo.emoji}</span>
          <span className="text-sm font-medium text-content-secondary">{typeInfo.label}</span>
        </div>

        <h1 className="mt-3 text-xl font-semibold text-content-primary">{post.title}</h1>

        <div className="mt-2 flex items-center gap-2 text-sm text-content-secondary">
          <span>{post.profiles?.display_name || 'Voisin'}</span>
          <span>·</span>
          <span>{formatRelativeTime(post.created_at)}</span>
        </div>

        {post.description && (
          <p className="mt-4 whitespace-pre-wrap text-content-primary">{post.description}</p>
        )}

        {post.availability && (
          <p className="mt-3 text-sm text-content-secondary">
            <span className="font-medium text-content-primary">Disponibilité : </span>
            {post.availability}
          </p>
        )}

        {post.approx_zone && (
          <p className="mt-1 text-sm text-content-secondary">
            <span className="font-medium text-content-primary">Zone : </span>
            {post.approx_zone}
          </p>
        )}
      </div>

      {!isOwnPost && <ContactActions postId={post.id} postTitle={post.title} />}

      {isOwnPost && (
        <div className="rounded-card border border-border bg-surface-card p-4 text-center text-sm text-content-secondary">
          C'est ta propre annonce.{' '}
          <Link href="/mes-annonces" className="font-medium text-corail">
            Gérer mes annonces
          </Link>
        </div>
      )}

      {otherPosts?.length > 0 && (
        <div>
          <h2 className="mb-2 text-sm font-medium text-content-secondary">
            Autres annonces de {post.profiles?.display_name || 'ce voisin'}
          </h2>
          <div className="flex flex-col gap-2">
            {otherPosts.map((op) => (
              <Link
                key={op.id}
                href={`/annonces/${op.id}`}
                className="rounded-card border border-border bg-surface-card p-3 text-sm text-content-primary transition-fast hover:bg-border/30"
              >
                {getPostTypeInfo(op.type).emoji} {op.title}
              </Link>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}


// Server Component : détail d'une annonce. La policy RLS
// "posts_select_own_quartier" garantit déjà qu'on ne peut pas voir
// l'annonce d'un autre quartier.
//
// NOTE DE PORTÉE : plusieurs éléments d'inspiration (notes/avis, "% de
// prêts honorés", historique d'emprunts, réservation avec calendrier) ne
// sont pas construits — ce sont de vraies fonctionnalités à part entière,
// pas juste de la mise en page. Ce qui est affiché ici reflète toujours de
// vraies données.

import Link from 'next/link';
import Image from 'next/image';
import { notFound } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';
import { getPlaceholderImage } from '@/lib/placeholderImages';
import { getLevel } from '@/lib/levels';
import VerifiedBadge from '@/components/VerifiedBadge';
import PostHeaderActions from './PostHeaderActions';
import ContactActions from './ContactActions';

export default async function AnnonceDetailPage({ params }) {
  const { id } = await params;
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: post, error } = await supabase
    .from('posts')
    .select('id, type, title, description, availability, approx_zone, created_at, user_id, reserved, lat, lng, loan_type, item_condition, brand_model, loan_duration, deposit_required, pickup_preference, show_phone, extra_notes')
    .eq('id', id)
    .single();

  if (error || !post) {
    notFound();
  }

  const { data: authorProfile } = await supabase
    .from('profiles')
    .select('display_name, points, photo_url, photo_visible, verification_status, phone')
    .eq('user_id', post.user_id)
    .single();

  const { data: images } = await supabase
    .from('post_images')
    .select('storage_path, position')
    .eq('post_id', post.id)
    .order('position', { ascending: true });

  const photoUrls = (images || []).map(
    (img) => supabase.storage.from('posts').getPublicUrl(img.storage_path).data.publicUrl
  );
  const heroImage = photoUrls[0] || getPlaceholderImage(post.type);

  const typeInfo = getPostTypeInfo(post.type);
  const isOwnPost = post.user_id === user.id;
  const authorName = authorProfile?.display_name || 'Voisin';
  const authorInitial = authorName.charAt(0).toUpperCase();
  const level = getLevel(authorProfile?.points || 0);

  const { data: otherPosts } = await supabase
    .from('posts')
    .select('id, title, type')
    .eq('user_id', post.user_id)
    .eq('status', 'active')
    .neq('id', post.id)
    .limit(3);

  return (
    <div className="flex flex-col gap-5 pb-4">
      {/* Photo pleine largeur avec retour/favori/partage en overlay */}
      <div className="relative h-72 w-full">
        <Image src={heroImage} alt="" fill sizes="100vw" className="object-cover" priority />
        {post.reserved && (
          <span className="absolute left-3 top-14 rounded-pill bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-700 shadow-soft">
            Réservé
          </span>
        )}
        <PostHeaderActions postId={post.id} postTitle={post.title} />
      </div>

      <div className="flex flex-col gap-5 px-4">
        <div>
          <span className="inline-block rounded-pill bg-surface-card px-3 py-1 text-xs font-semibold uppercase tracking-wide text-content-secondary">
            {typeInfo.label}
          </span>
          <h1 className="mt-2 text-xl font-semibold text-content-primary">{post.title}</h1>
          {post.description && (
            <p className="mt-1 text-sm text-content-secondary">{post.description}</p>
          )}
        </div>

        {/* Auteur + niveau (factuel, pas de note/avis — pas de systeme de notation) */}
        <Link
          href={isOwnPost ? '/profile' : '#'}
          className="flex items-center gap-3 rounded-card border border-border bg-surface-card p-3"
        >
          <div className="flex h-11 w-11 flex-shrink-0 items-center justify-center overflow-hidden rounded-pill bg-corail/10 font-semibold text-corail">
            {authorProfile?.photo_visible && authorProfile?.photo_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={authorProfile.photo_url} alt="" className="h-full w-full object-cover" />
            ) : (
              authorInitial
            )}
          </div>
          <div className="min-w-0 flex-1">
            <p className="flex items-center gap-1 font-medium text-content-primary">
              {authorName}
              {authorProfile?.verification_status === 'verified' && <VerifiedBadge />}
            </p>
            <p className="text-xs text-content-secondary">{level.label}</p>
          </div>
        </Link>

        {/* Infos structurées — uniquement des champs réels */}
        {(post.availability || post.approx_zone) && (
          <div className="grid grid-cols-2 gap-3 rounded-card border border-border bg-surface-card p-4">
            {post.availability && (
              <div>
                <p className="text-xs text-content-secondary">Disponibilité</p>
                <p className="mt-0.5 text-sm font-medium text-content-primary">{post.availability}</p>
              </div>
            )}
            {post.approx_zone && (
              <div>
                <p className="text-xs text-content-secondary">Zone</p>
                <p className="mt-0.5 text-sm font-medium text-content-primary">{post.approx_zone}</p>
              </div>
            )}
            <div>
              <p className="text-xs text-content-secondary">Publié</p>
              <p className="mt-0.5 text-sm font-medium text-content-primary">
                {formatRelativeTime(post.created_at)}
              </p>
            </div>
          </div>
        )}

        {/* Détails Prêt/Don — uniquement si ce type et au moins un champ rempli */}
        {post.type === 'don' && (post.item_condition || post.brand_model || post.loan_duration || post.deposit_required || post.pickup_preference) && (
          <div className="rounded-card border border-border bg-surface-card p-4">
            <h2 className="mb-2 text-sm font-semibold text-content-primary">
              {post.loan_type === 'don' ? 'Détails du don' : 'Détails du prêt'}
            </h2>
            <div className="grid grid-cols-2 gap-3">
              {post.item_condition && (
                <div>
                  <p className="text-xs text-content-secondary">État</p>
                  <p className="mt-0.5 text-sm font-medium text-content-primary">
                    {{ neuf: 'Neuf', tres_bon: 'Très bon', bon: 'Bon', a_reparer: 'À réparer' }[post.item_condition]}
                  </p>
                </div>
              )}
              {post.brand_model && (
                <div>
                  <p className="text-xs text-content-secondary">Marque / modèle</p>
                  <p className="mt-0.5 text-sm font-medium text-content-primary">{post.brand_model}</p>
                </div>
              )}
              {post.loan_type === 'pret' && post.loan_duration && (
                <div>
                  <p className="text-xs text-content-secondary">Durée du prêt</p>
                  <p className="mt-0.5 text-sm font-medium text-content-primary">
                    {{ '1_a_3_jours': '1 à 3 jours', '1_semaine': '1 semaine', flexible: 'Flexible' }[post.loan_duration]}
                  </p>
                </div>
              )}
              {post.loan_type === 'pret' && (
                <div>
                  <p className="text-xs text-content-secondary">Caution</p>
                  <p className="mt-0.5 text-sm font-medium text-content-primary">
                    {post.deposit_required ? 'Oui' : 'Aucune'}
                  </p>
                </div>
              )}
              {post.pickup_preference && (
                <div>
                  <p className="text-xs text-content-secondary">Remise</p>
                  <p className="mt-0.5 text-sm font-medium text-content-primary">
                    {post.pickup_preference === 'chez_moi' ? 'Chez le propriétaire' : 'Peut se déplacer'}
                  </p>
                </div>
              )}
            </div>
            {post.extra_notes && (
              <p className="mt-3 border-t border-border pt-3 text-sm text-content-secondary">
                {post.extra_notes}
              </p>
            )}
            {post.show_phone && authorProfile?.phone && (
              <a
                href={`tel:${authorProfile.phone}`}
                className="mt-3 block border-t border-border pt-3 text-sm font-medium text-corail"
              >
                📞 {authorProfile.phone}
              </a>
            )}
          </div>
        )}

        {!isOwnPost && (
          <>
            {post.reserved && (
              <p className="text-center text-xs text-amber-700">
                Cette annonce a été marquée comme réservée — tu peux quand même contacter au
                cas où ça ne se concrétiserait pas.
              </p>
            )}
            <ContactActions postId={post.id} postAuthorId={post.user_id} />
          </>
        )}

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
              Autres annonces de {authorName}
            </h2>
            <div className="flex flex-col gap-2">
              {otherPosts.map((op) => {
                const OpIcon = getPostTypeInfo(op.type).icon;
                return (
                  <Link
                    key={op.id}
                    href={`/annonces/${op.id}`}
                    className="flex items-center gap-2 rounded-card border border-border bg-surface-card p-3 text-sm text-content-primary transition-fast hover:bg-border/30"
                  >
                    <OpIcon size={16} /> {op.title}
                  </Link>
                );
              })}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}


#!/usr/bin/env bash
set -e
echo "Ajout de couleur et d'ombres douces sur l'accueil..."

mkdir -p "src/app"
cat > "src/app/page.jsx" << 'MQEOF_SRC_APP_PAGE_JSX'
// Page d'accueil — Server Component.
//
// Direction visuelle : structure épurée façon Airbnb (grandes zones photo,
// hiérarchie typographique nette, beaucoup d'espace), mais avec un peu plus
// de couleur et de relief qu'en V1 — icônes de catégories teintées
// corail/vert avec une ombre douce, cartes légèrement surélevées
// (shadow-soft, déjà dans le design system depuis le début).
//
// Volontairement exclu (cohérent avec la section 80 du prompt maître) :
// pas de "vu par X personnes", pas de tri algorithmique par popularité,
// pas de notification-appât. Le fil reste chronologique, l'app reste utile
// plutôt qu'accrocheuse.

import Link from 'next/link';
import { Search, Users, Store } from 'lucide-react';
import { createClient } from '@/lib/supabase/server';
import { POST_TYPES, getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';
import { getEventCategoryInfo, formatEventDate } from '@/lib/eventCategories';

export default async function HomePage() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: profile } = await supabase
    .from('profiles')
    .select('display_name, quartier_id, quartiers(name, city)')
    .eq('user_id', user.id)
    .single();

  if (!profile?.quartier_id) {
    return (
      <div className="p-4">
        <div className="rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">
            Il te reste une étape avant de découvrir ton quartier.
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

  const quartierId = profile.quartier_id;
  const firstName = profile.display_name?.split(' ')[0] || null;

  const [neighborsCount, featuredAlertResult, feedResult, upcomingEventsResult] = await Promise.all([
    supabase
      .from('profiles')
      .select('*', { count: 'exact', head: true })
      .eq('quartier_id', quartierId),
    supabase
      .from('posts')
      .select('id, title, created_at, user_id')
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .eq('type', 'alerte')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle(),
    supabase
      .from('posts')
      .select('id, type, title, created_at, user_id')
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .neq('type', 'alerte')
      .order('created_at', { ascending: false })
      .limit(4),
    supabase
      .from('events')
      .select('id, category, title, event_date, max_attendees')
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .gte('event_date', new Date().toISOString())
      .order('event_date', { ascending: true })
      .limit(4),
  ]);

  const featuredAlert = featuredAlertResult.data;
  const feed = feedResult.data || [];
  const upcomingEvents = upcomingEventsResult.data || [];

  // Requêtes séparées : pas de FK directe posts/events → profiles, et on
  // récupère la 1ère photo de chaque annonce pour l'illustration de carte.
  const relevantUserIds = [
    ...new Set([featuredAlert?.user_id, ...feed.map((p) => p.user_id)].filter(Boolean)),
  ];
  const feedPostIds = feed.map((p) => p.id);

  const [{ data: authors }, { data: images }, { data: attendees }] = await Promise.all([
    relevantUserIds.length > 0
      ? supabase.from('profiles').select('user_id, display_name').in('user_id', relevantUserIds)
      : Promise.resolve({ data: [] }),
    feedPostIds.length > 0
      ? supabase.from('post_images').select('post_id, storage_path, position').in('post_id', feedPostIds).order('position', { ascending: true })
      : Promise.resolve({ data: [] }),
    upcomingEvents.length > 0
      ? supabase.from('event_attendees').select('event_id').in('event_id', upcomingEvents.map((e) => e.id))
      : Promise.resolve({ data: [] }),
  ]);

  const authorName = Object.fromEntries((authors || []).map((a) => [a.user_id, a.display_name]));

  const thumbnailByPost = {};
  for (const img of images || []) {
    if (!thumbnailByPost[img.post_id]) {
      thumbnailByPost[img.post_id] = supabase.storage.from('posts').getPublicUrl(img.storage_path).data.publicUrl;
    }
  }

  const attendeeCounts = {};
  for (const a of attendees || []) {
    attendeeCounts[a.event_id] = (attendeeCounts[a.event_id] || 0) + 1;
  }

  return (
    <div className="flex flex-col p-4">
      <h1 className="text-xl font-semibold text-content-primary">
        {firstName ? `Bonjour ${firstName}` : 'Bonjour'}
      </h1>
      <p className="mt-1 text-sm text-content-secondary">
        Voici ce qui se passe près de chez toi.
      </p>

      {/* Barre de recherche — pour l'instant amène simplement aux annonces ;
          une vraie recherche (annonces + voisins) est prévue dans un
          prochain chantier (section 46 du prompt maître). */}
      <Link
        href="/annonces"
        className="mt-5 flex items-center gap-3 rounded-pill border border-border bg-surface-card px-4 py-3 shadow-soft transition-fast hover:shadow-none"
      >
        <Search size={17} className="text-content-secondary" />
        <span className="text-sm text-content-secondary">Rechercher dans le quartier</span>
      </Link>

      {/* Catégories — icônes teintées corail/vert, légère ombre */}
      <div className="-mx-4 mt-6 flex gap-5 overflow-x-auto px-4 pb-1">
        {POST_TYPES.map((cat, i) => {
          const Icon = cat.icon;
          const tint = i % 2 === 0 ? 'bg-corail/10 text-corail' : 'bg-vert/10 text-vert';
          return (
            <Link
              key={cat.type}
              href={`/annonces?type=${cat.type}`}
              className="flex flex-shrink-0 flex-col items-center gap-2 transition-fast active:scale-95"
            >
              <div className={`flex h-12 w-12 items-center justify-center rounded-pill shadow-soft ${tint}`}>
                <Icon size={20} />
              </div>
              <span className="text-xs font-medium text-content-primary">{cat.label}</span>
            </Link>
          );
        })}
      </div>

      {/* Alerte la plus récente — pleine largeur, mise en avant */}
      {featuredAlert && (
        <Link
          href={`/annonces/${featuredAlert.id}`}
          className="mt-6 flex items-start gap-3 rounded-card bg-amber-50 p-4 shadow-soft transition-fast hover:shadow-none"
        >
          <div className="mt-0.5 flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-pill bg-amber-100 text-amber-700">
            {(() => {
              const AlertIcon = getPostTypeInfo('alerte').icon;
              return <AlertIcon size={16} />;
            })()}
          </div>
          <div className="min-w-0">
            <p className="text-sm font-medium text-content-primary">{featuredAlert.title}</p>
            <p className="mt-0.5 text-xs text-content-secondary">
              Signalé par {authorName[featuredAlert.user_id] || 'un voisin'} ·{' '}
              {formatRelativeTime(featuredAlert.created_at)}
            </p>
          </div>
        </Link>
      )}

      {/* Fil "Près de chez toi" — même format carte que les activités */}
      {feed.length > 0 && (
        <section className="mt-8">
          <div className="mb-3 flex items-baseline justify-between">
            <h2 className="text-base font-semibold text-content-primary">Près de chez toi</h2>
          </div>

          <div className="grid grid-cols-2 gap-3">
            {feed.map((post, i) => {
              const typeInfo = getPostTypeInfo(post.type);
              const Icon = typeInfo.icon;
              const thumbnail = thumbnailByPost[post.id];
              const tint = i % 2 === 0 ? 'bg-corail/10 text-corail' : 'bg-vert/10 text-vert';
              return (
                <Link key={post.id} href={`/annonces/${post.id}`}>
                  <div className="relative h-24 w-full overflow-hidden rounded-card bg-surface-card shadow-soft">
                    {thumbnail ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={thumbnail} alt="" className="h-full w-full object-cover" />
                    ) : (
                      <div className={`flex h-full w-full items-center justify-center ${tint}`}>
                        <Icon size={24} />
                      </div>
                    )}
                  </div>
                  <p className="mt-2 line-clamp-2 text-sm font-medium text-content-primary">
                    {post.title}
                  </p>
                  <p className="mt-0.5 text-xs text-content-secondary">
                    {authorName[post.user_id] || 'Voisin'} · {formatRelativeTime(post.created_at)}
                  </p>
                </Link>
              );
            })}
          </div>

          <Link
            href="/annonces"
            className="mt-4 block w-full rounded-pill border border-border py-2.5 text-center text-sm font-medium text-content-primary transition-fast hover:border-content-secondary"
          >
            Voir plus
          </Link>
        </section>
      )}

      {feed.length === 0 && !featuredAlert && (
        <div className="mt-8 rounded-card border border-border bg-surface-card p-6 text-center text-sm text-content-secondary">
          Rien de nouveau pour l'instant.
          <div className="mt-2">
            <Link href="/new" className="font-medium text-corail">
              Sois le premier à publier →
            </Link>
          </div>
        </div>
      )}

      {/* Prochaines activités */}
      {upcomingEvents.length > 0 && (
        <section className="mt-8">
          <div className="mb-3 flex items-baseline justify-between">
            <h2 className="text-base font-semibold text-content-primary">Prochaines activités</h2>
            <Link href="/activites" className="text-xs text-content-secondary">
              Tout voir
            </Link>
          </div>

          <div className="-mx-4 flex gap-3 overflow-x-auto px-4 pb-1">
            {upcomingEvents.map((event) => {
              const catInfo = getEventCategoryInfo(event.category);
              const Icon = catInfo.icon;
              const count = attendeeCounts[event.id] || 0;
              const isFull = count >= event.max_attendees;
              return (
                <Link key={event.id} href={`/activites/${event.id}`} className="w-40 flex-shrink-0">
                  <div className="flex h-24 w-full items-center justify-center rounded-card bg-vert/10 text-vert shadow-soft">
                    <Icon size={24} />
                  </div>
                  <p className="mt-2 line-clamp-2 text-sm font-medium text-content-primary">
                    {event.title}
                  </p>
                  <p className={`mt-0.5 text-xs ${isFull ? 'text-corail' : 'text-content-secondary'}`}>
                    {formatEventDate(event.event_date)} · {isFull ? 'Complet' : `${count}/${event.max_attendees}`}
                  </p>
                </Link>
              );
            })}
          </div>
        </section>
      )}

      <Link
        href="/commerces"
        className="mt-3 flex items-center justify-between rounded-card border border-border bg-surface-card p-4 shadow-soft transition-fast hover:shadow-none"
      >
        <div className="flex items-center gap-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-pill bg-corail/10 text-corail">
            <Store size={17} />
          </div>
          <span className="text-sm text-content-primary">Commerces & lieux du quartier</span>
        </div>
        <span className="text-xs text-content-secondary">Voir</span>
      </Link>

      <Link
        href="/voisins"
        className="mt-3 flex items-center justify-between rounded-card border border-border bg-surface-card p-4 shadow-soft transition-fast hover:shadow-none"
      >
        <div className="flex items-center gap-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-pill bg-vert/10 text-vert">
            <Users size={17} />
          </div>
          <span className="text-sm text-content-primary">
            {neighborsCount.count ?? 0} voisin{(neighborsCount.count ?? 0) > 1 ? 's' : ''} dans ce quartier
          </span>
        </div>
        <span className="text-xs text-content-secondary">Voir</span>
      </Link>
    </div>
  );
}

MQEOF_SRC_APP_PAGE_JSX

echo "Couleur et ombres ajoutees avec succes."
echo "Prochaine etape : git add -A && git commit -m \"accueil : couleur + ombres douces\" && git push"
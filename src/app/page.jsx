// Page d'accueil — Server Component.
//
// Direction visuelle : pastilles de catégories pleinement colorées,
// cartes horizontales avec vraies photos (illustration générique en
// secours), pile d'avatars pour les activités et les voisins.
//
// Volontairement exclu (cohérent avec la section 80 du prompt maître) :
// pas de notation/étoiles (aucun système d'avis n'existe côté base), pas
// de tri algorithmique par popularité, pas de notification-appât.

import Link from 'next/link';
import { Search, Users, Store } from 'lucide-react';
import { createClient } from '@/lib/supabase/server';
import { POST_TYPES, formatRelativeTime } from '@/lib/postTypes';
import { formatEventDate } from '@/lib/eventCategories';
import AvatarStack from '@/components/AvatarStack';
import PostCard from '@/components/PostCard';

function formatEventDateBadge(dateString) {
  const date = new Date(dateString);
  return {
    day: date.toLocaleDateString('fr-FR', { weekday: 'short' }).toUpperCase().replace('.', ''),
    date: date.getDate(),
    month: date.toLocaleDateString('fr-FR', { month: 'short' }).toUpperCase().replace('.', ''),
  };
}

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

  const [neighborsCount, featuredAlertResult, feedResult, upcomingEventsResult, neighborPreviewResult] =
    await Promise.all([
      supabase.from('profiles').select('*', { count: 'exact', head: true }).eq('quartier_id', quartierId),
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
        .select('id, type, title, created_at, user_id, reserved')
        .eq('quartier_id', quartierId)
        .eq('status', 'active')
        .neq('type', 'alerte')
        .order('created_at', { ascending: false })
        .limit(4),
      supabase
        .from('events')
        .select('id, category, title, location, event_date, max_attendees')
        .eq('quartier_id', quartierId)
        .eq('status', 'active')
        .gte('event_date', new Date().toISOString())
        .order('event_date', { ascending: true })
        .limit(3),
      supabase
        .from('profiles')
        .select('user_id, display_name, photo_url, photo_visible')
        .eq('quartier_id', quartierId)
        .neq('map_visibility', 'off')
        .limit(4),
    ]);

  const featuredAlert = featuredAlertResult.data;
  const feed = feedResult.data || [];
  const upcomingEvents = upcomingEventsResult.data || [];
  const neighborPreview = neighborPreviewResult.data || [];

  const relevantUserIds = [
    ...new Set([featuredAlert?.user_id, ...feed.map((p) => p.user_id)].filter(Boolean)),
  ];
  const feedPostIds = feed.map((p) => p.id);
  const eventIds = upcomingEvents.map((e) => e.id);

  const [{ data: authors }, { data: images }, { data: attendeeRows }, { data: convCounts }] = await Promise.all([
    relevantUserIds.length > 0
      ? supabase.from('profiles').select('user_id, display_name, photo_url, photo_visible').in('user_id', relevantUserIds)
      : Promise.resolve({ data: [] }),
    feedPostIds.length > 0
      ? supabase.from('post_images').select('post_id, storage_path, position').in('post_id', feedPostIds).order('position', { ascending: true })
      : Promise.resolve({ data: [] }),
    eventIds.length > 0
      ? supabase.from('event_attendees').select('event_id, user_id').in('event_id', eventIds)
      : Promise.resolve({ data: [] }),
    feedPostIds.length > 0
      ? supabase.rpc('get_conversation_counts', { p_post_ids: feedPostIds })
      : Promise.resolve({ data: [] }),
  ]);

  const authorName = Object.fromEntries((authors || []).map((a) => [a.user_id, a.display_name]));
  const authorPhoto = Object.fromEntries((authors || []).map((a) => [a.user_id, a]));
  const conversationCounts = Object.fromEntries((convCounts || []).map((c) => [c.post_id, c.count]));

  const thumbnailByPost = {};
  for (const img of images || []) {
    if (!thumbnailByPost[img.post_id]) {
      thumbnailByPost[img.post_id] = supabase.storage.from('posts').getPublicUrl(img.storage_path).data.publicUrl;
    }
  }

  // Profils des participants pour la pile d'avatars de chaque activité.
  const attendeeUserIds = [...new Set((attendeeRows || []).map((a) => a.user_id))];
  const { data: attendeeProfiles } =
    attendeeUserIds.length > 0
      ? await supabase.from('profiles').select('user_id, display_name, photo_url, photo_visible').in('user_id', attendeeUserIds)
      : { data: [] };
  const attendeeProfileById = Object.fromEntries((attendeeProfiles || []).map((p) => [p.user_id, p]));

  const attendeesByEvent = {};
  for (const row of attendeeRows || []) {
    if (!attendeesByEvent[row.event_id]) attendeesByEvent[row.event_id] = [];
    const p = attendeeProfileById[row.user_id];
    if (p) attendeesByEvent[row.event_id].push(p);
  }

  return (
    <div className="flex flex-col p-4">
      <h1 className="text-xl font-semibold text-content-primary">
        {firstName ? `Bonjour ${firstName} 👋` : 'Bonjour 👋'}
      </h1>
      <p className="mt-1 text-sm text-content-secondary">
        Ravi de te revoir dans ton quartier.
      </p>

      <Link
        href="/annonces"
        className="mt-5 flex items-center gap-3 rounded-pill border border-border bg-surface-card px-4 py-3 shadow-soft transition-fast hover:shadow-none"
      >
        <Search size={17} className="text-content-secondary" />
        <span className="text-sm text-content-secondary">Rechercher dans le quartier</span>
      </Link>

      {/* Catégories — vraies illustrations, grille 3 colonnes (2 lignes, pas de scroll) */}
      <div className="mt-5 grid grid-cols-3 gap-2.5">
        {POST_TYPES.map((cat) => (
          <Link
            key={cat.type}
            href={`/annonces?type=${cat.type}`}
            className="overflow-hidden rounded-card shadow-soft transition-fast active:scale-95"
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={`/categories/${cat.type}.png`}
              alt={cat.label}
              className="aspect-square w-full object-cover"
            />
          </Link>
        ))}
      </div>

      {/* Alerte la plus récente */}
      {featuredAlert && (
        <Link
          href={`/annonces/${featuredAlert.id}`}
          className="mt-5 flex items-center gap-3 rounded-card bg-corail/10 p-4 shadow-soft transition-fast hover:shadow-none"
        >
          <div className="h-10 w-10 flex-shrink-0 overflow-hidden rounded-pill">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/categories/alerte.png" alt="" className="h-full w-full object-cover" />
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

      {/* Près de chez toi — grille de 3, triée par date de publication */}
      {feed.length > 0 && (
        <section className="mt-7">
          <div className="mb-3 flex items-baseline justify-between">
            <h2 className="text-base font-semibold text-content-primary">Près de chez toi</h2>
            <Link href="/annonces" className="text-xs text-content-secondary">
              Voir tout
            </Link>
          </div>

          <div className="grid grid-cols-2 gap-3">
            {feed.map((post) => (
              <PostCard
                key={post.id}
                post={post}
                thumbnail={thumbnailByPost[post.id]}
                author={authorPhoto[post.user_id]}
                msgCount={conversationCounts[post.id] || 0}
              />
            ))}
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
        <div className="mt-7 rounded-card border border-border bg-surface-card p-6 text-center text-sm text-content-secondary">
          Rien de nouveau pour l'instant.
          <div className="mt-2">
            <Link href="/new" className="font-medium text-corail">
              Sois le premier à publier →
            </Link>
          </div>
        </div>
      )}

      {/* Prochaines activités — badge date + pile de participants */}
      {upcomingEvents.length > 0 && (
        <section className="mt-7">
          <div className="mb-3 flex items-baseline justify-between">
            <h2 className="text-base font-semibold text-content-primary">Prochaines activités</h2>
            <Link href="/activites" className="text-xs text-content-secondary">
              Voir tout
            </Link>
          </div>

          <div className="flex flex-col gap-3">
            {upcomingEvents.map((event) => {
              const badge = formatEventDateBadge(event.event_date);
              const attendees = attendeesByEvent[event.id] || [];
              return (
                <Link
                  key={event.id}
                  href={`/activites/${event.id}`}
                  className="flex gap-3 rounded-card border border-border bg-surface-card p-3 shadow-soft transition-fast hover:shadow-none"
                >
                  <div className="flex h-14 w-14 flex-shrink-0 flex-col items-center justify-center rounded-card bg-surface">
                    <span className="text-[10px] font-medium text-corail">{badge.day}</span>
                    <span className="text-lg font-semibold leading-none text-content-primary">{badge.date}</span>
                    <span className="text-[10px] text-content-secondary">{badge.month}</span>
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-medium text-content-primary">{event.title}</p>
                    <p className="mt-0.5 truncate text-xs text-content-secondary">
                      {new Date(event.event_date).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}
                      {event.location ? ` · ${event.location}` : ''}
                    </p>
                    {attendees.length > 0 && (
                      <div className="mt-1.5">
                        <AvatarStack people={attendees} size={20} />
                      </div>
                    )}
                  </div>
                </Link>
              );
            })}
          </div>
        </section>
      )}

      {/* Résumé communauté — deux cartes avec illustration de fond */}
      <div className="mt-7 grid grid-cols-2 gap-3">
        <Link
          href="/voisins"
          className="relative flex h-32 flex-col justify-end overflow-hidden rounded-card p-3 shadow-soft"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/placeholders/voisins-card.jpg"
            alt=""
            className="absolute inset-0 h-full w-full object-cover"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-black/55 to-transparent" />
          <div className="relative">
            <AvatarStack people={neighborPreview} size={22} />
            <p className="mt-1.5 text-xs font-medium text-white">
              {neighborsCount.count ?? 0} voisins peuvent aider
            </p>
          </div>
        </Link>

        <Link
          href="/commerces"
          className="relative flex h-32 flex-col justify-end overflow-hidden rounded-card p-3 shadow-soft"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/placeholders/commerce-card.jpg"
            alt=""
            className="absolute inset-0 h-full w-full object-cover"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-black/55 to-transparent" />
          <div className="relative flex items-center gap-1.5">
            <Store size={14} className="text-white" />
            <p className="text-xs font-medium text-white">Soutenons nos commerces</p>
          </div>
        </Link>
      </div>
    </div>
  );
}


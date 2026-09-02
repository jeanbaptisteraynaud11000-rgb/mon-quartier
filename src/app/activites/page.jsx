// Server Component : activités à venir du quartier, triées par date,
// filtrable par catégorie via ?category=sortie|musee|sport|jeux_de_societe|autre.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { EVENT_CATEGORIES, getEventCategoryInfo, formatEventDate } from '@/lib/eventCategories';
import { getPlaceholderImage } from '@/lib/placeholderImages';
import PostDistanceBadge from '@/components/PostDistanceBadge';
import EventCardMenu from './EventCardMenu';

export default async function ActivitesPage({ searchParams }) {
  const params = await searchParams;
  const activeCategory = params?.category;

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
            Termine d'abord ton inscription pour voir les activités de ton quartier.
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
    .from('events')
    .select('id, category, title, location, event_date, max_attendees, user_id, photo_url, price_info, lat, lng')
    .eq('quartier_id', profile.quartier_id)
    .eq('status', 'active')
    .gte('event_date', new Date().toISOString())
    .order('event_date', { ascending: true })
    .limit(30);

  if (activeCategory) {
    query = query.eq('category', activeCategory);
  }

  const { data: events, error } = await query;

  let attendeeCounts = {};
  let organizerInfo = {};
  if (events?.length > 0) {
    const [{ data: attendees }, { data: organizers }] = await Promise.all([
      supabase.from('event_attendees').select('event_id').in('event_id', events.map((e) => e.id)),
      supabase
        .from('profiles')
        .select('user_id, display_name, photo_url, photo_visible')
        .in('user_id', [...new Set(events.map((e) => e.user_id))]),
    ]);
    for (const a of attendees || []) {
      attendeeCounts[a.event_id] = (attendeeCounts[a.event_id] || 0) + 1;
    }
    organizerInfo = Object.fromEntries((organizers || []).map((o) => [o.user_id, o]));
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-content-primary">Activités</h1>
        <Link
          href="/activites/new"
          className="rounded-pill bg-corail px-4 py-2 text-sm font-medium text-white transition-fast hover:bg-corail-hover"
        >
          Organiser
        </Link>
      </div>

      {/* Filtres de catégorie — même traitement que /annonces */}
      <div className="grid grid-cols-3 gap-2">
        <FilterTile href="/activites" label="Toutes" active={!activeCategory} />
        {EVENT_CATEGORIES.map((cat) => (
          <FilterTile
            key={cat.category}
            href={`/activites?category=${cat.category}`}
            image={getPlaceholderImage(cat.category)}
            label={cat.label}
            active={activeCategory === cat.category}
          />
        ))}
      </div>

      {error && (
        <p className="text-sm text-corail">Impossible de charger les activités pour le moment.</p>
      )}

      {!error && events?.length === 0 && (
        <div className="rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">Aucune activité prévue pour l'instant.</p>
          <p className="mt-1 text-sm text-content-secondary">
            Sortie, sport, jeux de société... lance la première !
          </p>
          <Link
            href="/activites/new"
            className="mt-4 inline-block h-tap rounded-pill bg-corail px-6 py-3 font-medium text-white transition-fast hover:bg-corail-hover"
          >
            Organiser une activité
          </Link>
        </div>
      )}

      <div className="flex flex-col gap-3">
        {events?.map((event) => {
          const catInfo = getEventCategoryInfo(event.category);
          const count = attendeeCounts[event.id] || 0;
          const isFull = count >= event.max_attendees;
          const organizer = organizerInfo[event.user_id];
          const isOrganizer = event.user_id === user.id;

          return (
            <div key={event.id} className="rounded-card border border-border bg-surface-card p-3 shadow-soft">
              <div className="flex gap-3">
                <Link href={`/activites/${event.id}`} className="relative h-20 w-20 flex-shrink-0 overflow-hidden rounded-card">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={event.photo_url || getPlaceholderImage(event.category)}
                    alt=""
                    className="h-full w-full object-cover"
                  />
                  <PostDistanceBadge lat={event.lat} lng={event.lng} />
                </Link>

                <div className="min-w-0 flex-1">
                  <div className="flex items-center justify-between gap-2">
                    <Link href={`/activites/${event.id}`} className="flex min-w-0 items-center gap-1.5">
                      <div className="flex h-5 w-5 flex-shrink-0 items-center justify-center overflow-hidden rounded-pill bg-vert/10 text-[9px] font-semibold text-vert">
                        {organizer?.photo_visible && organizer?.photo_url ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img src={organizer.photo_url} alt="" className="h-full w-full object-cover" />
                        ) : (
                          (organizer?.display_name || '?').charAt(0).toUpperCase()
                        )}
                      </div>
                      <span className="truncate text-xs font-medium text-content-secondary">
                        {organizer?.display_name || 'Voisin'} · {formatEventDate(event.event_date)}
                      </span>
                    </Link>
                    <EventCardMenu eventId={event.id} isOrganizer={isOrganizer} />
                  </div>

                  <Link href={`/activites/${event.id}`}>
                    <p className="mt-1 font-semibold text-content-primary">{event.title}</p>
                    {event.location && (
                      <p className="mt-0.5 truncate text-sm text-content-secondary">{event.location}</p>
                    )}
                  </Link>

                  <div className="mt-2 flex items-center gap-1.5">
                    <span className="rounded-pill bg-surface px-2 py-0.5 text-[11px] font-medium text-content-secondary">
                      {catInfo.label}
                    </span>
                    {event.price_info && (
                      <span className="rounded-pill bg-vert/10 px-2 py-0.5 text-[11px] font-medium text-vert">
                        {event.price_info}
                      </span>
                    )}
                    <span className={`text-[11px] font-medium ${isFull ? 'text-corail' : 'text-content-secondary'}`}>
                      {isFull ? 'Complet' : `${count} / ${event.max_attendees} places`}
                    </span>
                  </div>
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


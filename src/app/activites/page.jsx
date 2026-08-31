// Server Component : activités à venir du quartier, triées par date,
// filtrable par catégorie via ?category=sortie|musee|sport|jeux_de_societe|autre.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { EVENT_CATEGORIES, getEventCategoryInfo, formatEventDate } from '@/lib/eventCategories';
import { getPlaceholderImage } from '@/lib/placeholderImages';

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
    .select('id, category, title, location, event_date, max_attendees, user_id')
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
  if (events?.length > 0) {
    const { data: attendees } = await supabase
      .from('event_attendees')
      .select('event_id')
      .in('event_id', events.map((e) => e.id));
    for (const a of attendees || []) {
      attendeeCounts[a.event_id] = (attendeeCounts[a.event_id] || 0) + 1;
    }
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
          return (
            <Link
              key={event.id}
              href={`/activites/${event.id}`}
              className="flex gap-3 rounded-card border border-border bg-surface-card p-4 shadow-soft transition-fast hover:bg-border/20 active:scale-[0.99]"
            >
              <div className="h-14 w-14 flex-shrink-0 overflow-hidden rounded-card">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={getPlaceholderImage(event.category)}
                  alt=""
                  className="h-full w-full object-cover"
                />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-xs font-medium text-content-secondary">
                  {formatEventDate(event.event_date)} · {catInfo.label}
                </p>
                <p className="mt-0.5 font-semibold text-content-primary">{event.title}</p>
                {event.location && (
                  <p className="mt-0.5 truncate text-sm text-content-secondary">{event.location}</p>
                )}
                <p className={`mt-1 text-xs font-medium ${isFull ? 'text-corail' : 'text-content-secondary'}`}>
                  {isFull ? 'Complet' : `${count} / ${event.max_attendees} places`}
                </p>
              </div>
            </Link>
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


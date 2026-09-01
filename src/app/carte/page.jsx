// Server Component : rassemble les annonces, activités et commerces ayant
// des coordonnées, dans le quartier de l'utilisateur uniquement (jamais
// au-delà — cohérent avec l'isolation stricte par quartier de toute
// l'app). Le rendu de la carte elle-même est délégué à un composant client
// (MapLibre a besoin du navigateur).

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import QuartierMapWrapper from '@/components/map/QuartierMapWrapper';

export default async function CartePage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: profile } = await supabase
    .from('profiles')
    .select('quartier_id, quartiers(name, city, center_lat, center_lng)')
    .eq('user_id', user.id)
    .single();

  if (!profile?.quartier_id) {
    return (
      <div className="p-4">
        <div className="rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">
            Termine d'abord ton inscription pour découvrir la carte de ton quartier.
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

  const [{ data: boundary }, { data: areaM2 }, { data: posts }, { data: events }, { data: places }] = await Promise.all([
    supabase.rpc('get_quartier_boundary', { p_quartier_id: quartierId }),
    supabase.rpc('get_quartier_area_m2', { p_quartier_id: quartierId }),
    supabase
      .from('posts')
      .select('id, type, title, description, lat, lng')
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .not('lat', 'is', null),
    supabase
      .from('events')
      .select('id, category, title, location, lat, lng')
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .gte('event_date', new Date().toISOString())
      .not('lat', 'is', null),
    supabase
      .from('places')
      .select('id, category, name, address, lat, lng')
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .not('lat', 'is', null),
  ]);

  // Un seul tableau à plat pour la carte — propriétés simples uniquement
  // (MapLibre sérialise les propriétés des sources groupées).
  const points = [
    ...(posts || []).map((p) => ({
      id: p.id,
      kind: 'post',
      category: p.type,
      title: p.title,
      subtitle: p.description || '',
      lat: p.lat,
      lng: p.lng,
    })),
    ...(events || []).map((e) => ({
      id: e.id,
      kind: 'event',
      category: e.category,
      title: e.title,
      subtitle: e.location || '',
      lat: e.lat,
      lng: e.lng,
    })),
    ...(places || []).map((pl) => ({
      id: pl.id,
      kind: 'place',
      category: pl.category,
      title: pl.name,
      subtitle: pl.address || '',
      lat: pl.lat,
      lng: pl.lng,
    })),
  ];

  return (
    <div className="flex h-[calc(100vh-3.5rem-4.25rem)] flex-col">
      <div className="border-b border-border bg-surface p-4">
        <h1 className="text-lg font-semibold text-content-primary">
          Carte — {profile.quartiers?.name}
        </h1>
        <p className="text-xs text-content-secondary">
          {points.length} élément{points.length > 1 ? 's' : ''} dans ton quartier
        </p>
      </div>

      <div className="relative flex-1">
        <QuartierMapWrapper
          centerLat={profile.quartiers?.center_lat || 0}
          centerLng={profile.quartiers?.center_lng || 0}
          boundary={boundary}
          areaM2={areaM2}
          points={points}
        />
      </div>
    </div>
  );
}


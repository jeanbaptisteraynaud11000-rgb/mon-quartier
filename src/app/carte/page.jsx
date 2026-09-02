// Server Component : rassemble les annonces, activités et commerces ayant
// des coordonnées, dans le quartier de l'utilisateur uniquement (jamais
// au-delà — cohérent avec l'isolation stricte par quartier de toute
// l'app). Le rendu de la carte elle-même est délégué à un composant client
// (MapLibre a besoin du navigateur).

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import QuartierMapWrapper from '@/components/map/QuartierMapWrapper';
import { calculateDistance, formatDistance } from '@/lib/distanceCalculator';
import { getPlaceholderImage } from '@/lib/placeholderImages';

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
  const centerLat = profile.quartiers?.center_lat || 0;
  const centerLng = profile.quartiers?.center_lng || 0;

  const [{ data: boundary }, { data: areaM2 }, { data: posts }, { data: events }, { data: places }] = await Promise.all([
    supabase.rpc('get_quartier_boundary', { p_quartier_id: quartierId }),
    supabase.rpc('get_quartier_area_m2', { p_quartier_id: quartierId }),
    supabase
      .from('posts')
      .select('id, type, title, description, availability, approx_zone, user_id, lat, lng')
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .not('lat', 'is', null),
    supabase
      .from('events')
      .select('id, category, title, location, event_date, max_attendees, user_id, photo_url, price_info, lat, lng')
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .gte('event_date', new Date().toISOString())
      .not('lat', 'is', null),
    supabase
      .from('places')
      .select('id, category, name, address, phone, photo_url, lat, lng')
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .not('lat', 'is', null),
  ]);

  // Auteurs des annonces/activités (photo, nom) — requête séparée, pas de
  // clé étrangère directe vers profiles.
  const authorIds = [
    ...new Set([...(posts || []).map((p) => p.user_id), ...(events || []).map((e) => e.user_id)]),
  ];
  const { data: authors } =
    authorIds.length > 0
      ? await supabase.from('profiles').select('user_id, display_name, photo_url, photo_visible').in('user_id', authorIds)
      : { data: [] };
  const authorById = Object.fromEntries((authors || []).map((a) => [a.user_id, a]));

  // Photo de couverture des annonces (première image).
  const postIds = (posts || []).map((p) => p.id);
  const { data: postImages } =
    postIds.length > 0
      ? await supabase
          .from('post_images')
          .select('post_id, storage_path, position')
          .in('post_id', postIds)
          .order('position', { ascending: true })
      : { data: [] };
  const thumbnailByPost = {};
  for (const img of postImages || []) {
    if (!thumbnailByPost[img.post_id]) {
      thumbnailByPost[img.post_id] = supabase.storage.from('posts').getPublicUrl(img.storage_path).data.publicUrl;
    }
  }

  function distanceFromCenter(lat, lng) {
    const km = calculateDistance(centerLat, centerLng, lat, lng);
    return formatDistance(km);
  }

  // Un seul tableau à plat pour la carte — propriétés simples uniquement
  // (MapLibre sérialise les propriétés des sources groupées).
  const points = [
    ...(posts || []).map((p) => {
      const author = authorById[p.user_id];
      return {
        id: p.id,
        kind: 'post',
        category: p.type,
        title: p.title,
        description: p.description || '',
        photo: thumbnailByPost[p.id] || getPlaceholderImage(p.type),
        authorName: author?.display_name || 'Voisin',
        authorPhoto: author?.photo_visible ? author?.photo_url || '' : '',
        availability: p.availability || '',
        zone: p.approx_zone || '',
        distanceLabel: distanceFromCenter(p.lat, p.lng) || '',
        lat: p.lat,
        lng: p.lng,
      };
    }),
    ...(events || []).map((e) => {
      const author = authorById[e.user_id];
      return {
        id: e.id,
        kind: 'event',
        category: e.category,
        title: e.title,
        description: e.location || '',
        photo: e.photo_url || getPlaceholderImage(e.category),
        authorName: author?.display_name || 'Voisin',
        authorPhoto: author?.photo_visible ? author?.photo_url || '' : '',
        availability: new Date(e.event_date).toLocaleDateString('fr-FR', {
          weekday: 'short',
          day: 'numeric',
          month: 'short',
          hour: '2-digit',
          minute: '2-digit',
        }) + (e.price_info ? ` · ${e.price_info}` : ''),
        zone: '',
        distanceLabel: distanceFromCenter(e.lat, e.lng) || '',
        lat: e.lat,
        lng: e.lng,
      };
    }),
    ...(places || []).map((pl) => ({
      id: pl.id,
      kind: 'place',
      category: pl.category,
      title: pl.name,
      description: pl.address || '',
      photo: pl.photo_url || getPlaceholderImage(pl.category),
      authorName: '',
      authorPhoto: '',
      availability: '',
      zone: '',
      distanceLabel: distanceFromCenter(pl.lat, pl.lng) || '',
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
          centerLat={centerLat}
          centerLng={centerLng}
          boundary={boundary}
          areaM2={areaM2}
          points={points}
        />
      </div>
    </div>
  );
}


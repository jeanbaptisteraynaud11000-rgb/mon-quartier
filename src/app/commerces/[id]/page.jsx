// Server Component : détail d'un commerce. RLS "places_select_own_quartier"
// garantit déjà l'isolation par quartier.

import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { getPlaceCategoryInfo } from '@/lib/placeCategories';
import { getPlaceholderImage } from '@/lib/placeholderImages';

export default async function PlaceDetailPage({ params }) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: place, error } = await supabase
    .from('places')
    .select('id, category, name, description, address, phone, website, added_by, photo_url')
    .eq('id', id)
    .single();

  if (error || !place) {
    notFound();
  }

  const catInfo = getPlaceCategoryInfo(place.category);
  const Icon = catInfo.icon;

  return (
    <div className="flex flex-col gap-5 p-4">
      <Link href="/commerces" className="text-sm font-medium text-content-secondary">
        ← Retour
      </Link>

      <div className="relative h-44 w-full overflow-hidden rounded-card bg-surface-card">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={place.photo_url || getPlaceholderImage(place.category)}
          alt=""
          className="h-full w-full object-cover"
        />
      </div>

      <div className="rounded-card border border-border bg-surface-card p-5">
        <div className="flex items-center gap-2">
          <span className="flex h-8 w-8 items-center justify-center rounded-pill bg-surface text-content-secondary">
            <Icon size={16} />
          </span>
          <span className="text-sm font-medium text-content-secondary">{catInfo.label}</span>
        </div>

        <h1 className="mt-3 text-xl font-semibold text-content-primary">{place.name}</h1>

        {place.address && (
          <p className="mt-2 text-sm text-content-secondary">{place.address}</p>
        )}

        {place.description && (
          <p className="mt-4 whitespace-pre-wrap text-content-primary">{place.description}</p>
        )}

        {(place.phone || place.website) && (
          <div className="mt-4 flex flex-col gap-1 border-t border-border pt-4">
            {place.phone && (
              <a href={`tel:${place.phone}`} className="text-sm font-medium text-corail">
                {place.phone}
              </a>
            )}
            {place.website && (
              <a
                href={place.website.startsWith('http') ? place.website : `https://${place.website}`}
                target="_blank"
                rel="noopener noreferrer"
                className="text-sm font-medium text-corail"
              >
                {place.website}
              </a>
            )}
          </div>
        )}
      </div>

      <p className="text-center text-xs text-content-secondary">
        Ajouté par un habitant du quartier. Vérifie les informations avant de te déplacer.
      </p>
    </div>
  );
}


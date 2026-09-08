// Server Component protégé — voir requireAdmin().

import { requireAdmin } from '@/lib/requireAdmin';
import { getPlaceCategoryInfo } from '@/lib/placeCategories';
import SponsorToggle from './SponsorToggle';
import OfferModeration from './OfferModeration';

export default async function AdminCommercesPage() {
  const { supabase } = await requireAdmin();

  const { data: places } = await supabase
    .from('places')
    .select('id, name, category, is_sponsored, sponsored_until, quartiers(name, city)')
    .order('name', { ascending: true });

  const { data: pendingOffers } = await supabase
    .from('place_offers')
    .select('id, title, description, ends_at, places(name)')
    .eq('status', 'pending')
    .order('created_at', { ascending: true });

  return (
    <div className="flex flex-col gap-6 p-4">
      <h1 className="text-xl font-semibold text-content-primary">
        Commerces — sponsoring & offres
      </h1>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-content-secondary">
          Offres en attente de validation ({pendingOffers?.length || 0})
        </h2>
        {(!pendingOffers || pendingOffers.length === 0) && (
          <p className="text-sm text-content-secondary">Aucune offre en attente.</p>
        )}
        <div className="flex flex-col gap-2">
          {pendingOffers?.map((offer) => (
            <OfferModeration key={offer.id} offer={offer} />
          ))}
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-content-secondary">
          Fiches ({places?.length || 0})
        </h2>
        <div className="flex flex-col gap-2">
          {places?.map((place) => {
            const catInfo = getPlaceCategoryInfo(place.category);
            return (
              <div
                key={place.id}
                className="flex items-center justify-between gap-3 rounded-card border border-border bg-surface-card p-3"
              >
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium text-content-primary">{place.name}</p>
                  <p className="truncate text-xs text-content-secondary">
                    {catInfo.label} · {place.quartiers?.name} — {place.quartiers?.city}
                  </p>
                </div>
                <SponsorToggle placeId={place.id} isSponsored={place.is_sponsored} sponsoredUntil={place.sponsored_until} />
              </div>
            );
          })}
        </div>
      </section>
    </div>
  );
}


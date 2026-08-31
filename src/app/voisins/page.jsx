// Server Component : annuaire des voisins du quartier.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';

function memberSince(dateString) {
  const date = new Date(dateString);
  const diffMonths =
    (Date.now() - date.getTime()) / (1000 * 60 * 60 * 24 * 30.44);

  if (diffMonths < 1) return "arrivé(e) ce mois-ci";
  if (diffMonths < 2) return 'membre depuis 1 mois';
  if (diffMonths < 12) return `membre depuis ${Math.floor(diffMonths)} mois`;
  const years = Math.floor(diffMonths / 12);
  return `membre depuis ${years} an${years > 1 ? 's' : ''}`;
}

export default async function VoisinsPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: myProfile } = await supabase
    .from('profiles')
    .select('quartier_id, quartiers(name, city)')
    .eq('user_id', user.id)
    .single();

  if (!myProfile?.quartier_id) {
    return (
      <div className="p-4">
        <div className="rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">
            Termine d'abord ton inscription pour voir tes voisins.
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

  // On respecte map_visibility = 'off' comme un choix général de discrétion :
  // quelqu'un qui a explicitement demandé à ne pas apparaître ne doit pas se
  // retrouver listé ici non plus. Limite à 50 : mesure simple anti-scraping
  // (section 83) en attendant une vraie pagination si le quartier grossit.
  const { data: neighbors, error } = await supabase
    .from('profiles')
    .select('user_id, display_name, created_at, map_visibility, photo_url, photo_visible')
    .eq('quartier_id', myProfile.quartier_id)
    .neq('map_visibility', 'off')
    .order('created_at', { ascending: true })
    .limit(50);

  return (
    <div className="flex flex-col gap-4 p-4">
      <div>
        <h1 className="text-xl font-semibold text-content-primary">Mes voisins</h1>
        <p className="text-sm text-content-secondary">
          {myProfile.quartiers?.name} — {myProfile.quartiers?.city}
        </p>
      </div>

      {error && (
        <p className="text-sm text-corail">Impossible de charger la liste pour le moment.</p>
      )}

      {!error && neighbors?.length === 0 && (
        <div className="rounded-card border border-border bg-surface-card p-6 text-center text-sm text-content-secondary">
          Aucun voisin visible pour l'instant.
        </div>
      )}

      <div className="flex flex-col gap-2">
        {neighbors?.map((neighbor) => {
          const isMe = neighbor.user_id === user.id;
          const initial = (neighbor.display_name || '?').charAt(0).toUpperCase();
          return (
            <div
              key={neighbor.user_id}
              className="flex items-center gap-3 rounded-card border border-border bg-surface-card p-3"
            >
              <div className="flex h-10 w-10 flex-shrink-0 items-center justify-center overflow-hidden rounded-pill bg-corail/10 font-semibold text-corail">
                {neighbor.photo_visible && neighbor.photo_url ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={neighbor.photo_url} alt="" className="h-full w-full object-cover" />
                ) : (
                  initial
                )}
              </div>
              <div className="min-w-0 flex-1">
                <p className="truncate font-medium text-content-primary">
                  {neighbor.display_name || 'Voisin'} {isMe && '(toi)'}
                </p>
                <p className="text-xs text-content-secondary">
                  {memberSince(neighbor.created_at)}
                </p>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}


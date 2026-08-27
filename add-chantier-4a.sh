#!/usr/bin/env bash
set -e
echo "Ajout du chantier #4a (accueil reel)..."

mkdir -p "src/app"
cat > "src/app/page.jsx" << 'MQEOF_SRC_APP_PAGE_JSX'
// Page d'accueil — Server Component : les données sont chargées côté
// serveur avant l'envoi de la page (pas de flash de contenu vide, pas de
// clé Supabase exposée côté client pour ces requêtes).

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';

const CATEGORIES = [
  { type: 'don', label: 'Prêt / Don', emoji: '🎁' },
  { type: 'entraide', label: 'Entraide', emoji: '🤝' },
  { type: 'covoiturage', label: 'Covoiturage', emoji: '🚗' },
  { type: 'cherche', label: 'Je cherche', emoji: '🔎' },
];

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

  // Cas résiduel : compte créé mais onboarding jamais terminé
  // (quartier_id encore null). On ne devrait normalement plus voir ce cas
  // vu l'auto-approbation, mais on le gère proprement au cas où.
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
  const quartierName = profile.quartiers?.name ?? 'ton quartier';
  const quartierCity = profile.quartiers?.city ?? '';
  const firstName = profile.display_name?.split(' ')[0] || null;

  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);

  const [neighborsCount, postsTodayCount, entraideCount] = await Promise.all([
    supabase
      .from('profiles')
      .select('*', { count: 'exact', head: true })
      .eq('quartier_id', quartierId),
    supabase
      .from('posts')
      .select('*', { count: 'exact', head: true })
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .gte('created_at', startOfToday.toISOString()),
    supabase
      .from('posts')
      .select('*', { count: 'exact', head: true })
      .eq('quartier_id', quartierId)
      .eq('status', 'active')
      .eq('type', 'entraide'),
  ]);

  return (
    <div className="flex flex-col gap-6 p-4">
      <section className="rounded-card border border-border bg-surface-card p-5">
        <h1 className="text-xl font-semibold text-content-primary">
          {firstName ? `Bonjour ${firstName} 👋` : 'Bonjour 👋'}
        </h1>
        <p className="mt-1 text-sm text-content-secondary">
          Que se passe-t-il dans {quartierName} ?
        </p>
      </section>

      <section>
        <div className="grid grid-cols-2 gap-3">
          {CATEGORIES.map((cat) => (
            <Link
              key={cat.type}
              href={`/annonces?type=${cat.type}`}
              className="flex h-28 flex-col justify-between rounded-card border border-border bg-surface-card p-3 shadow-soft transition-fast hover:bg-border/40 active:scale-[0.98]"
            >
              <span className="text-2xl">{cat.emoji}</span>
              <span className="text-sm font-medium text-content-primary">{cat.label}</span>
            </Link>
          ))}
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-base font-semibold text-content-primary">Mes voisins</h2>
        <Link
          href="/voisins"
          className="block rounded-card border border-border bg-surface-card p-4 shadow-soft transition-fast hover:bg-border/40 active:scale-[0.98]"
        >
          <div className="flex items-center justify-between text-sm">
            <span className="text-content-secondary">
              <span className="text-lg font-semibold text-content-primary">
                {neighborsCount.count ?? 0}
              </span>{' '}
              voisin{(neighborsCount.count ?? 0) > 1 ? 's' : ''}
            </span>
          </div>
          <div className="mt-2 flex items-center justify-between text-sm text-content-secondary">
            <span>{postsTodayCount.count ?? 0} annonce{(postsTodayCount.count ?? 0) > 1 ? 's' : ''} aujourd'hui</span>
          </div>
          <div className="mt-1 flex items-center justify-between text-sm text-content-secondary">
            <span>{entraideCount.count ?? 0} demande{(entraideCount.count ?? 0) > 1 ? 's' : ''} d'entraide en cours</span>
          </div>
          <span className="mt-3 inline-block text-sm font-medium text-corail">
            Voir mes voisins →
          </span>
        </Link>
      </section>

      {quartierCity && (
        <p className="text-center text-xs text-content-secondary">
          {quartierName} — {quartierCity}
        </p>
      )}
    </div>
  );
}

MQEOF_SRC_APP_PAGE_JSX

echo "Chantier #4a ajoute avec succes."
echo "Prochaine etape : git add -A && git commit -m \"chantier 4a : accueil reel\" && git push"
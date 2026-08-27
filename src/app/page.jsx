// Page d'accueil PROVISOIRE — sert uniquement à valider le design system
// et la navigation (Header + BottomNav) pendant le chantier #2.
//
// Le vrai contenu (bienvenue personnalisée, catégories 2x2, bloc "Mes voisins",
// données réelles) sera construit au chantier "Accueil" (Phase 2, section 5-6
// du prompt maître) une fois l'authentification en place.

export default function HomePage() {
  return (
    <div className="flex flex-col gap-6 p-4">
      <section className="rounded-card border border-border bg-surface-card p-5">
        <h1 className="text-xl font-semibold text-content-primary">
          Bonjour 👋
        </h1>
        <p className="mt-1 text-sm text-content-secondary">
          Que se passe-t-il dans votre quartier ?
        </p>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-medium text-content-secondary">
          Aperçu design system — Chantier #2
        </h2>
        <div className="grid grid-cols-2 gap-3">
          {['Prêt / Don', 'Entraide', 'Covoiturage', 'Je cherche'].map((label) => (
            <div
              key={label}
              className="flex h-28 flex-col justify-end rounded-card border border-border bg-surface-card p-3 shadow-soft"
            >
              <span className="text-sm font-medium text-content-primary">{label}</span>
            </div>
          ))}
        </div>
      </section>

      <section className="rounded-card border border-border bg-surface-card p-4 text-sm text-content-secondary">
        Utilise le bouton <span className="font-medium text-corail">+</span> en bas
        pour tester le bottom sheet de création, et la nav basse pour vérifier
        les états actifs.
      </section>
    </div>
  );
}


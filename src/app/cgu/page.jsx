export default function CGUPage() {
  return (
    <div className="mx-auto max-w-2xl p-6 text-sm text-content-primary">
      <h1 className="mb-4 text-xl font-semibold">Conditions Générales d'Utilisation</h1>

      <p className="mb-4 rounded-card border border-corail bg-corail/5 p-4 text-corail">
        ⚠️ Contenu à personnaliser : trame générique, à faire valider par un professionnel
        du droit avant mise en production.
      </p>

      <h2 className="mt-6 mb-2 font-semibold">1. Objet</h2>
      <p className="text-content-secondary">
        Hoody est une application permettant aux habitants d'un même quartier de se
        découvrir, s'entraider, échanger des objets et communiquer.
      </p>

      <h2 className="mt-6 mb-2 font-semibold">2. Inscription</h2>
      <p className="text-content-secondary">
        L'inscription nécessite une adresse réelle rattachée à un quartier disponible sur la
        plateforme. Toute fausse déclaration peut entraîner la suspension du compte.
      </p>

      <h2 className="mt-6 mb-2 font-semibold">3. Comportement attendu</h2>
      <p className="text-content-secondary">
        Chaque utilisateur s'engage à un comportement respectueux envers les autres membres.
        Tout contenu inapproprié, frauduleux ou harcelant peut faire l'objet d'un signalement
        et d'une modération (masquage, suspension, bannissement).
      </p>

      <h2 className="mt-6 mb-2 font-semibold">4. Responsabilité</h2>
      <p className="text-content-secondary">
        Les échanges entre voisins (prêts, dons, covoiturage) se font sous la responsabilité
        des utilisateurs eux-mêmes. Hoody ne garantit pas la qualité, la sécurité ou
        la légalité des annonces publiées.
      </p>

      <h2 className="mt-6 mb-2 font-semibold">5. Résiliation</h2>
      <p className="text-content-secondary">
        Chaque utilisateur peut supprimer son compte à tout moment depuis les paramètres.
      </p>
    </div>
  );
}


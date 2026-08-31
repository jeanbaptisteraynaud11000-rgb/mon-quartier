export default function ConfidentialitePage() {
  return (
    <div className="mx-auto max-w-2xl p-6 text-sm text-content-primary">
      <h1 className="mb-4 text-xl font-semibold">Confidentialité et données personnelles</h1>

      <p className="mb-4 rounded-card border border-corail bg-corail/5 p-4 text-corail">
        ⚠️ Contenu à personnaliser et faire valider juridiquement (obligations RGPD réelles :
        base légale, DPO éventuel, durées de conservation précises).
      </p>

      <h2 className="mt-6 mb-2 font-semibold">Données collectées</h2>
      <p className="text-content-secondary">
        Email, prénom affiché, adresse (utilisée uniquement pour déterminer ton quartier,
        jamais affichée publiquement en clair), et le contenu que tu publies (annonces,
        messages).
      </p>

      <h2 className="mt-6 mb-2 font-semibold">Finalité</h2>
      <p className="text-content-secondary">
        Ces données servent uniquement à faire fonctionner le service : te rattacher à ton
        quartier, te permettre d'échanger avec tes voisins, et assurer la sécurité de la
        plateforme (modération, lutte contre les abus).
      </p>

      <h2 className="mt-6 mb-2 font-semibold">Localisation</h2>
      <p className="text-content-secondary">
        Ta position exacte n'est jamais partagée avec les autres utilisateurs. Seul un
        périmètre flouté peut apparaître sur la carte, selon tes préférences de
        confidentialité.
      </p>

      <h2 className="mt-6 mb-2 font-semibold">Tes droits</h2>
      <p className="text-content-secondary">
        Tu peux à tout moment demander la suppression de ton compte depuis les paramètres.
        Pour toute autre demande (accès, rectification, export de tes données), contacte
        [email de contact DPO/support].
      </p>
    </div>
  );
}


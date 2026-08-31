export default function MentionsLegalesPage() {
  return (
    <div className="mx-auto max-w-2xl p-6 text-sm text-content-primary">
      <h1 className="mb-4 text-xl font-semibold">Mentions légales</h1>

      <p className="mb-4 rounded-card border border-corail bg-corail/5 p-4 text-corail">
        ⚠️ Contenu à personnaliser : ce texte est un point de départ générique,
        pas un document juridique validé. Fais-le relire par un professionnel
        avant mise en production réelle.
      </p>

      <h2 className="mt-6 mb-2 font-semibold">Éditeur du site</h2>
      <p className="text-content-secondary">
        [Nom / raison sociale] — [adresse] — [email de contact] — [SIRET si applicable]
      </p>

      <h2 className="mt-6 mb-2 font-semibold">Directeur de publication</h2>
      <p className="text-content-secondary">[Nom du responsable]</p>

      <h2 className="mt-6 mb-2 font-semibold">Hébergement</h2>
      <p className="text-content-secondary">
        Supabase (base de données) — [adresse de l'hébergeur Supabase]
        <br />
        [Hébergeur du frontend, ex : Vercel] — [adresse]
      </p>

      <h2 className="mt-6 mb-2 font-semibold">Propriété intellectuelle</h2>
      <p className="text-content-secondary">
        L'ensemble des contenus de Hoody (textes, logo, charte graphique) sont
        protégés. Les contenus publiés par les utilisateurs (annonces, messages) leur
        appartiennent.
      </p>
    </div>
  );
}


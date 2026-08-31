import Link from 'next/link';

const CATEGORIES = [
  {
    title: 'Compte',
    items: [
      { q: 'Comment changer mon mot de passe ?', a: "Va dans Profil > Paramètres (bientôt disponible), ou utilise 'Mot de passe oublié' depuis l'écran de connexion." },
      { q: 'Comment supprimer mon compte ?', a: "Rends-toi sur ta page de profil et utilise l'option de suppression de compte." },
    ],
  },
  {
    title: 'Quartier',
    items: [
      { q: "Mon quartier n'est pas disponible, que faire ?", a: "L'app se déploie progressivement quartier par quartier. Reviens plus tard ou contacte le support." },
    ],
  },
  {
    title: 'Annonces',
    items: [
      { q: 'Comment publier une annonce ?', a: "Utilise le bouton + en bas de l'écran, choisis une catégorie, remplis le formulaire." },
      { q: 'Comment supprimer ou modifier une annonce ?', a: "Va sur 'Mes annonces' depuis ton profil, tu y trouveras les actions Modifier et Supprimer." },
    ],
  },
  {
    title: 'Messagerie',
    items: [
      { q: 'Comment contacter un voisin ?', a: "Depuis le détail d'une annonce, clique sur 'Contacter'." },
      { q: 'Comment bloquer quelqu\'un ?', a: "Dans une conversation, utilise le menu ⋯ en haut à droite." },
    ],
  },
  {
    title: 'Confidentialité et sécurité',
    items: [
      { q: 'Mon adresse est-elle visible des autres ?', a: "Non, jamais. Seule une position approximative peut apparaître selon tes préférences." },
      { q: 'Comment signaler un contenu ?', a: "Depuis une annonce ou une conversation, utilise le bouton 'Signaler'." },
    ],
  },
];

export default function HelpPage() {
  return (
    <div className="flex flex-col gap-6 p-4">
      <h1 className="text-xl font-semibold text-content-primary">Aide</h1>

      {CATEGORIES.map((cat) => (
        <div key={cat.title}>
          <h2 className="mb-2 font-semibold text-content-primary">{cat.title}</h2>
          <div className="flex flex-col gap-2">
            {cat.items.map((item) => (
              <details
                key={item.q}
                className="rounded-card border border-border bg-surface-card p-3"
              >
                <summary className="cursor-pointer text-sm font-medium text-content-primary">
                  {item.q}
                </summary>
                <p className="mt-2 text-sm text-content-secondary">{item.a}</p>
              </details>
            ))}
          </div>
        </div>
      ))}

      <div className="rounded-card border border-border bg-surface-card p-4 text-center text-sm">
        <p className="text-content-secondary">Tu ne trouves pas ta réponse ?</p>
        <Link href="/support" className="mt-1 inline-block font-medium text-corail">
          Contacter le support →
        </Link>
      </div>
    </div>
  );
}


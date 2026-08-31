#!/usr/bin/env bash
set -e
echo "Ajout PWA (2/3) : pages legales, aide, support..."

mkdir -p "src/app/confidentialite"
cat > "src/app/confidentialite/page.jsx" << 'MQEOF_SRC_APP_CONFIDENTIALITE_PAGE_JSX'
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

MQEOF_SRC_APP_CONFIDENTIALITE_PAGE_JSX

mkdir -p "src/app/cgu"
cat > "src/app/cgu/page.jsx" << 'MQEOF_SRC_APP_CGU_PAGE_JSX'
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
        Mon Quartier est une application permettant aux habitants d'un même quartier de se
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
        des utilisateurs eux-mêmes. Mon Quartier ne garantit pas la qualité, la sécurité ou
        la légalité des annonces publiées.
      </p>

      <h2 className="mt-6 mb-2 font-semibold">5. Résiliation</h2>
      <p className="text-content-secondary">
        Chaque utilisateur peut supprimer son compte à tout moment depuis les paramètres.
      </p>
    </div>
  );
}

MQEOF_SRC_APP_CGU_PAGE_JSX

mkdir -p "src/app/mentions-legales"
cat > "src/app/mentions-legales/page.jsx" << 'MQEOF_SRC_APP_MENTIONS-LEGALES_PAGE_JSX'
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
        L'ensemble des contenus de Mon Quartier (textes, logo, charte graphique) sont
        protégés. Les contenus publiés par les utilisateurs (annonces, messages) leur
        appartiennent.
      </p>
    </div>
  );
}

MQEOF_SRC_APP_MENTIONS-LEGALES_PAGE_JSX

mkdir -p "src/app/cookies"
cat > "src/app/cookies/page.jsx" << 'MQEOF_SRC_APP_COOKIES_PAGE_JSX'
export default function CookiesPage() {
  return (
    <div className="mx-auto max-w-2xl p-6 text-sm text-content-primary">
      <h1 className="mb-4 text-xl font-semibold">Cookies</h1>

      <p className="mb-4 rounded-card border border-corail bg-corail/5 p-4 text-corail">
        ⚠️ À adapter selon les outils réellement utilisés (analytics, etc.).
      </p>

      <p className="text-content-secondary">
        Mon Quartier utilise uniquement des cookies techniques nécessaires au
        fonctionnement du service (maintien de ta session de connexion). Aucun cookie
        publicitaire ou de tracking tiers n'est utilisé à ce stade.
      </p>
    </div>
  );
}

MQEOF_SRC_APP_COOKIES_PAGE_JSX

mkdir -p "src/app/help"
cat > "src/app/help/page.jsx" << 'MQEOF_SRC_APP_HELP_PAGE_JSX'
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

MQEOF_SRC_APP_HELP_PAGE_JSX

mkdir -p "src/app/support"
cat > "src/app/support/page.jsx" << 'MQEOF_SRC_APP_SUPPORT_PAGE_JSX'
'use client';

import { useState } from 'react';
import { supabase } from '@/lib/supabaseClient';

const CATEGORIES = ['Compte', 'Quartier', 'Annonces', 'Messagerie', 'Confidentialité', 'Sécurité', 'Autre'];

export default function SupportPage() {
  const [category, setCategory] = useState(CATEGORIES[0]);
  const [subject, setSubject] = useState('');
  const [description, setDescription] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState('');

  async function handleSubmit(e) {
    e.preventDefault();
    if (!subject.trim() || !description.trim()) return;

    setSubmitting(true);
    setError('');

    const { data: { user } } = await supabase.auth.getUser();
    const { error: insertError } = await supabase.from('support_requests').insert({
      user_id: user.id,
      category,
      subject: subject.trim(),
      description: description.trim(),
    });

    setSubmitting(false);

    if (insertError) {
      setError('Une erreur est survenue. Réessaie.');
      return;
    }

    setDone(true);
  }

  if (done) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center p-6 text-center">
        <div className="text-4xl">✓</div>
        <h1 className="mt-3 text-lg font-semibold text-content-primary">
          Ta demande a bien été envoyée
        </h1>
        <p className="mt-1 text-sm text-content-secondary">On te répondra au plus vite.</p>
      </div>
    );
  }

  return (
    <div className="p-6">
      <h1 className="mb-4 text-xl font-semibold text-content-primary">Contacter le support</h1>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <div>
          <label className="mb-1 block text-sm font-medium text-content-primary">Catégorie</label>
          <select
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none focus:border-corail"
          >
            {CATEGORIES.map((c) => (
              <option key={c} value={c}>{c}</option>
            ))}
          </select>
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium text-content-primary">Sujet</label>
          <input
            type="text"
            required
            value={subject}
            onChange={(e) => setSubject(e.target.value)}
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none focus:border-corail"
          />
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium text-content-primary">Description</label>
          <textarea
            required
            rows={5}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            className="w-full resize-none rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none focus:border-corail"
          />
        </div>

        {error && <p className="text-sm text-corail">{error}</p>}

        <button
          type="submit"
          disabled={submitting}
          className="h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
        >
          {submitting ? 'Envoi...' : 'Envoyer'}
        </button>
      </form>
    </div>
  );
}

MQEOF_SRC_APP_SUPPORT_PAGE_JSX

echo "PWA (2/3) ajoutee avec succes."
echo "Prochaine etape : executer la migration SQL 013 dans Supabase, puis tester."

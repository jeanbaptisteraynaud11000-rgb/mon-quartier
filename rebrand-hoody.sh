#!/usr/bin/env bash
set -e
echo "Rebranding Mon Quartier -> Hoody..."

mkdir -p "public"
cat > "public/manifest.json" << 'MQEOF_PUBLIC_MANIFEST_JSON'
{
  "name": "Hoody",
  "short_name": "Hoody",
  "description": "L'application quotidienne de votre voisinage",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#FFFFFF",
  "theme_color": "#FF5A5F",
  "orientation": "portrait",
  "icons": [
    {
      "src": "/icons/icon-192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/icons/icon-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "any maskable"
    }
  ]
}

MQEOF_PUBLIC_MANIFEST_JSON

mkdir -p "src/app"
cat > "src/app/layout.jsx" << 'MQEOF_SRC_APP_LAYOUT_JSX'
import './globals.css';
import Header from '@/components/layout/Header';
import BottomNav from '@/components/layout/BottomNav';
import ServiceWorkerRegistration from '@/components/ServiceWorkerRegistration';

export const metadata = {
  title: 'Hoody',
  description: "L'application quotidienne de votre voisinage : entraide, prêt, covoiturage et vie de quartier.",
  manifest: '/manifest.json',
  icons: {
    icon: '/icons/icon-192.png',
    apple: '/icons/icon-192.png',
  },
};

export const viewport = {
  themeColor: '#FFFFFF',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
};

export default function RootLayout({ children }) {
  return (
    <html lang="fr">
      <body className="font-sans text-content-primary">
        <ServiceWorkerRegistration />
        <Header />
        {/* pb-nav-h + marge : laisse la place à la nav basse fixe */}
        <main className="mx-auto min-h-screen max-w-lg pb-[calc(theme(spacing.nav-h)+1rem)]">
          {children}
        </main>
        <BottomNav />
      </body>
    </html>
  );
}

MQEOF_SRC_APP_LAYOUT_JSX

mkdir -p "src/components/layout"
cat > "src/components/layout/Header.jsx" << 'MQEOF_SRC_COMPONENTS_LAYOUT_HEADER_JSX'
'use client';

import Link from 'next/link';
import Image from 'next/image';
import { Bell, MessageCircle } from 'lucide-react';

// NOTE : les badges (nombre non lus) sont volontairement absents pour l'instant.
// Ils seront branchés au chantier "Notifications / Messagerie" sur de vraies
// données Supabase (jamais de chiffres fictifs, section 65 du prompt maître).
// Structure prête : voir <NotificationBadge count={...} /> commenté ci-dessous.

function IconButton({ href, ariaLabel, children }) {
  return (
    <Link
      href={href}
      aria-label={ariaLabel}
      className="relative flex h-tap w-tap items-center justify-center rounded-pill text-content-primary transition-fast hover:bg-surface-card active:scale-95"
    >
      {children}
    </Link>
  );
}

// function NotificationBadge({ count }) {
//   if (!count) return null;
//   return (
//     <span className="absolute -top-0.5 -right-0.5 flex h-4 min-w-4 items-center justify-center rounded-pill bg-corail px-1 text-[10px] font-semibold text-white">
//       {count > 9 ? '9+' : count}
//     </span>
//   );
// }

export default function Header() {
  return (
    <header className="safe-top sticky top-0 z-40 flex h-14 items-center justify-between border-b border-border bg-surface/95 px-4 backdrop-blur">
      <Link href="/" className="flex items-center" aria-label="Hoody, accueil">
        <Image src="/logo.png" alt="Hoody" width={96} height={30} priority className="h-6 w-auto" />
      </Link>

      <div className="flex items-center gap-1">
        <IconButton href="/notifications" ariaLabel="Notifications">
          <Bell size={22} strokeWidth={1.8} />
        </IconButton>
        <IconButton href="/messages" ariaLabel="Messages">
          <MessageCircle size={22} strokeWidth={1.8} />
        </IconButton>
      </div>
    </header>
  );
}

MQEOF_SRC_COMPONENTS_LAYOUT_HEADER_JSX

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
        L'ensemble des contenus de Hoody (textes, logo, charte graphique) sont
        protégés. Les contenus publiés par les utilisateurs (annonces, messages) leur
        appartiennent.
      </p>
    </div>
  );
}

MQEOF_SRC_APP_MENTIONS-LEGALES_PAGE_JSX

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

MQEOF_SRC_APP_CGU_PAGE_JSX

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
        Hoody utilise uniquement des cookies techniques nécessaires au
        fonctionnement du service (maintien de ta session de connexion). Aucun cookie
        publicitaire ou de tracking tiers n'est utilisé à ce stade.
      </p>
    </div>
  );
}

MQEOF_SRC_APP_COOKIES_PAGE_JSX

mkdir -p "src/app/onboarding"
cat > "src/app/onboarding/page.jsx" << 'MQEOF_SRC_APP_ONBOARDING_PAGE_JSX'
'use client';

import { useEffect, useState, useCallback, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';

// Statuts possibles de l'écran affiché
const SCREENS = {
  LOADING: 'loading',
  ADDRESS_FORM: 'address_form',
  QUARTIER_FOUND: 'quartier_found',
  NO_QUARTIER: 'no_quartier',
  MEMBERSHIP_PENDING: 'membership_pending',
  MEMBERSHIP_APPROVED: 'membership_approved',
  MEMBERSHIP_REJECTED: 'membership_rejected',
};

export default function OnboardingPage() {
  const router = useRouter();
  const [screen, setScreen] = useState(SCREENS.LOADING);
  const [error, setError] = useState('');

  // Recherche d'adresse
  const [query, setQuery] = useState('');
  const [suggestions, setSuggestions] = useState([]);
  const [searching, setSearching] = useState(false);
  const debounceRef = useRef(null);

  // Résultat de la détection
  const [detectedQuartier, setDetectedQuartier] = useState(null);
  const [selectedCoords, setSelectedCoords] = useState(null);
  const [selectedLabel, setSelectedLabel] = useState('');
  const [submitting, setSubmitting] = useState(false);

  // Étape 1 : vérifier si l'utilisateur a déjà une demande d'adhésion
  // en cours (évite de lui re-proposer l'onboarding à chaque visite).
  useEffect(() => {
    async function checkExistingMembership() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        router.push('/login');
        return;
      }

      const { data: memberships, error: fetchError } = await supabase
        .from('neighborhood_memberships')
        .select('status, quartiers(name, city)')
        .eq('user_id', user.id)
        .order('requested_at', { ascending: false })
        .limit(1);

      if (fetchError) {
        setError("Impossible de vérifier ton statut. Réessaie dans un instant.");
        setScreen(SCREENS.ADDRESS_FORM);
        return;
      }

      const latest = memberships?.[0];

      if (!latest) {
        setScreen(SCREENS.ADDRESS_FORM);
      } else if (latest.status === 'pending') {
        setDetectedQuartier(latest.quartiers);
        setScreen(SCREENS.MEMBERSHIP_PENDING);
      } else if (latest.status === 'approved') {
        setDetectedQuartier(latest.quartiers);
        setScreen(SCREENS.MEMBERSHIP_APPROVED);
      } else if (latest.status === 'rejected') {
        setScreen(SCREENS.MEMBERSHIP_REJECTED);
      } else {
        setScreen(SCREENS.ADDRESS_FORM);
      }
    }

    checkExistingMembership();
  }, [router]);

  // Autocomplétion via l'API Adresse (data.gouv.fr), avec un debounce de 300ms
  // pour ne pas spammer l'API à chaque frappe.
  const handleQueryChange = useCallback((value) => {
    setQuery(value);
    setDetectedQuartier(null);
    setSelectedCoords(null);

    if (debounceRef.current) clearTimeout(debounceRef.current);

    if (value.trim().length < 4) {
      setSuggestions([]);
      return;
    }

    debounceRef.current = setTimeout(async () => {
      setSearching(true);
      try {
        const res = await fetch(
          `https://api-adresse.data.gouv.fr/search/?q=${encodeURIComponent(value)}&limit=5`
        );
        const json = await res.json();
        setSuggestions(json.features || []);
      } catch {
        setSuggestions([]);
      } finally {
        setSearching(false);
      }
    }, 300);
  }, []);

  async function handleSelectSuggestion(feature) {
    const [lng, lat] = feature.geometry.coordinates;
    setQuery(feature.properties.label);
    setSelectedLabel(feature.properties.label);
    setSelectedCoords({ lat, lng });
    setSuggestions([]);

    // Appel de la fonction PostGIS (via RPC) pour savoir dans quel
    // quartier tombe ce point.
    const { data, error: rpcError } = await supabase.rpc('find_quartier_for_coordinates', {
      p_lat: lat,
      p_lng: lng,
    });

    if (rpcError) {
      setError("Impossible de vérifier ton quartier pour le moment. Réessaie.");
      return;
    }

    if (data && data.length > 0) {
      setDetectedQuartier(data[0]);
      setScreen(SCREENS.QUARTIER_FOUND);
    } else {
      setDetectedQuartier(null);
      setScreen(SCREENS.NO_QUARTIER);
    }
  }

  async function handleRequestMembership() {
    if (!detectedQuartier) return;
    setSubmitting(true);
    setError('');

    const { data: { user } } = await supabase.auth.getUser();

    const { error: insertError } = await supabase.from('neighborhood_memberships').insert({
      user_id: user.id,
      quartier_id: detectedQuartier.id,
      status: 'pending',
    });

    setSubmitting(false);

    if (insertError) {
      setError("Une erreur est survenue lors de l'envoi de ta demande. Réessaie.");
      return;
    }

    setScreen(SCREENS.MEMBERSHIP_PENDING);
  }

  // ---------------------------------------------------------------------
  // RENDU
  // ---------------------------------------------------------------------

  if (screen === SCREENS.LOADING) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="skeleton h-4 w-40" />
      </div>
    );
  }

  if (screen === SCREENS.MEMBERSHIP_PENDING) {
    return (
      <ScreenCard emoji="🕒" title="Ta demande est en cours d'examen">
        <p>
          Ta demande pour rejoindre{' '}
          <span className="font-medium text-content-primary">
            {detectedQuartier?.name} — {detectedQuartier?.city}
          </span>{' '}
          a bien été envoyée à l'administrateur du quartier.
        </p>
        <p className="mt-3">
          Tu peux déjà découvrir Hoody en attendant. Certaines fonctionnalités
          (messagerie, recherche de voisins) seront disponibles après validation.
        </p>
        <button
          onClick={() => router.push('/')}
          className="mt-6 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover"
        >
          Découvrir Hoody
        </button>
      </ScreenCard>
    );
  }

  if (screen === SCREENS.MEMBERSHIP_APPROVED) {
    return (
      <ScreenCard emoji="🎉" title="Tu fais partie du quartier !">
        <p>
          Ton adhésion à{' '}
          <span className="font-medium text-content-primary">
            {detectedQuartier?.name} — {detectedQuartier?.city}
          </span>{' '}
          est validée.
        </p>
        <button
          onClick={() => router.push('/')}
          className="mt-6 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover"
        >
          Découvrir mes voisins
        </button>
      </ScreenCard>
    );
  }

  if (screen === SCREENS.MEMBERSHIP_REJECTED) {
    return (
      <ScreenCard emoji="😕" title="Ta demande n'a pas été validée">
        <p>
          L'administrateur de quartier n'a pas pu valider ta demande. Tu peux
          réessayer avec une adresse différente.
        </p>
        <button
          onClick={() => setScreen(SCREENS.ADDRESS_FORM)}
          className="mt-6 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover"
        >
          Réessayer
        </button>
      </ScreenCard>
    );
  }

  return (
    <div className="flex min-h-screen flex-col p-6">
      <div className="mx-auto w-full max-w-sm">
        <h1 className="mb-1 text-2xl font-semibold text-content-primary">
          Où habites-tu ?
        </h1>
        <p className="mb-6 text-sm text-content-secondary">
          On va vérifier si Hoody est disponible dans ton secteur.
        </p>

        <div className="relative">
          <input
            type="text"
            value={query}
            onChange={(e) => handleQueryChange(e.target.value)}
            placeholder="7 rue Édouard Branly, Hyères"
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />

          {suggestions.length > 0 && (
            <ul className="absolute z-10 mt-1 w-full overflow-hidden rounded-card border border-border bg-surface shadow-soft">
              {suggestions.map((feature) => (
                <li key={feature.properties.id}>
                  <button
                    onClick={() => handleSelectSuggestion(feature)}
                    className="w-full px-4 py-3 text-left text-sm text-content-primary transition-fast hover:bg-surface-card"
                  >
                    {feature.properties.label}
                  </button>
                </li>
              ))}
            </ul>
          )}

          {searching && (
            <p className="mt-2 text-xs text-content-secondary">Recherche...</p>
          )}
        </div>

        {error && <p className="mt-4 text-sm text-corail">{error}</p>}

        {screen === SCREENS.QUARTIER_FOUND && detectedQuartier && (
          <div className="mt-6 rounded-card border border-border bg-surface-card p-4">
            <p className="text-sm text-content-secondary">Votre quartier semble être :</p>
            <p className="mt-1 text-lg font-semibold text-content-primary">
              {detectedQuartier.name} — {detectedQuartier.city}
            </p>
            <button
              onClick={handleRequestMembership}
              disabled={submitting}
              className="mt-4 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
            >
              {submitting ? 'Envoi...' : 'Demander à rejoindre ce quartier'}
            </button>
          </div>
        )}

        {screen === SCREENS.NO_QUARTIER && (
          <div className="mt-6 rounded-card border border-border bg-surface-card p-4">
            <p className="text-sm text-content-primary">
              Hoody n'est pas encore disponible dans votre secteur.
            </p>
            <p className="mt-2 text-xs text-content-secondary">
              {selectedLabel}
            </p>
            {/* NOTE : le vrai bouton "être prévenu" nécessite une table
                d'attente dédiée — à ajouter dans un chantier ultérieur si
                cette fonctionnalité est jugée prioritaire. */}
          </div>
        )}
      </div>
    </div>
  );
}

function ScreenCard({ emoji, title, children }) {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center p-6 text-center">
      <div className="mx-auto w-full max-w-sm">
        <div className="mb-4 text-4xl">{emoji}</div>
        <h1 className="mb-2 text-xl font-semibold text-content-primary">{title}</h1>
        <div className="text-sm text-content-secondary">{children}</div>
      </div>
    </div>
  );
}

MQEOF_SRC_APP_ONBOARDING_PAGE_JSX

mkdir -p "src/app/offline"
cat > "src/app/offline/page.jsx" << 'MQEOF_SRC_APP_OFFLINE_PAGE_JSX'
export default function OfflinePage() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center p-6 text-center">
      <div className="text-4xl">📡</div>
      <h1 className="mt-4 text-xl font-semibold text-content-primary">
        Vous êtes hors connexion
      </h1>
      <p className="mt-2 text-sm text-content-secondary">
        Reconnecte-toi pour retrouver Hoody. Rien de ce que tu ferais ici ne serait
        envoyé tant que la connexion n'est pas rétablie.
      </p>
    </div>
  );
}

MQEOF_SRC_APP_OFFLINE_PAGE_JSX

mkdir -p "public/icons"
base64 -d > "public/icons/icon-192.png" << 'MQB64EOF_PUBLIC_ICONS_ICON-192_PNG'
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
MQB64EOF_PUBLIC_ICONS_ICON-192_PNG

mkdir -p "public/icons"
base64 -d > "public/icons/icon-512.png" << 'MQB64EOF_PUBLIC_ICONS_ICON-512_PNG'
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
MQB64EOF_PUBLIC_ICONS_ICON-512_PNG

mkdir -p "public"
base64 -d > "public/logo.png" << 'MQB64EOF_PUBLIC_LOGO_PNG'
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
MQB64EOF_PUBLIC_LOGO_PNG

echo "Rebranding applique avec succes."
echo "Prochaine etape : git add -A && git commit -m \"rebranding : Mon Quartier -> Hoody\" && git push"
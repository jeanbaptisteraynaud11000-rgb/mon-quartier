// Server Component. Le middleware redirige déjà automatiquement vers
// /login?next=/invite/[id] si la personne n'est pas connectée (cette route
// n'est pas dans la liste des routes publiques) — pas besoin de le refaire
// ici.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';

const MESSAGES = {
  ok: null, // géré séparément (cas de succès)
  invalid: "Ce lien d'invitation n'existe pas.",
  revoked: 'Cette invitation a été annulée par son émetteur.',
  expired: "Ce lien d'invitation a expiré.",
  exhausted: 'Ce lien a déjà été utilisé.',
  already_member: 'Tu fais déjà partie d\'un quartier — tu ne peux pas en rejoindre un second via ce lien.',
};

export default async function InvitePage({ params }) {
  const { id } = await params;
  const supabase = await createClient();

  const { data, error } = await supabase.rpc('redeem_invitation', {
    p_invitation_id: id,
  });

  const result = data?.[0];

  if (error || !result) {
    return (
      <ScreenMessage emoji="😕" title="Une erreur est survenue">
        Impossible de traiter cette invitation pour le moment. Réessaie plus tard.
      </ScreenMessage>
    );
  }

  if (result.success) {
    return (
      <ScreenMessage emoji="🎉" title="Tu fais maintenant partie du quartier !">
        Ton adhésion à <span className="font-medium text-content-primary">{result.quartier_name}</span> est
        confirmée.
        <div className="mt-6">
          <Link
            href="/voisins"
            className="inline-block h-tap rounded-pill bg-corail px-6 py-3 font-medium text-white transition-fast hover:bg-corail-hover"
          >
            Découvrir mes voisins
          </Link>
        </div>
      </ScreenMessage>
    );
  }

  return (
    <ScreenMessage emoji="😕" title="Cette invitation n'est plus valable">
      {MESSAGES[result.reason] || "Ce lien d'invitation n'est plus valable."}
      <div className="mt-6">
        <Link href="/" className="text-sm font-medium text-corail">
          Retour à l'accueil
        </Link>
      </div>
    </ScreenMessage>
  );
}

function ScreenMessage({ emoji, title, children }) {
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


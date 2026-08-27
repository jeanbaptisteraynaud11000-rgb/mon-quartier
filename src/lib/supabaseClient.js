// Client Supabase utilisable dans les composants client ('use client').
//
// NOTE (chantier #3 - Auth) : lorsqu'on mettra en place l'authentification
// avec gestion de session côté serveur (middleware, Server Components),
// on ajoutera des clients dédiés basés sur @supabase/ssr :
//   - src/lib/supabase/server.js   (pour les Server Components / route handlers)
//   - src/lib/supabase/middleware.js (pour rafraîchir la session sur chaque requête)
// Ce fichier-ci reste le client "navigateur" simple, utilisé pour l'instant
// uniquement pour vérifier la connexion pendant le chantier design system.

import { createBrowserClient } from '@supabase/ssr';

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  );
}

// Instance partagée pour les cas simples (composants client qui ne créent
// pas leur propre instance à chaque rendu).
export const supabase = createClient();


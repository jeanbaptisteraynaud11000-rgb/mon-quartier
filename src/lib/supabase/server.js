// Client Supabase pour l'exécution côté serveur (Server Components,
// Route Handlers, Server Actions). S'appuie sur les cookies Next.js pour
// lire/écrire la session — c'est ce qui permet à Supabase de savoir "qui
// est connecté" même dans un composant qui ne s'exécute jamais dans le
// navigateur.

import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          } catch {
            // `set` peut échouer si appelé depuis un Server Component pur
            // (rendu, pas d'action). Sans conséquence : le middleware
            // (voir middleware.js) se charge de rafraîchir la session sur
            // chaque requête de toute façon.
          }
        },
      },
    }
  );
}


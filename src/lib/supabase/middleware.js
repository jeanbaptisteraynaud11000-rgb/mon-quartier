// Rafraîchit la session Supabase à chaque requête. Appelé depuis
// src/middleware.js. Sans ça, un token expiré côté navigateur ne serait
// jamais renouvelé et l'utilisateur se retrouverait déconnecté sans
// prévenir en plein milieu d'une session.

import { createServerClient } from '@supabase/ssr';
import { NextResponse } from 'next/server';

export async function updateSession(request) {
  let supabaseResponse = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          supabaseResponse = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  // IMPORTANT : getUser() (et non getSession()) car il revalide le token
  // auprès de Supabase à chaque appel, au lieu de faire confiance à un
  // cookie qui pourrait avoir été manipulé côté client.
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return { supabaseResponse, user };
}


// Point d'entrée unique pour tous les liens envoyés par email par Supabase
// (confirmation d'inscription, réinitialisation de mot de passe...).
// Supabase redirige ici avec un ?code=..., qu'on échange contre une vraie
// session, puis on renvoie l'utilisateur vers ?next= (ou / par défaut).

import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function GET(request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get('code');
  const next = searchParams.get('next') ?? '/';

  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      return NextResponse.redirect(`${origin}${next}`);
    }
  }

  return NextResponse.redirect(`${origin}/login?error=confirmation_failed`);
}


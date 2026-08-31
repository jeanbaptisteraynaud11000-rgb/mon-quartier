// Middleware exécuté sur (presque) chaque requête.
//
// Rôle exact et volontairement limité pour ce chantier #3a :
//   1. rafraîchir la session Supabase (voir lib/supabase/middleware.js)
//   2. rediriger vers /login les visiteurs NON connectés qui tentent
//      d'accéder à une route protégée (avec ?next= pour revenir après login)
//   3. rediriger vers / les visiteurs DÉJÀ connectés qui vont sur /login
//      ou /register
//
// Ce que ce middleware NE fait PAS encore (viendra au chantier #3b / #4) :
//   - vérifier le statut de la demande d'adhésion (pending/approved)
//   - restreindre les fonctionnalités sensibles pour un compte "pending"
//     (recherche de voisins, messagerie...) — cette logique doit de toute
//     façon être également garantie par les policies RLS, jamais par le
//     seul middleware.

import { NextResponse } from 'next/server';
import { updateSession } from '@/lib/supabase/middleware';

const PUBLIC_ROUTE_PREFIXES = [
  '/login',
  '/register',
  '/forgot-password',
  '/reset-password',
  '/email-confirmation',
  '/auth',
  '/offline',
  '/confidentialite',
  '/cgu',
  '/mentions-legales',
  '/cookies',
];

function isPublicRoute(pathname) {
  return PUBLIC_ROUTE_PREFIXES.some((prefix) => pathname.startsWith(prefix));
}

export async function middleware(request) {
  const { supabaseResponse, user } = await updateSession(request);
  const { pathname } = request.nextUrl;

  if (!user && !isPublicRoute(pathname)) {
    const redirectUrl = new URL('/login', request.url);
    redirectUrl.searchParams.set('next', pathname);
    return NextResponse.redirect(redirectUrl);
  }

  if (user && (pathname.startsWith('/login') || pathname.startsWith('/register'))) {
    return NextResponse.redirect(new URL('/', request.url));
  }

  return supabaseResponse;
}

export const config = {
  matcher: [
    // Exclut les assets statiques et les images pour ne pas ralentir leur
    // chargement inutilement avec une vérification de session.
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
};


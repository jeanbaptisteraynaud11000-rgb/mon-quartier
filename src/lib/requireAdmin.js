// Garde d'accès pour toutes les pages /admin/*. À appeler en tout premier
// dans chaque Server Component d'une page admin.
//
// NOTE : ceci est une commodité UX (rediriger proprement plutôt que
// laisser une page vide) — la vraie sécurité vient des policies RLS et des
// vérifications is_super_admin()/is_quartier_admin_of() à l'intérieur des
// fonctions SECURITY DEFINER (hide_post, suspend_member...), jamais de ce
// seul contrôle côté frontend (section 43 du prompt maître).

import { redirect } from 'next/navigation';
import { createClient } from './supabase/server';

export async function requireAdmin() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect('/login');

  const { data: profile } = await supabase
    .from('profiles')
    .select('role, quartier_id')
    .eq('user_id', user.id)
    .single();

  if (!profile || (profile.role !== 'quartier_admin' && profile.role !== 'super_admin')) {
    redirect('/');
  }

  return {
    supabase,
    userId: user.id,
    role: profile.role,
    quartierId: profile.quartier_id,
  };
}


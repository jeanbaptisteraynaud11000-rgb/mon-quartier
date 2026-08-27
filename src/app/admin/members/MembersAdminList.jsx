'use client';

import { useEffect, useState, useCallback } from 'react';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';

export default function MembersAdminList() {
  const [members, setMembers] = useState([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);

    // RLS scope déjà le résultat au bon quartier (ou tout, pour un
    // super_admin) — voir profiles_select policy, migration 001.
    const { data: profiles } = await supabase
      .from('profiles')
      .select('user_id, display_name, role, quartier_id, created_at')
      .order('created_at', { ascending: true });

    const userIds = (profiles || []).map((p) => p.user_id);
    const { data: memberships } = await supabase
      .from('neighborhood_memberships')
      .select('user_id, quartier_id, status')
      .in('user_id', userIds.length > 0 ? userIds : ['00000000-0000-0000-0000-000000000000']);

    const statusByUser = Object.fromEntries((memberships || []).map((m) => [m.user_id, m.status]));

    setMembers(
      (profiles || []).map((p) => ({ ...p, status: statusByUser[p.user_id] || 'approved' }))
    );
    setLoading(false);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function handleSuspend(userId, quartierId) {
    const reason = prompt('Motif de la suspension (optionnel) :') || null;
    const { error } = await supabase.rpc('suspend_member', {
      p_user_id: userId,
      p_quartier_id: quartierId,
      p_reason: reason,
    });
    if (!error) load();
  }

  async function handleUnsuspend(userId, quartierId) {
    const { error } = await supabase.rpc('unsuspend_member', {
      p_user_id: userId,
      p_quartier_id: quartierId,
    });
    if (!error) load();
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <Link href="/admin" className="text-sm text-content-secondary">
        ← Administration
      </Link>
      <h1 className="text-xl font-semibold text-content-primary">Membres</h1>

      {loading && <div className="skeleton h-16 w-full" />}

      <div className="flex flex-col gap-2">
        {members.map((member) => (
          <div
            key={member.user_id}
            className="flex items-center justify-between rounded-card border border-border bg-surface-card p-4"
          >
            <div>
              <p className="font-medium text-content-primary">
                {member.display_name || 'Voisin'}
                {member.role !== 'member' && (
                  <span className="ml-2 rounded-pill bg-corail/10 px-2 py-0.5 text-xs font-medium text-corail">
                    {member.role === 'super_admin' ? 'Super admin' : 'Admin'}
                  </span>
                )}
              </p>
              <p className="text-xs text-content-secondary">
                {member.status === 'suspended' ? 'Suspendu' : 'Actif'}
              </p>
            </div>

            {member.role !== 'super_admin' && (
              <div>
                {member.status === 'suspended' ? (
                  <button
                    onClick={() => handleUnsuspend(member.user_id, member.quartier_id)}
                    className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-content-primary hover:bg-surface"
                  >
                    Réactiver
                  </button>
                ) : (
                  <button
                    onClick={() => handleSuspend(member.user_id, member.quartier_id)}
                    className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-corail hover:bg-surface"
                  >
                    Suspendre
                  </button>
                )}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}


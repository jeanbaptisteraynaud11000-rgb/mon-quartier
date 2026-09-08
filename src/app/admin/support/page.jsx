// Server Component protégé — voir requireAdmin().

import { requireAdmin } from '@/lib/requireAdmin';
import SupportStatusSelect from './SupportStatusSelect';

const STATUS_TINT = {
  open: 'bg-corail/10 text-corail',
  in_progress: 'bg-amber-100 text-amber-700',
  closed: 'bg-vert/10 text-vert',
};

export default async function AdminSupportPage() {
  const { supabase } = await requireAdmin();

  const { data: requests } = await supabase
    .from('support_requests')
    .select('id, category, subject, description, status, created_at, user_id')
    .order('created_at', { ascending: false });

  const userIds = [...new Set((requests || []).map((r) => r.user_id))];
  const { data: authors } =
    userIds.length > 0
      ? await supabase.from('profiles').select('user_id, display_name').in('user_id', userIds)
      : { data: [] };
  const authorById = Object.fromEntries((authors || []).map((a) => [a.user_id, a.display_name]));

  return (
    <div className="flex flex-col gap-4 p-4">
      <h1 className="text-xl font-semibold text-content-primary">Demandes de support</h1>

      {(!requests || requests.length === 0) && (
        <p className="text-sm text-content-secondary">Aucune demande pour l'instant.</p>
      )}

      <div className="flex flex-col gap-3">
        {requests?.map((req) => (
          <div key={req.id} className="rounded-card border border-border bg-surface-card p-4">
            <div className="flex items-start justify-between gap-2">
              <div className="min-w-0 flex-1">
                <p className="text-sm font-semibold text-content-primary">{req.subject}</p>
                <p className="text-xs text-content-secondary">
                  {authorById[req.user_id] || 'Voisin'}
                  {req.category ? ` · ${req.category}` : ''} ·{' '}
                  {new Date(req.created_at).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })}
                </p>
              </div>
              <SupportStatusSelect requestId={req.id} status={req.status} />
            </div>
            <p className="mt-2 whitespace-pre-wrap text-sm text-content-primary">{req.description}</p>
          </div>
        ))}
      </div>
    </div>
  );
}


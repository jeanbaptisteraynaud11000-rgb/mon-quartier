import Link from 'next/link';
import { requireAdmin } from '@/lib/requireAdmin';

export default async function AdminDashboard() {
  const { supabase, role, quartierId } = await requireAdmin();

  // super_admin sans quartier propre = vue globale ; sinon toujours scopé
  // au quartier de l'admin (un quartier_admin ne voit jamais au-delà du sien).
  const isGlobalView = role === 'super_admin' && !quartierId;

  async function countFor(table, filters = (q) => q) {
    let query = supabase.from(table).select('*', { count: 'exact', head: true });
    if (!isGlobalView) query = query.eq('quartier_id', quartierId);
    query = filters(query);
    const { count } = await query;
    return count ?? 0;
  }

  const [membersCount, activePostsCount, openReportsCount, suspendedCount, quartiersCount] =
    await Promise.all([
      isGlobalView
        ? supabase.from('profiles').select('*', { count: 'exact', head: true }).then((r) => r.count ?? 0)
        : supabase
            .from('profiles')
            .select('*', { count: 'exact', head: true })
            .eq('quartier_id', quartierId)
            .then((r) => r.count ?? 0),
      countFor('posts', (q) => q.eq('status', 'active')),
      countFor('reports', (q) => q.eq('status', 'open')),
      countFor('neighborhood_memberships', (q) => q.eq('status', 'suspended')),
      isGlobalView
        ? supabase.from('quartiers').select('*', { count: 'exact', head: true }).then((r) => r.count ?? 0)
        : Promise.resolve(null),
    ]);

  return (
    <div className="flex flex-col gap-4 p-4">
      <h1 className="text-xl font-semibold text-content-primary">
        Administration {isGlobalView ? '— vue globale' : ''}
      </h1>

      <div className="grid grid-cols-2 gap-3">
        {isGlobalView && <StatCard label="Quartiers" value={quartiersCount} />}
        <StatCard label="Membres" value={membersCount} />
        <StatCard label="Annonces actives" value={activePostsCount} />
        <StatCard
          label="Signalements ouverts"
          value={openReportsCount}
          href="/admin/reports"
          highlight={openReportsCount > 0}
        />
        <StatCard label="Membres suspendus" value={suspendedCount} href="/admin/members" />
      </div>

      <div className="flex flex-col gap-2">
        <Link
          href="/admin/reports"
          className="rounded-card border border-border bg-surface-card p-4 font-medium text-content-primary transition-fast hover:bg-border/30"
        >
          Signalements →
        </Link>
        <Link
          href="/admin/posts"
          className="rounded-card border border-border bg-surface-card p-4 font-medium text-content-primary transition-fast hover:bg-border/30"
        >
          Annonces →
        </Link>
        <Link
          href="/admin/members"
          className="rounded-card border border-border bg-surface-card p-4 font-medium text-content-primary transition-fast hover:bg-border/30"
        >
          Membres →
        </Link>
      </div>
    </div>
  );
}

function StatCard({ label, value, href, highlight }) {
  const content = (
    <div
      className={`rounded-card border p-4 ${
        highlight ? 'border-corail bg-corail/5' : 'border-border bg-surface-card'
      }`}
    >
      <p className={`text-2xl font-semibold ${highlight ? 'text-corail' : 'text-content-primary'}`}>
        {value}
      </p>
      <p className="text-sm text-content-secondary">{label}</p>
    </div>
  );

  if (href) {
    return (
      <Link href={href} className="transition-fast hover:opacity-80">
        {content}
      </Link>
    );
  }
  return content;
}


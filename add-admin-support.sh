#!/usr/bin/env bash
set -e
echo "Page admin support + notifications..."

mkdir -p "src/app/admin/support"
cat > "src/app/admin/support/SupportStatusSelect.jsx" << 'MQEOF_SRC_APP_ADMIN_SUPPORT_SUPPORTSTATUSSELECT_JSX'
'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';

const STATUS_OPTIONS = [
  { value: 'open', label: 'Ouverte' },
  { value: 'in_progress', label: 'En cours' },
  { value: 'closed', label: 'Fermée' },
];

export default function SupportStatusSelect({ requestId, status }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  async function handleChange(e) {
    setBusy(true);
    await supabase.from('support_requests').update({ status: e.target.value }).eq('id', requestId);
    setBusy(false);
    router.refresh();
  }

  return (
    <select
      value={status}
      onChange={handleChange}
      disabled={busy}
      className="rounded-pill border border-border bg-surface px-2 py-1 text-xs font-medium text-content-primary"
    >
      {STATUS_OPTIONS.map((opt) => (
        <option key={opt.value} value={opt.value}>{opt.label}</option>
      ))}
    </select>
  );
}

MQEOF_SRC_APP_ADMIN_SUPPORT_SUPPORTSTATUSSELECT_JSX

mkdir -p "src/app/admin/support"
cat > "src/app/admin/support/page.jsx" << 'MQEOF_SRC_APP_ADMIN_SUPPORT_PAGE_JSX'
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

MQEOF_SRC_APP_ADMIN_SUPPORT_PAGE_JSX

mkdir -p "src/app/admin"
cat > "src/app/admin/page.jsx" << 'MQEOF_SRC_APP_ADMIN_PAGE_JSX'
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
        <Link
          href="/admin/commerces"
          className="rounded-card border border-border bg-surface-card p-4 font-medium text-content-primary transition-fast hover:bg-border/30"
        >
          Commerces — sponsoring & offres →
        </Link>
        <Link
          href="/admin/support"
          className="rounded-card border border-border bg-surface-card p-4 font-medium text-content-primary transition-fast hover:bg-border/30"
        >
          Demandes de support →
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

MQEOF_SRC_APP_ADMIN_PAGE_JSX

mkdir -p "src/app/notifications"
cat > "src/app/notifications/page.jsx" << 'MQEOF_SRC_APP_NOTIFICATIONS_PAGE_JSX'
'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { formatRelativeTime } from '@/lib/postTypes';
import { Bell, MessageCircle, CalendarCheck, CalendarX, UserPlus, MapPin, Tag, LifeBuoy } from 'lucide-react';

const ICONS = {
  message: MessageCircle,
  event_join: CalendarCheck,
  event_cancelled: CalendarX,
  invitation_used: UserPlus,
  watched_alert: MapPin,
  offer_pending: Tag,
  support_request: LifeBuoy,
};

export default function NotificationsPage() {
  const router = useRouter();
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(true);

  async function load() {
    const { data } = await supabase
      .from('notifications')
      .select('id, type, title, body, link, read_at, created_at')
      .order('created_at', { ascending: false })
      .limit(50);
    setNotifications(data || []);
    setLoading(false);
  }

  useEffect(() => {
    load();
  }, []);

  async function handleClick(notif) {
    if (!notif.read_at) {
      await supabase.from('notifications').update({ read_at: new Date().toISOString() }).eq('id', notif.id);
    }
    if (notif.link) router.push(notif.link);
  }

  async function handleMarkAllRead() {
    await supabase.rpc('mark_all_notifications_read');
    load();
  }

  const hasUnread = notifications.some((n) => !n.read_at);

  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-content-primary">Notifications</h1>
        {hasUnread && (
          <button onClick={handleMarkAllRead} className="text-sm font-medium text-corail">
            Tout marquer comme lu
          </button>
        )}
      </div>

      {loading && <div className="skeleton h-16 w-full" />}

      {!loading && notifications.length === 0 && (
        <div className="rounded-card border border-border bg-surface-card p-6 text-center text-sm text-content-secondary">
          <Bell size={22} className="mx-auto mb-2 text-content-secondary" />
          Aucune notification pour l'instant.
        </div>
      )}

      <div className="flex flex-col gap-2">
        {notifications.map((notif) => {
          const Icon = ICONS[notif.type] || Bell;
          return (
            <button
              key={notif.id}
              onClick={() => handleClick(notif)}
              className={`flex w-full items-start gap-3 rounded-card border p-3 text-left transition-fast hover:bg-border/20 ${
                notif.read_at ? 'border-border bg-surface-card' : 'border-corail/30 bg-corail/5'
              }`}
            >
              <div className="mt-0.5 flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-pill bg-surface text-content-secondary">
                <Icon size={16} />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-sm font-medium text-content-primary">{notif.title}</p>
                {notif.body && (
                  <p className="mt-0.5 line-clamp-1 text-sm text-content-secondary">{notif.body}</p>
                )}
                <p className="mt-0.5 text-xs text-content-secondary">
                  {formatRelativeTime(notif.created_at)}
                </p>
              </div>
              {!notif.read_at && <div className="mt-1.5 h-2 w-2 flex-shrink-0 rounded-pill bg-corail" />}
            </button>
          );
        })}
      </div>
    </div>
  );
}

MQEOF_SRC_APP_NOTIFICATIONS_PAGE_JSX

echo "Admin support ajoute avec succes."
echo "Prochaine etape : executer la migration 042, puis git add -A && git commit -m \"admin support : page + notification\" && git push"
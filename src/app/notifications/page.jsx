'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { formatRelativeTime } from '@/lib/postTypes';
import { Bell, MessageCircle, CalendarCheck, CalendarX, UserPlus } from 'lucide-react';

const ICONS = {
  message: MessageCircle,
  event_join: CalendarCheck,
  event_cancelled: CalendarX,
  invitation_used: UserPlus,
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


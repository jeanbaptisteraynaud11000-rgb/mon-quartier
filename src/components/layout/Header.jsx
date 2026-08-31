'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { Bell, MessageCircle } from 'lucide-react';
import { supabase } from '@/lib/supabaseClient';

// Le badge "cloche" compte les notifications non-message (event_join,
// event_cancelled, invitation_used) ; le badge "messages" compte
// spécifiquement les notifications de type message — évite de compter la
// même chose deux fois entre les deux icônes.

function IconButton({ href, ariaLabel, count, children }) {
  return (
    <Link
      href={href}
      aria-label={ariaLabel}
      className="relative flex h-tap w-tap items-center justify-center rounded-pill text-content-primary transition-fast hover:bg-surface-card active:scale-95"
    >
      {children}
      {count > 0 && (
        <span className="absolute -top-0.5 -right-0.5 flex h-4 min-w-4 items-center justify-center rounded-pill bg-corail px-1 text-[10px] font-semibold text-white">
          {count > 9 ? '9+' : count}
        </span>
      )}
    </Link>
  );
}

export default function Header() {
  const [notifCount, setNotifCount] = useState(0);
  const [messageCount, setMessageCount] = useState(0);

  useEffect(() => {
    let userId = null;

    async function loadCounts() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;
      userId = user.id;

      const { count: notifs } = await supabase
        .from('notifications')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .is('read_at', null)
        .neq('type', 'message');

      const { count: messages } = await supabase
        .from('notifications')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .is('read_at', null)
        .eq('type', 'message');

      setNotifCount(notifs || 0);
      setMessageCount(messages || 0);
    }

    loadCounts();

    // Temps réel : dès qu'une notification arrive (ou est marquée lue dans
    // un autre onglet), on rafraîchit les compteurs.
    const channel = supabase
      .channel('header-notifications')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'notifications' },
        () => loadCounts()
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  return (
    <header className="safe-top sticky top-0 z-40 flex h-14 items-center justify-between border-b border-border bg-surface/95 px-4 backdrop-blur">
      <Link href="/" className="flex items-center" aria-label="Hoody, accueil">
        <Image src="/logo.png" alt="Hoody" width={96} height={30} priority className="h-6 w-auto" />
      </Link>

      <div className="flex items-center gap-1">
        <IconButton href="/notifications" ariaLabel="Notifications" count={notifCount}>
          <Bell size={22} strokeWidth={1.8} />
        </IconButton>
        <IconButton href="/messages" ariaLabel="Messages" count={messageCount}>
          <MessageCircle size={22} strokeWidth={1.8} />
        </IconButton>
      </div>
    </header>
  );
}


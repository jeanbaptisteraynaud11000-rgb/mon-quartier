#!/usr/bin/env bash
set -e
echo "Ajout du systeme de notifications..."

mkdir -p "src/app/notifications"
cat > "src/app/notifications/page.jsx" << 'MQEOF_SRC_APP_NOTIFICATIONS_PAGE_JSX'
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

MQEOF_SRC_APP_NOTIFICATIONS_PAGE_JSX

mkdir -p "src/components/layout"
cat > "src/components/layout/Header.jsx" << 'MQEOF_SRC_COMPONENTS_LAYOUT_HEADER_JSX'
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

MQEOF_SRC_COMPONENTS_LAYOUT_HEADER_JSX

mkdir -p "src/app/messages/[id]"
cat > "src/app/messages/[id]/page.jsx" << 'MQEOF_SRC_APP_MESSAGES_ID_PAGE_JSX'
'use client';

import { useEffect, useRef, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';
import ReportSheet from '@/components/ReportSheet';

export default function ConversationPage() {
  const { id: conversationId } = useParams();
  const router = useRouter();

  const [currentUserId, setCurrentUserId] = useState(null);
  const [otherUserId, setOtherUserId] = useState(null);
  const [otherName, setOtherName] = useState('Voisin');
  const [postTitle, setPostTitle] = useState(null);
  const [messages, setMessages] = useState([]);
  const [content, setContent] = useState('');
  const [loading, setLoading] = useState(true);
  const [forbidden, setForbidden] = useState(false);
  const [sending, setSending] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [reportOpen, setReportOpen] = useState(false);
  const [blocked, setBlocked] = useState(false);

  const bottomRef = useRef(null);

  useEffect(() => {
    async function load() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        router.push('/login');
        return;
      }
      setCurrentUserId(user.id);

      // La policy RLS garantit déjà qu'on ne peut lire que ses propres
      // conversations — si ce n'est pas la nôtre, `members` sera vide.
      const { data: members } = await supabase
        .from('conversation_members')
        .select('user_id')
        .eq('conversation_id', conversationId);

      const isMember = members?.some((m) => m.user_id === user.id);
      if (!members || members.length === 0 || !isMember) {
        setForbidden(true);
        setLoading(false);
        return;
      }

      const otherUserId = members.find((m) => m.user_id !== user.id)?.user_id;
      if (otherUserId) {
        setOtherUserId(otherUserId);
        const { data: otherProfile } = await supabase
          .from('profiles')
          .select('display_name')
          .eq('user_id', otherUserId)
          .single();
        setOtherName(otherProfile?.display_name || 'Voisin');

        const { data: existingBlock } = await supabase
          .from('blocks')
          .select('blocker_id')
          .eq('blocker_id', user.id)
          .eq('blocked_id', otherUserId)
          .maybeSingle();
        setBlocked(!!existingBlock);
      }

      const { data: conversation } = await supabase
        .from('conversations')
        .select('post_id, posts(title)')
        .eq('id', conversationId)
        .single();
      setPostTitle(conversation?.posts?.title || null);

      const { data: existingMessages } = await supabase
        .from('messages')
        .select('id, sender_id, content, created_at')
        .eq('conversation_id', conversationId)
        .order('created_at', { ascending: true });

      setMessages(existingMessages || []);
      setLoading(false);

      // Marque comme lu.
      await supabase
        .from('conversation_members')
        .update({ last_read_at: new Date().toISOString() })
        .eq('conversation_id', conversationId)
        .eq('user_id', user.id);

      // Marque aussi les notifications de message liées à cette conversation
      // comme lues, sinon le badge du header resterait allumé.
      await supabase
        .from('notifications')
        .update({ read_at: new Date().toISOString() })
        .eq('user_id', user.id)
        .eq('type', 'message')
        .eq('link', `/messages/${conversationId}`)
        .is('read_at', null);
    }

    load();
  }, [conversationId, router]);

  // Réception en temps réel des nouveaux messages de cette conversation.
  useEffect(() => {
    const channel = supabase
      .channel(`messages:${conversationId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'messages',
          filter: `conversation_id=eq.${conversationId}`,
        },
        (payload) => {
          setMessages((prev) => {
            if (prev.some((m) => m.id === payload.new.id)) return prev;
            return [...prev, payload.new];
          });
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [conversationId]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  async function handleSend(e) {
    e.preventDefault();
    if (!content.trim() || sending) return;

    setSending(true);
    const { error } = await supabase.from('messages').insert({
      conversation_id: conversationId,
      sender_id: currentUserId,
      content: content.trim(),
    });
    setSending(false);

    if (!error) {
      setContent('');
    }
  }

  async function handleBlock() {
    if (!confirm(`Bloquer ${otherName} ? Vous ne pourrez plus échanger de messages.`)) return;
    const { error } = await supabase.from('blocks').insert({
      blocker_id: currentUserId,
      blocked_id: otherUserId,
    });
    if (!error) {
      setBlocked(true);
      setMenuOpen(false);
    }
  }

  async function handleUnblock() {
    const { error } = await supabase
      .from('blocks')
      .delete()
      .eq('blocker_id', currentUserId)
      .eq('blocked_id', otherUserId);
    if (!error) {
      setBlocked(false);
      setMenuOpen(false);
    }
  }

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="skeleton h-4 w-40" />
      </div>
    );
  }

  if (forbidden) {
    return (
      <div className="p-6 text-center text-content-secondary">
        Cette conversation n'existe pas ou tu n'y as pas accès.
      </div>
    );
  }

  return (
    <div className="flex h-screen flex-col">
      <div className="border-b border-border bg-surface p-4">
        <div className="flex items-center justify-between">
          <Link href="/messages" className="text-sm text-content-secondary">
            ← Messages
          </Link>
          <div className="relative">
            <button
              onClick={() => setMenuOpen((v) => !v)}
              aria-label="Options"
              className="flex h-tap w-tap items-center justify-center rounded-pill text-content-secondary hover:bg-surface-card"
            >
              ⋯
            </button>
            {menuOpen && (
              <div className="absolute right-0 top-full z-10 mt-1 w-48 rounded-card border border-border bg-surface py-1 shadow-soft">
                <button
                  onClick={() => {
                    setReportOpen(true);
                    setMenuOpen(false);
                  }}
                  className="block w-full px-4 py-2 text-left text-sm text-content-primary hover:bg-surface-card"
                >
                  Signaler
                </button>
                {blocked ? (
                  <button
                    onClick={handleUnblock}
                    className="block w-full px-4 py-2 text-left text-sm text-content-primary hover:bg-surface-card"
                  >
                    Débloquer {otherName}
                  </button>
                ) : (
                  <button
                    onClick={handleBlock}
                    className="block w-full px-4 py-2 text-left text-sm text-corail hover:bg-surface-card"
                  >
                    Bloquer {otherName}
                  </button>
                )}
              </div>
            )}
          </div>
        </div>
        <h1 className="mt-1 font-semibold text-content-primary">{otherName}</h1>
        {postTitle && (
          <p className="text-xs text-content-secondary">À propos de : {postTitle}</p>
        )}
      </div>

      <div className="flex-1 overflow-y-auto p-4">
        <div className="flex flex-col gap-2">
          {messages.map((msg) => {
            const isMine = msg.sender_id === currentUserId;
            return (
              <div
                key={msg.id}
                className={`max-w-[75%] rounded-card px-4 py-2 text-sm ${
                  isMine
                    ? 'self-end bg-corail text-white'
                    : 'self-start bg-surface-card text-content-primary'
                }`}
              >
                {msg.content}
              </div>
            );
          })}
          <div ref={bottomRef} />
        </div>
      </div>

      {blocked ? (
        <div className="safe-bottom border-t border-border bg-surface p-4 text-center text-sm text-content-secondary">
          Tu as bloqué {otherName}. Débloque-la pour reprendre la conversation.
        </div>
      ) : (
        <form onSubmit={handleSend} className="safe-bottom flex gap-2 border-t border-border bg-surface p-3">
          <input
            type="text"
            value={content}
            onChange={(e) => setContent(e.target.value)}
            placeholder="Écris un message..."
            className="flex-1 rounded-pill border border-border bg-surface px-4 py-2 text-content-primary outline-none transition-fast focus:border-corail"
          />
          <button
            type="submit"
            disabled={sending || !content.trim()}
            className="rounded-pill bg-corail px-5 py-2 font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
          >
            Envoyer
          </button>
        </form>
      )}

      <ReportSheet
        open={reportOpen}
        onClose={() => setReportOpen(false)}
        targetType="conversation"
        targetId={conversationId}
      />
    </div>
  );
}

MQEOF_SRC_APP_MESSAGES_ID_PAGE_JSX

echo "Notifications ajoutees avec succes."
echo "Prochaine etape : executer la migration 019, puis git add -A && git commit -m \"notifications temps reel\" && git push"
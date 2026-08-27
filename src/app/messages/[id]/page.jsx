'use client';

import { useEffect, useRef, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';

export default function ConversationPage() {
  const { id: conversationId } = useParams();
  const router = useRouter();

  const [currentUserId, setCurrentUserId] = useState(null);
  const [otherName, setOtherName] = useState('Voisin');
  const [postTitle, setPostTitle] = useState(null);
  const [messages, setMessages] = useState([]);
  const [content, setContent] = useState('');
  const [loading, setLoading] = useState(true);
  const [forbidden, setForbidden] = useState(false);
  const [sending, setSending] = useState(false);

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
        const { data: otherProfile } = await supabase
          .from('profiles')
          .select('display_name')
          .eq('user_id', otherUserId)
          .single();
        setOtherName(otherProfile?.display_name || 'Voisin');
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
        <Link href="/messages" className="text-sm text-content-secondary">
          ← Messages
        </Link>
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
    </div>
  );
}


#!/usr/bin/env bash
set -e
echo "Ajout du chantier #7 (messagerie)..."

mkdir -p "src/app/messages"
cat > "src/app/messages/page.jsx" << 'MQEOF_SRC_APP_MESSAGES_PAGE_JSX'
// Server Component : liste des conversations, triée par activité récente.
// Pas de jointure imbriquée profiles/posts (pas de FK directe, voir les
// pages annonces pour le même choix) — on fait des requêtes séparées.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { formatRelativeTime } from '@/lib/postTypes';

export default async function MessagesPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: memberships } = await supabase
    .from('conversation_members')
    .select('conversation_id')
    .eq('user_id', user.id);

  const conversationIds = (memberships || []).map((m) => m.conversation_id);

  if (conversationIds.length === 0) {
    return (
      <div className="p-4">
        <div className="rounded-card border border-border bg-surface-card p-6 text-center text-sm text-content-secondary">
          Aucun message pour le moment.
          <p className="mt-1">
            Lorsque tu discuteras avec un voisin, votre conversation apparaîtra ici.
          </p>
        </div>
      </div>
    );
  }

  const { data: conversations } = await supabase
    .from('conversations')
    .select('id, post_id, last_message_at, posts(title)')
    .in('id', conversationIds)
    .order('last_message_at', { ascending: false });

  // Autres participants de chaque conversation (tout le monde sauf moi)
  const { data: allMembers } = await supabase
    .from('conversation_members')
    .select('conversation_id, user_id')
    .in('conversation_id', conversationIds)
    .neq('user_id', user.id);

  const otherUserIds = [...new Set((allMembers || []).map((m) => m.user_id))];
  const { data: profiles } = await supabase
    .from('profiles')
    .select('user_id, display_name')
    .in('user_id', otherUserIds.length > 0 ? otherUserIds : ['00000000-0000-0000-0000-000000000000']);

  const nameByUserId = Object.fromEntries((profiles || []).map((p) => [p.user_id, p.display_name]));
  const otherUserIdByConversation = Object.fromEntries(
    (allMembers || []).map((m) => [m.conversation_id, m.user_id])
  );

  // Dernier message de chaque conversation, pour l'aperçu
  const { data: lastMessages } = await supabase
    .from('messages')
    .select('conversation_id, content, created_at')
    .in('conversation_id', conversationIds)
    .order('created_at', { ascending: false });

  const previewByConversation = {};
  for (const msg of lastMessages || []) {
    if (!previewByConversation[msg.conversation_id]) {
      previewByConversation[msg.conversation_id] = msg;
    }
  }

  return (
    <div className="flex flex-col gap-2 p-4">
      {conversations?.map((conv) => {
        const otherUserId = otherUserIdByConversation[conv.id];
        const otherName = nameByUserId[otherUserId] || 'Voisin';
        const preview = previewByConversation[conv.id];

        return (
          <Link
            key={conv.id}
            href={`/messages/${conv.id}`}
            className="flex flex-col gap-1 rounded-card border border-border bg-surface-card p-4 transition-fast hover:bg-border/30"
          >
            <div className="flex items-center justify-between">
              <span className="font-semibold text-content-primary">{otherName}</span>
              <span className="text-xs text-content-secondary">
                {formatRelativeTime(conv.last_message_at)}
              </span>
            </div>
            {conv.posts?.title && (
              <span className="text-xs text-content-secondary">
                À propos de : {conv.posts.title}
              </span>
            )}
            {preview && (
              <p className="truncate text-sm text-content-secondary">{preview.content}</p>
            )}
          </Link>
        );
      })}
    </div>
  );
}

MQEOF_SRC_APP_MESSAGES_PAGE_JSX

mkdir -p "src/app/messages/[id]"
cat > "src/app/messages/[id]/page.jsx" << 'MQEOF_SRC_APP_MESSAGES_ID_PAGE_JSX'
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

MQEOF_SRC_APP_MESSAGES_ID_PAGE_JSX

mkdir -p "src/app/annonces/[id]"
cat > "src/app/annonces/[id]/ContactActions.jsx" << 'MQEOF_SRC_APP_ANNONCES_ID_CONTACTACTIONS_JSX'
'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';

// NOTE : "Signaler" nécessite la table `reports` + modération (Phase 5,
// pas encore construite). "Contacter" et "Partager" sont pleinement
// fonctionnels.

export default function ContactActions({ postId, postAuthorId, postTitle }) {
  const router = useRouter();
  const [notice, setNotice] = useState('');
  const [contacting, setContacting] = useState(false);

  async function handleContact() {
    setContacting(true);
    setNotice('');

    const { data: conversationId, error } = await supabase.rpc('start_conversation', {
      p_other_user_id: postAuthorId,
      p_post_id: postId,
    });

    setContacting(false);

    if (error || !conversationId) {
      setNotice("Impossible de démarrer la conversation pour le moment.");
      return;
    }

    router.push(`/messages/${conversationId}`);
  }

  async function handleShare() {
    const url = window.location.href;
    if (navigator.share) {
      try {
        await navigator.share({ title: postTitle, url });
      } catch {
        // L'utilisateur a annulé le partage — rien à faire.
      }
    } else {
      await navigator.clipboard.writeText(url);
      setNotice('Lien copié !');
      setTimeout(() => setNotice(''), 2000);
    }
  }

  return (
    <div className="flex flex-col gap-2">
      <div className="grid grid-cols-3 gap-2">
        <button
          onClick={handleContact}
          disabled={contacting}
          className="h-tap rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface-card disabled:opacity-60"
        >
          {contacting ? '...' : 'Contacter'}
        </button>
        <button
          onClick={() => setNotice('Le signalement arrive dans un prochain chantier.')}
          className="h-tap rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface-card"
        >
          Signaler
        </button>
        <button
          onClick={handleShare}
          className="h-tap rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface-card"
        >
          Partager
        </button>
      </div>
      {notice && <p className="text-center text-sm text-content-secondary">{notice}</p>}
    </div>
  );
}

MQEOF_SRC_APP_ANNONCES_ID_CONTACTACTIONS_JSX

mkdir -p "src/app/annonces/[id]"
cat > "src/app/annonces/[id]/page.jsx" << 'MQEOF_SRC_APP_ANNONCES_ID_PAGE_JSX'
// Server Component : détail d'une annonce. La policy RLS "posts_select_own_quartier"
// garantit déjà qu'on ne peut pas voir l'annonce d'un autre quartier — si
// jamais quelqu'un force une URL /annonces/[id] hors de son quartier, la
// requête retourne simplement "non trouvé", jamais les données.

import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';
import ContactActions from './ContactActions';

export default async function AnnonceDetailPage({ params }) {
  const { id } = await params;
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: post, error } = await supabase
    .from('posts')
    .select('id, type, title, description, availability, approx_zone, created_at, user_id')
    .eq('id', id)
    .single();

  if (error || !post) {
    notFound();
  }

  // Requête séparée pour l'auteur : il n'existe pas de clé étrangère directe
  // entre `posts` et `profiles` (les deux référencent `auth.users`
  // séparément), donc une jointure imbriquée `profiles(...)` échouerait.
  const { data: authorProfile } = await supabase
    .from('profiles')
    .select('display_name')
    .eq('user_id', post.user_id)
    .single();

  const typeInfo = getPostTypeInfo(post.type);
  const isOwnPost = post.user_id === user.id;
  const authorName = authorProfile?.display_name || 'Voisin';

  // Autres annonces du même auteur (hors celle-ci)
  const { data: otherPosts } = await supabase
    .from('posts')
    .select('id, title, type')
    .eq('user_id', post.user_id)
    .eq('status', 'active')
    .neq('id', post.id)
    .limit(3);

  return (
    <div className="flex flex-col gap-5 p-4">
      <Link href="/annonces" className="text-sm font-medium text-content-secondary">
        ← Retour aux annonces
      </Link>

      <div className="rounded-card border border-border bg-surface-card p-5">
        <div className="flex items-center gap-2">
          <span className="text-xl">{typeInfo.emoji}</span>
          <span className="text-sm font-medium text-content-secondary">{typeInfo.label}</span>
        </div>

        <h1 className="mt-3 text-xl font-semibold text-content-primary">{post.title}</h1>

        <div className="mt-2 flex items-center gap-2 text-sm text-content-secondary">
          <span>{authorName}</span>
          <span>·</span>
          <span>{formatRelativeTime(post.created_at)}</span>
        </div>

        {post.description && (
          <p className="mt-4 whitespace-pre-wrap text-content-primary">{post.description}</p>
        )}

        {post.availability && (
          <p className="mt-3 text-sm text-content-secondary">
            <span className="font-medium text-content-primary">Disponibilité : </span>
            {post.availability}
          </p>
        )}

        {post.approx_zone && (
          <p className="mt-1 text-sm text-content-secondary">
            <span className="font-medium text-content-primary">Zone : </span>
            {post.approx_zone}
          </p>
        )}
      </div>

      {!isOwnPost && (
        <ContactActions postId={post.id} postAuthorId={post.user_id} postTitle={post.title} />
      )}

      {isOwnPost && (
        <div className="rounded-card border border-border bg-surface-card p-4 text-center text-sm text-content-secondary">
          C'est ta propre annonce.{' '}
          <Link href="/mes-annonces" className="font-medium text-corail">
            Gérer mes annonces
          </Link>
        </div>
      )}

      {otherPosts?.length > 0 && (
        <div>
          <h2 className="mb-2 text-sm font-medium text-content-secondary">
            Autres annonces de {authorName}
          </h2>
          <div className="flex flex-col gap-2">
            {otherPosts.map((op) => (
              <Link
                key={op.id}
                href={`/annonces/${op.id}`}
                className="rounded-card border border-border bg-surface-card p-3 text-sm text-content-primary transition-fast hover:bg-border/30"
              >
                {getPostTypeInfo(op.type).emoji} {op.title}
              </Link>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

MQEOF_SRC_APP_ANNONCES_ID_PAGE_JSX

echo "Chantier #7 ajoute avec succes."
echo "Prochaine etape : git add -A && git commit -m \"chantier 7 : messagerie\" && git push"
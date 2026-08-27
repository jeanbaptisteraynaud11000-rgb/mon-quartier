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


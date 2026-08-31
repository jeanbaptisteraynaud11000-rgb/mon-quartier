'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import ReportSheet from '@/components/ReportSheet';

// NOTE : le partage a été déplacé dans PostHeaderActions (icône en overlay
// sur la photo). Ici il ne reste que Contacter et Signaler.

export default function ContactActions({ postId, postAuthorId }) {
  const router = useRouter();
  const [notice, setNotice] = useState('');
  const [contacting, setContacting] = useState(false);
  const [reportOpen, setReportOpen] = useState(false);

  async function handleContact() {
    setContacting(true);
    setNotice('');

    const { data: conversationId, error } = await supabase.rpc('start_conversation', {
      p_other_user_id: postAuthorId,
      p_post_id: postId,
    });

    setContacting(false);

    if (error || !conversationId) {
      setNotice(error?.message?.includes('bloqu')
        ? "Vous ne pouvez pas contacter cette personne."
        : "Impossible de démarrer la conversation pour le moment.");
      return;
    }

    router.push(`/messages/${conversationId}`);
  }

  return (
    <div className="flex flex-col gap-2">
      <div className="flex gap-2">
        <button
          onClick={handleContact}
          disabled={contacting}
          className="h-tap flex-1 rounded-pill bg-vert font-medium text-white transition-fast hover:opacity-90 disabled:opacity-60"
        >
          {contacting ? '...' : 'Contacter'}
        </button>
        <button
          onClick={() => setReportOpen(true)}
          className="h-tap rounded-pill border border-border px-4 font-medium text-content-secondary transition-fast hover:bg-surface-card"
        >
          Signaler
        </button>
      </div>
      {notice && <p className="text-center text-sm text-content-secondary">{notice}</p>}

      <ReportSheet
        open={reportOpen}
        onClose={() => setReportOpen(false)}
        targetType="post"
        targetId={postId}
      />
    </div>
  );
}


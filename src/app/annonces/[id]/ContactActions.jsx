'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import ReportSheet from '@/components/ReportSheet';

export default function ContactActions({ postId, postAuthorId, postTitle }) {
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
          onClick={() => setReportOpen(true)}
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

      <ReportSheet
        open={reportOpen}
        onClose={() => setReportOpen(false)}
        targetType="post"
        targetId={postId}
      />
    </div>
  );
}


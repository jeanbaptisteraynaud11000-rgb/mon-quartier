'use client';

import { useState, useRef, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { MoreVertical } from 'lucide-react';
import { supabase } from '@/lib/supabaseClient';
import ReportSheet from '@/components/ReportSheet';

export default function PostCardMenu({ postId, isOwnPost }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [reportOpen, setReportOpen] = useState(false);
  const ref = useRef(null);

  useEffect(() => {
    function handleClickOutside(e) {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false);
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  async function handleMarkCompleted(e) {
    e.preventDefault();
    e.stopPropagation();
    await supabase.from('posts').update({ status: 'completed' }).eq('id', postId);
    setOpen(false);
    router.refresh();
  }

  async function handleDelete(e) {
    e.preventDefault();
    e.stopPropagation();
    if (!confirm('Supprimer cette annonce ?')) return;
    await supabase.from('posts').update({ status: 'deleted' }).eq('id', postId);
    setOpen(false);
    router.refresh();
  }

  return (
    <div ref={ref} className="relative flex-shrink-0">
      <button
        onClick={(e) => {
          e.preventDefault();
          e.stopPropagation();
          setOpen((v) => !v);
        }}
        aria-label="Options"
        className="flex h-7 w-7 items-center justify-center rounded-pill text-content-secondary hover:bg-surface-card"
      >
        <MoreVertical size={16} />
      </button>

      {open && (
        <div className="absolute right-0 top-full z-10 mt-1 w-44 overflow-hidden rounded-card border border-border bg-surface shadow-soft">
          {isOwnPost ? (
            <>
              <Link
                href={`/annonces/${postId}/edit`}
                onClick={(e) => e.stopPropagation()}
                className="block px-4 py-2 text-left text-sm text-content-primary hover:bg-surface-card"
              >
                Modifier
              </Link>
              <button
                onClick={handleMarkCompleted}
                className="block w-full px-4 py-2 text-left text-sm text-content-primary hover:bg-surface-card"
              >
                Marquer terminé
              </button>
              <button
                onClick={handleDelete}
                className="block w-full px-4 py-2 text-left text-sm text-corail hover:bg-surface-card"
              >
                Supprimer
              </button>
            </>
          ) : (
            <button
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                setReportOpen(true);
                setOpen(false);
              }}
              className="block w-full px-4 py-2 text-left text-sm text-content-primary hover:bg-surface-card"
            >
              Signaler
            </button>
          )}
        </div>
      )}

      <ReportSheet
        open={reportOpen}
        onClose={() => setReportOpen(false)}
        targetType="post"
        targetId={postId}
      />
    </div>
  );
}


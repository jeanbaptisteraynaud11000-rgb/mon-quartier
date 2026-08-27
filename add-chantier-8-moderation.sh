#!/usr/bin/env bash
set -e
echo "Ajout du chantier #8 (Phase 5 : signalement, blocage, moderation, admin)..."

mkdir -p "src/components"
cat > "src/components/ReportSheet.jsx" << 'MQEOF_SRC_COMPONENTS_REPORTSHEET_JSX'
'use client';

import { useState } from 'react';
import { supabase } from '@/lib/supabaseClient';

const REASONS = [
  { value: 'inapproprie', label: 'Contenu inapproprié' },
  { value: 'spam', label: 'Spam' },
  { value: 'usurpation', label: 'Usurpation' },
  { value: 'harcelement', label: 'Harcèlement' },
  { value: 'arnaque', label: 'Arnaque' },
  { value: 'autre', label: 'Autre' },
];

export default function ReportSheet({ open, onClose, targetType, targetId }) {
  const [reason, setReason] = useState(null);
  const [details, setDetails] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState('');

  if (!open) return null;

  async function handleSubmit() {
    if (!reason) return;
    setSubmitting(true);
    setError('');

    const { data: { user } } = await supabase.auth.getUser();
    const { data: profile } = await supabase
      .from('profiles')
      .select('quartier_id')
      .eq('user_id', user.id)
      .single();

    const { error: insertError } = await supabase.from('reports').insert({
      reporter_id: user.id,
      quartier_id: profile.quartier_id,
      target_type: targetType,
      target_id: targetId,
      reason,
      details: details.trim() || null,
    });

    setSubmitting(false);

    if (insertError) {
      setError('Une erreur est survenue. Réessaie.');
      return;
    }

    setDone(true);
  }

  function handleClose() {
    setReason(null);
    setDetails('');
    setDone(false);
    setError('');
    onClose();
  }

  return (
    <div className="fixed inset-0 z-50" role="dialog" aria-modal="true">
      <button
        aria-label="Fermer"
        onClick={handleClose}
        className="absolute inset-0 bg-black/40"
      />
      <div className="safe-bottom absolute bottom-0 left-0 right-0 rounded-t-sheet bg-surface p-6 shadow-sheet">
        <div className="mx-auto mb-4 h-1 w-10 rounded-pill bg-border" />

        {done ? (
          <div className="py-4 text-center">
            <p className="font-medium text-content-primary">
              Merci, votre signalement a été pris en compte.
            </p>
            <p className="mt-1 text-sm text-content-secondary">
              La communauté et nos modérateurs veilleront à la suite.
            </p>
            <button
              onClick={handleClose}
              className="mt-4 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover"
            >
              Fermer
            </button>
          </div>
        ) : (
          <>
            <h2 className="mb-4 text-lg font-semibold text-content-primary">
              Pourquoi souhaitez-vous signaler ce contenu ?
            </h2>

            <div className="flex flex-col gap-2">
              {REASONS.map((r) => (
                <button
                  key={r.value}
                  onClick={() => setReason(r.value)}
                  className={`rounded-card border px-4 py-3 text-left transition-fast ${
                    reason === r.value
                      ? 'border-corail bg-corail/5 text-corail'
                      : 'border-border bg-surface-card text-content-primary hover:bg-border/30'
                  }`}
                >
                  {r.label}
                </button>
              ))}
            </div>

            <textarea
              value={details}
              onChange={(e) => setDetails(e.target.value)}
              placeholder="Préciser — optionnel"
              rows={3}
              className="mt-4 w-full resize-none rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
            />

            {error && <p className="mt-2 text-sm text-corail">{error}</p>}

            <button
              onClick={handleSubmit}
              disabled={!reason || submitting}
              className="mt-4 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
            >
              {submitting ? 'Envoi...' : 'Envoyer'}
            </button>
          </>
        )}
      </div>
    </div>
  );
}

MQEOF_SRC_COMPONENTS_REPORTSHEET_JSX

mkdir -p "src/app/annonces/[id]"
cat > "src/app/annonces/[id]/ContactActions.jsx" << 'MQEOF_SRC_APP_ANNONCES_ID_CONTACTACTIONS_JSX'
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

MQEOF_SRC_APP_ANNONCES_ID_CONTACTACTIONS_JSX

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

mkdir -p "src/lib"
cat > "src/lib/requireAdmin.js" << 'MQEOF_SRC_LIB_REQUIREADMIN_JS'
// Garde d'accès pour toutes les pages /admin/*. À appeler en tout premier
// dans chaque Server Component d'une page admin.
//
// NOTE : ceci est une commodité UX (rediriger proprement plutôt que
// laisser une page vide) — la vraie sécurité vient des policies RLS et des
// vérifications is_super_admin()/is_quartier_admin_of() à l'intérieur des
// fonctions SECURITY DEFINER (hide_post, suspend_member...), jamais de ce
// seul contrôle côté frontend (section 43 du prompt maître).

import { redirect } from 'next/navigation';
import { createClient } from './supabase/server';

export async function requireAdmin() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect('/login');

  const { data: profile } = await supabase
    .from('profiles')
    .select('role, quartier_id')
    .eq('user_id', user.id)
    .single();

  if (!profile || (profile.role !== 'quartier_admin' && profile.role !== 'super_admin')) {
    redirect('/');
  }

  return {
    supabase,
    userId: user.id,
    role: profile.role,
    quartierId: profile.quartier_id,
  };
}

MQEOF_SRC_LIB_REQUIREADMIN_JS

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

mkdir -p "src/app/admin/reports"
cat > "src/app/admin/reports/page.jsx" << 'MQEOF_SRC_APP_ADMIN_REPORTS_PAGE_JSX'
import { requireAdmin } from '@/lib/requireAdmin';
import ReportsList from './ReportsList';

export default async function AdminReportsPage() {
  await requireAdmin();
  return <ReportsList />;
}

MQEOF_SRC_APP_ADMIN_REPORTS_PAGE_JSX

mkdir -p "src/app/admin/reports"
cat > "src/app/admin/reports/ReportsList.jsx" << 'MQEOF_SRC_APP_ADMIN_REPORTS_REPORTSLIST_JSX'
'use client';

import { useEffect, useState, useCallback } from 'react';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';
import { formatRelativeTime } from '@/lib/postTypes';

const REASON_LABELS = {
  inapproprie: 'Contenu inapproprié',
  spam: 'Spam',
  usurpation: 'Usurpation',
  harcelement: 'Harcèlement',
  arnaque: 'Arnaque',
  autre: 'Autre',
};

export default function ReportsList() {
  const [reports, setReports] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('open');

  const load = useCallback(async (status) => {
    setLoading(true);
    const { data } = await supabase
      .from('reports')
      .select('id, target_type, target_id, reason, details, status, created_at')
      .eq('status', status)
      .order('created_at', { ascending: false });
    setReports(data || []);
    setLoading(false);
  }, []);

  useEffect(() => {
    load(filter);
  }, [filter, load]);

  async function handleResolve(reportId, newStatus) {
    const { error } = await supabase.rpc('resolve_report', {
      p_report_id: reportId,
      p_new_status: newStatus,
    });
    if (!error) load(filter);
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <Link href="/admin" className="text-sm text-content-secondary">
        ← Administration
      </Link>
      <h1 className="text-xl font-semibold text-content-primary">Signalements</h1>

      <div className="flex gap-2">
        {['open', 'reviewing', 'closed'].map((s) => (
          <button
            key={s}
            onClick={() => setFilter(s)}
            className={`rounded-pill border px-3 py-1.5 text-sm font-medium transition-fast ${
              filter === s
                ? 'border-corail bg-corail text-white'
                : 'border-border bg-surface text-content-primary'
            }`}
          >
            {s === 'open' ? 'Ouverts' : s === 'reviewing' ? 'En cours' : 'Clos'}
          </button>
        ))}
      </div>

      {loading && <div className="skeleton h-16 w-full" />}

      {!loading && reports.length === 0 && (
        <p className="text-sm text-content-secondary">Aucun signalement dans cette catégorie.</p>
      )}

      <div className="flex flex-col gap-2">
        {reports.map((report) => (
          <div key={report.id} className="rounded-card border border-border bg-surface-card p-4">
            <div className="flex items-center justify-between text-sm text-content-secondary">
              <span>
                {report.target_type} · {REASON_LABELS[report.reason]}
              </span>
              <span>{formatRelativeTime(report.created_at)}</span>
            </div>
            {report.details && (
              <p className="mt-2 text-sm text-content-primary">{report.details}</p>
            )}
            {report.target_type === 'post' && (
              <Link
                href={`/annonces/${report.target_id}`}
                className="mt-2 inline-block text-sm font-medium text-corail"
              >
                Voir l'annonce concernée →
              </Link>
            )}

            {report.status !== 'closed' && (
              <div className="mt-3 flex gap-2">
                {report.status === 'open' && (
                  <button
                    onClick={() => handleResolve(report.id, 'reviewing')}
                    className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-content-primary hover:bg-surface"
                  >
                    Prendre en charge
                  </button>
                )}
                <button
                  onClick={() => handleResolve(report.id, 'closed')}
                  className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-content-primary hover:bg-surface"
                >
                  Clore
                </button>
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

MQEOF_SRC_APP_ADMIN_REPORTS_REPORTSLIST_JSX

mkdir -p "src/app/admin/posts"
cat > "src/app/admin/posts/page.jsx" << 'MQEOF_SRC_APP_ADMIN_POSTS_PAGE_JSX'
import { requireAdmin } from '@/lib/requireAdmin';
import PostsAdminList from './PostsAdminList';

export default async function AdminPostsPage() {
  await requireAdmin();
  return <PostsAdminList />;
}

MQEOF_SRC_APP_ADMIN_POSTS_PAGE_JSX

mkdir -p "src/app/admin/posts"
cat > "src/app/admin/posts/PostsAdminList.jsx" << 'MQEOF_SRC_APP_ADMIN_POSTS_POSTSADMINLIST_JSX'
'use client';

import { useEffect, useState, useCallback } from 'react';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';
import { getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';

// NOTE : pas de filtre explicite par quartier_id ici — la policy RLS
// "posts_select_own_quartier" s'en charge déjà (un quartier_admin ne voit
// que les annonces de son quartier, un super_admin les voit toutes).

export default function PostsAdminList() {
  const [posts, setPosts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('active');

  const load = useCallback(async (status) => {
    setLoading(true);
    const { data } = await supabase
      .from('posts')
      .select('id, type, title, user_id, status, created_at')
      .eq('status', status)
      .order('created_at', { ascending: false })
      .limit(50);
    setPosts(data || []);
    setLoading(false);
  }, []);

  useEffect(() => {
    load(filter);
  }, [filter, load]);

  async function handleHide(postId) {
    const reason = prompt('Motif du masquage (optionnel) :') || null;
    const { error } = await supabase.rpc('hide_post', { p_post_id: postId, p_reason: reason });
    if (!error) load(filter);
  }

  async function handleRestore(postId) {
    const { error } = await supabase.rpc('restore_post', { p_post_id: postId });
    if (!error) load(filter);
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <Link href="/admin" className="text-sm text-content-secondary">
        ← Administration
      </Link>
      <h1 className="text-xl font-semibold text-content-primary">Annonces</h1>

      <div className="flex gap-2">
        {['active', 'hidden'].map((s) => (
          <button
            key={s}
            onClick={() => setFilter(s)}
            className={`rounded-pill border px-3 py-1.5 text-sm font-medium transition-fast ${
              filter === s
                ? 'border-corail bg-corail text-white'
                : 'border-border bg-surface text-content-primary'
            }`}
          >
            {s === 'active' ? 'Actives' : 'Masquées'}
          </button>
        ))}
      </div>

      {loading && <div className="skeleton h-16 w-full" />}

      {!loading && posts.length === 0 && (
        <p className="text-sm text-content-secondary">Aucune annonce dans cette catégorie.</p>
      )}

      <div className="flex flex-col gap-2">
        {posts.map((post) => {
          const typeInfo = getPostTypeInfo(post.type);
          return (
            <div key={post.id} className="rounded-card border border-border bg-surface-card p-4">
              <div className="flex items-center justify-between text-sm text-content-secondary">
                <span>{typeInfo.emoji} {typeInfo.label}</span>
                <span>{formatRelativeTime(post.created_at)}</span>
              </div>
              <Link href={`/annonces/${post.id}`} className="mt-1 block font-medium text-content-primary">
                {post.title}
              </Link>

              <div className="mt-3">
                {post.status === 'active' ? (
                  <button
                    onClick={() => handleHide(post.id)}
                    className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-corail hover:bg-surface"
                  >
                    Masquer
                  </button>
                ) : (
                  <button
                    onClick={() => handleRestore(post.id)}
                    className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-content-primary hover:bg-surface"
                  >
                    Restaurer
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

MQEOF_SRC_APP_ADMIN_POSTS_POSTSADMINLIST_JSX

mkdir -p "src/app/admin/members"
cat > "src/app/admin/members/page.jsx" << 'MQEOF_SRC_APP_ADMIN_MEMBERS_PAGE_JSX'
import { requireAdmin } from '@/lib/requireAdmin';
import MembersAdminList from './MembersAdminList';

export default async function AdminMembersPage() {
  const { quartierId } = await requireAdmin();
  return <MembersAdminList quartierId={quartierId} />;
}

MQEOF_SRC_APP_ADMIN_MEMBERS_PAGE_JSX

mkdir -p "src/app/admin/members"
cat > "src/app/admin/members/MembersAdminList.jsx" << 'MQEOF_SRC_APP_ADMIN_MEMBERS_MEMBERSADMINLIST_JSX'
'use client';

import { useEffect, useState, useCallback } from 'react';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';

export default function MembersAdminList() {
  const [members, setMembers] = useState([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);

    // RLS scope déjà le résultat au bon quartier (ou tout, pour un
    // super_admin) — voir profiles_select policy, migration 001.
    const { data: profiles } = await supabase
      .from('profiles')
      .select('user_id, display_name, role, quartier_id, created_at')
      .order('created_at', { ascending: true });

    const userIds = (profiles || []).map((p) => p.user_id);
    const { data: memberships } = await supabase
      .from('neighborhood_memberships')
      .select('user_id, quartier_id, status')
      .in('user_id', userIds.length > 0 ? userIds : ['00000000-0000-0000-0000-000000000000']);

    const statusByUser = Object.fromEntries((memberships || []).map((m) => [m.user_id, m.status]));

    setMembers(
      (profiles || []).map((p) => ({ ...p, status: statusByUser[p.user_id] || 'approved' }))
    );
    setLoading(false);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function handleSuspend(userId, quartierId) {
    const reason = prompt('Motif de la suspension (optionnel) :') || null;
    const { error } = await supabase.rpc('suspend_member', {
      p_user_id: userId,
      p_quartier_id: quartierId,
      p_reason: reason,
    });
    if (!error) load();
  }

  async function handleUnsuspend(userId, quartierId) {
    const { error } = await supabase.rpc('unsuspend_member', {
      p_user_id: userId,
      p_quartier_id: quartierId,
    });
    if (!error) load();
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <Link href="/admin" className="text-sm text-content-secondary">
        ← Administration
      </Link>
      <h1 className="text-xl font-semibold text-content-primary">Membres</h1>

      {loading && <div className="skeleton h-16 w-full" />}

      <div className="flex flex-col gap-2">
        {members.map((member) => (
          <div
            key={member.user_id}
            className="flex items-center justify-between rounded-card border border-border bg-surface-card p-4"
          >
            <div>
              <p className="font-medium text-content-primary">
                {member.display_name || 'Voisin'}
                {member.role !== 'member' && (
                  <span className="ml-2 rounded-pill bg-corail/10 px-2 py-0.5 text-xs font-medium text-corail">
                    {member.role === 'super_admin' ? 'Super admin' : 'Admin'}
                  </span>
                )}
              </p>
              <p className="text-xs text-content-secondary">
                {member.status === 'suspended' ? 'Suspendu' : 'Actif'}
              </p>
            </div>

            {member.role !== 'super_admin' && (
              <div>
                {member.status === 'suspended' ? (
                  <button
                    onClick={() => handleUnsuspend(member.user_id, member.quartier_id)}
                    className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-content-primary hover:bg-surface"
                  >
                    Réactiver
                  </button>
                ) : (
                  <button
                    onClick={() => handleSuspend(member.user_id, member.quartier_id)}
                    className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-corail hover:bg-surface"
                  >
                    Suspendre
                  </button>
                )}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

MQEOF_SRC_APP_ADMIN_MEMBERS_MEMBERSADMINLIST_JSX

mkdir -p "src/app/profile"
cat > "src/app/profile/page.jsx" << 'MQEOF_SRC_APP_PROFILE_PAGE_JSX'
'use client';

// Placeholder enrichi le temps du chantier auth/communauté — la vraie page
// profil (avatar, bio, badges, stats...) sera construite au chantier dédié.

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';

export default function ProfilePage() {
  const router = useRouter();
  const [inviteLink, setInviteLink] = useState('');
  const [generating, setGenerating] = useState(false);
  const [inviteError, setInviteError] = useState('');
  const [copied, setCopied] = useState(false);
  const [role, setRole] = useState(null);

  useEffect(() => {
    async function loadRole() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;
      const { data: profile } = await supabase
        .from('profiles')
        .select('role')
        .eq('user_id', user.id)
        .single();
      setRole(profile?.role);
    }
    loadRole();
  }, []);

  async function handleLogout() {
    await supabase.auth.signOut();
    router.push('/login');
    router.refresh();
  }

  async function handleGenerateInvite() {
    setGenerating(true);
    setInviteError('');

    const { data: { user } } = await supabase.auth.getUser();
    const { data: profile } = await supabase
      .from('profiles')
      .select('quartier_id')
      .eq('user_id', user.id)
      .single();

    if (!profile?.quartier_id) {
      setInviteError("Termine d'abord ton inscription pour pouvoir inviter quelqu'un.");
      setGenerating(false);
      return;
    }

    const { data: invitation, error } = await supabase
      .from('invitations')
      .insert({
        quartier_id: profile.quartier_id,
        invited_by: user.id,
      })
      .select('id')
      .single();

    setGenerating(false);

    if (error || !invitation) {
      setInviteError("Impossible de créer l'invitation pour le moment. Réessaie plus tard.");
      return;
    }

    setInviteLink(`${window.location.origin}/invite/${invitation.id}`);
  }

  async function handleCopyLink() {
    await navigator.clipboard.writeText(inviteLink);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="rounded-card border border-border bg-surface-card p-6 text-center text-sm text-content-secondary">
        Page « /profile » — à construire dans un prochain chantier.
      </div>

      <div className="rounded-card border border-border bg-surface-card p-4">
        <h2 className="font-semibold text-content-primary">Inviter un voisin</h2>
        <p className="mt-1 text-sm text-content-secondary">
          Le lien rattache automatiquement la personne à ton quartier. Valable 30 jours,
          utilisable une seule fois.
        </p>

        {!inviteLink ? (
          <button
            onClick={handleGenerateInvite}
            disabled={generating}
            className="mt-3 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
          >
            {generating ? 'Génération...' : "Générer un lien d'invitation"}
          </button>
        ) : (
          <div className="mt-3 flex flex-col gap-2">
            <div className="truncate rounded-card border border-border bg-surface px-3 py-2 text-xs text-content-secondary">
              {inviteLink}
            </div>
            <button
              onClick={handleCopyLink}
              className="h-tap w-full rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface"
            >
              {copied ? '✓ Copié !' : 'Copier le lien'}
            </button>
          </div>
        )}

        {inviteError && <p className="mt-2 text-sm text-corail">{inviteError}</p>}
      </div>

      {(role === 'quartier_admin' || role === 'super_admin') && (
        <Link
          href="/admin"
          className="block rounded-card border border-corail bg-corail/5 p-4 text-center font-medium text-corail transition-fast hover:bg-corail/10"
        >
          Administration →
        </Link>
      )}

      <button
        onClick={handleLogout}
        className="h-tap w-full rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface-card"
      >
        Se déconnecter
      </button>
    </div>
  );
}

MQEOF_SRC_APP_PROFILE_PAGE_JSX

echo "Chantier #8 ajoute avec succes."
echo "Prochaine etape : git add -A && git commit -m \"chantier 8 : phase 5 moderation\" && git push"
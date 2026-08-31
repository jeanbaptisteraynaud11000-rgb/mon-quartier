#!/usr/bin/env bash
set -e
echo "Refonte detail annonce + favoris..."

mkdir -p "src/app/annonces/[id]"
cat > "src/app/annonces/[id]/PostHeaderActions.jsx" << 'MQEOF_SRC_APP_ANNONCES_ID_POSTHEADERACTIONS_JSX'
'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { ChevronLeft, Share2, Heart } from 'lucide-react';
import { supabase } from '@/lib/supabaseClient';

export default function PostHeaderActions({ postId, postTitle }) {
  const router = useRouter();
  const [favorited, setFavorited] = useState(false);
  const [userId, setUserId] = useState(null);

  useEffect(() => {
    async function load() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;
      setUserId(user.id);

      const { data } = await supabase
        .from('favorites')
        .select('post_id')
        .eq('user_id', user.id)
        .eq('post_id', postId)
        .maybeSingle();
      setFavorited(!!data);
    }
    load();
  }, [postId]);

  async function handleToggleFavorite() {
    if (!userId) return;
    if (favorited) {
      await supabase.from('favorites').delete().eq('user_id', userId).eq('post_id', postId);
      setFavorited(false);
    } else {
      await supabase.from('favorites').insert({ user_id: userId, post_id: postId });
      setFavorited(true);
    }
  }

  async function handleShare() {
    const url = window.location.href;
    if (navigator.share) {
      try {
        await navigator.share({ title: postTitle, url });
      } catch {
        // Partage annulé — rien à faire.
      }
    } else {
      await navigator.clipboard.writeText(url);
    }
  }

  return (
    <div className="absolute inset-x-0 top-0 flex items-center justify-between p-3">
      <button
        onClick={() => router.back()}
        aria-label="Retour"
        className="flex h-9 w-9 items-center justify-center rounded-pill bg-white/90 text-content-primary shadow-soft"
      >
        <ChevronLeft size={20} />
      </button>
      <div className="flex gap-2">
        <button
          onClick={handleToggleFavorite}
          aria-label={favorited ? 'Retirer des favoris' : 'Ajouter aux favoris'}
          className="flex h-9 w-9 items-center justify-center rounded-pill bg-white/90 shadow-soft"
        >
          <Heart size={18} fill={favorited ? '#FF5A5F' : 'none'} className={favorited ? 'text-corail' : 'text-content-primary'} />
        </button>
        <button
          onClick={handleShare}
          aria-label="Partager"
          className="flex h-9 w-9 items-center justify-center rounded-pill bg-white/90 text-content-primary shadow-soft"
        >
          <Share2 size={17} />
        </button>
      </div>
    </div>
  );
}

MQEOF_SRC_APP_ANNONCES_ID_POSTHEADERACTIONS_JSX

mkdir -p "src/app/annonces/[id]"
cat > "src/app/annonces/[id]/ContactActions.jsx" << 'MQEOF_SRC_APP_ANNONCES_ID_CONTACTACTIONS_JSX'
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

MQEOF_SRC_APP_ANNONCES_ID_CONTACTACTIONS_JSX

mkdir -p "src/app/annonces/[id]"
cat > "src/app/annonces/[id]/page.jsx" << 'MQEOF_SRC_APP_ANNONCES_ID_PAGE_JSX'
// Server Component : détail d'une annonce. La policy RLS
// "posts_select_own_quartier" garantit déjà qu'on ne peut pas voir
// l'annonce d'un autre quartier.
//
// NOTE DE PORTÉE : plusieurs éléments d'inspiration (notes/avis, "% de
// prêts honorés", historique d'emprunts, réservation avec calendrier) ne
// sont pas construits — ce sont de vraies fonctionnalités à part entière,
// pas juste de la mise en page. Ce qui est affiché ici reflète toujours de
// vraies données.

import Link from 'next/link';
import Image from 'next/image';
import { notFound } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';
import { getPlaceholderImage } from '@/lib/placeholderImages';
import { getLevel } from '@/lib/levels';
import PostHeaderActions from './PostHeaderActions';
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

  const { data: authorProfile } = await supabase
    .from('profiles')
    .select('display_name, points, photo_url, photo_visible')
    .eq('user_id', post.user_id)
    .single();

  const { data: images } = await supabase
    .from('post_images')
    .select('storage_path, position')
    .eq('post_id', post.id)
    .order('position', { ascending: true });

  const photoUrls = (images || []).map(
    (img) => supabase.storage.from('posts').getPublicUrl(img.storage_path).data.publicUrl
  );
  const heroImage = photoUrls[0] || getPlaceholderImage(post.type);

  const typeInfo = getPostTypeInfo(post.type);
  const isOwnPost = post.user_id === user.id;
  const authorName = authorProfile?.display_name || 'Voisin';
  const authorInitial = authorName.charAt(0).toUpperCase();
  const level = getLevel(authorProfile?.points || 0);

  const { data: otherPosts } = await supabase
    .from('posts')
    .select('id, title, type')
    .eq('user_id', post.user_id)
    .eq('status', 'active')
    .neq('id', post.id)
    .limit(3);

  return (
    <div className="flex flex-col gap-5 pb-4">
      {/* Photo pleine largeur avec retour/favori/partage en overlay */}
      <div className="relative h-72 w-full">
        <Image src={heroImage} alt="" fill sizes="100vw" className="object-cover" priority />
        <PostHeaderActions postId={post.id} postTitle={post.title} />
      </div>

      <div className="flex flex-col gap-5 px-4">
        <div>
          <span className="inline-block rounded-pill bg-surface-card px-3 py-1 text-xs font-semibold uppercase tracking-wide text-content-secondary">
            {typeInfo.label}
          </span>
          <h1 className="mt-2 text-xl font-semibold text-content-primary">{post.title}</h1>
          {post.description && (
            <p className="mt-1 text-sm text-content-secondary">{post.description}</p>
          )}
        </div>

        {/* Auteur + niveau (factuel, pas de note/avis — pas de systeme de notation) */}
        <Link
          href={isOwnPost ? '/profile' : '#'}
          className="flex items-center gap-3 rounded-card border border-border bg-surface-card p-3"
        >
          <div className="flex h-11 w-11 flex-shrink-0 items-center justify-center overflow-hidden rounded-pill bg-corail/10 font-semibold text-corail">
            {authorProfile?.photo_visible && authorProfile?.photo_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={authorProfile.photo_url} alt="" className="h-full w-full object-cover" />
            ) : (
              authorInitial
            )}
          </div>
          <div className="min-w-0 flex-1">
            <p className="font-medium text-content-primary">{authorName}</p>
            <p className="text-xs text-content-secondary">{level.label}</p>
          </div>
        </Link>

        {/* Infos structurées — uniquement des champs réels */}
        {(post.availability || post.approx_zone) && (
          <div className="grid grid-cols-2 gap-3 rounded-card border border-border bg-surface-card p-4">
            {post.availability && (
              <div>
                <p className="text-xs text-content-secondary">Disponibilité</p>
                <p className="mt-0.5 text-sm font-medium text-content-primary">{post.availability}</p>
              </div>
            )}
            {post.approx_zone && (
              <div>
                <p className="text-xs text-content-secondary">Zone</p>
                <p className="mt-0.5 text-sm font-medium text-content-primary">{post.approx_zone}</p>
              </div>
            )}
            <div>
              <p className="text-xs text-content-secondary">Publié</p>
              <p className="mt-0.5 text-sm font-medium text-content-primary">
                {formatRelativeTime(post.created_at)}
              </p>
            </div>
          </div>
        )}

        {!isOwnPost && <ContactActions postId={post.id} postAuthorId={post.user_id} />}

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
              {otherPosts.map((op) => {
                const OpIcon = getPostTypeInfo(op.type).icon;
                return (
                  <Link
                    key={op.id}
                    href={`/annonces/${op.id}`}
                    className="flex items-center gap-2 rounded-card border border-border bg-surface-card p-3 text-sm text-content-primary transition-fast hover:bg-border/30"
                  >
                    <OpIcon size={16} /> {op.title}
                  </Link>
                );
              })}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

MQEOF_SRC_APP_ANNONCES_ID_PAGE_JSX

mkdir -p "src/app/favoris"
cat > "src/app/favoris/page.jsx" << 'MQEOF_SRC_APP_FAVORIS_PAGE_JSX'
// Server Component : mes annonces favorites.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';
import { getPlaceholderImage } from '@/lib/placeholderImages';

export default async function FavorisPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: favorites } = await supabase
    .from('favorites')
    .select('post_id, created_at')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false });

  const postIds = (favorites || []).map((f) => f.post_id);

  let posts = [];
  let thumbnailByPost = {};
  if (postIds.length > 0) {
    const { data } = await supabase
      .from('posts')
      .select('id, type, title, created_at, status')
      .in('id', postIds)
      .eq('status', 'active');
    posts = data || [];

    const { data: images } = await supabase
      .from('post_images')
      .select('post_id, storage_path, position')
      .in('post_id', postIds)
      .order('position', { ascending: true });

    for (const img of images || []) {
      if (!thumbnailByPost[img.post_id]) {
        thumbnailByPost[img.post_id] = supabase.storage.from('posts').getPublicUrl(img.storage_path).data.publicUrl;
      }
    }
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <h1 className="text-xl font-semibold text-content-primary">Mes favoris</h1>

      {posts.length === 0 && (
        <div className="rounded-card border border-border bg-surface-card p-6 text-center text-sm text-content-secondary">
          Aucune annonce en favori pour l'instant. Touche le cœur sur une annonce pour la
          retrouver ici.
        </div>
      )}

      <div className="flex flex-col gap-2">
        {posts.map((post) => {
          const thumbnail = thumbnailByPost[post.id] || getPlaceholderImage(post.type);
          return (
            <Link
              key={post.id}
              href={`/annonces/${post.id}`}
              className="flex items-center gap-3 rounded-card border border-border bg-surface-card p-3 transition-fast hover:bg-border/20"
            >
              <div className="h-12 w-12 flex-shrink-0 overflow-hidden rounded-card">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={thumbnail} alt="" className="h-full w-full object-cover" />
              </div>
              <div className="min-w-0 flex-1">
                <p className="truncate font-medium text-content-primary">{post.title}</p>
                <p className="text-xs text-content-secondary">{formatRelativeTime(post.created_at)}</p>
              </div>
            </Link>
          );
        })}
      </div>
    </div>
  );
}

MQEOF_SRC_APP_FAVORIS_PAGE_JSX

mkdir -p "src/app/profile"
cat > "src/app/profile/page.jsx" << 'MQEOF_SRC_APP_PROFILE_PAGE_JSX'
'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { getLevel } from '@/lib/levels';
import { Settings, Pencil } from 'lucide-react';

function memberSince(dateString) {
  if (!dateString) return '';
  const date = new Date(dateString);
  const diffMonths = (Date.now() - date.getTime()) / (1000 * 60 * 60 * 24 * 30.44);
  if (diffMonths < 1) return "arrivé(e) ce mois-ci";
  if (diffMonths < 12) return `membre depuis ${Math.max(1, Math.floor(diffMonths))} mois`;
  const years = Math.floor(diffMonths / 12);
  return `membre depuis ${years} an${years > 1 ? 's' : ''}`;
}

export default function ProfilePage() {
  const router = useRouter();
  const [inviteLink, setInviteLink] = useState('');
  const [generating, setGenerating] = useState(false);
  const [inviteError, setInviteError] = useState('');
  const [copied, setCopied] = useState(false);

  const [loading, setLoading] = useState(true);
  const [role, setRole] = useState(null);
  const [profile, setProfile] = useState(null);
  const [stats, setStats] = useState({ posts: 0, eventsOrganized: 0, eventsJoined: 0 });

  useEffect(() => {
    async function loadProfile() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data: p } = await supabase
        .from('profiles')
        .select('display_name, photo_url, bio, role, points, quartier_id, created_at')
        .eq('user_id', user.id)
        .single();

      setProfile(p);
      setRole(p?.role);

      const [{ count: posts }, { count: eventsOrganized }, { count: eventsJoined }] = await Promise.all([
        supabase.from('posts').select('*', { count: 'exact', head: true }).eq('user_id', user.id).eq('status', 'active'),
        supabase.from('events').select('*', { count: 'exact', head: true }).eq('user_id', user.id).eq('status', 'active'),
        supabase.from('event_attendees').select('*', { count: 'exact', head: true }).eq('user_id', user.id),
      ]);

      setStats({ posts: posts || 0, eventsOrganized: eventsOrganized || 0, eventsJoined: eventsJoined || 0 });
      setLoading(false);
    }
    loadProfile();
  }, []);

  async function handleLogout() {
    await supabase.auth.signOut();
    router.push('/login');
    router.refresh();
  }

  async function handleDeleteAccount() {
    if (
      !confirm(
        'Supprimer ton compte ? Ton profil sera anonymisé et tu seras déconnecté. Cette action est irréversible.'
      )
    ) {
      return;
    }
    const { error } = await supabase.rpc('request_account_deletion');
    if (!error) {
      await supabase.auth.signOut();
      router.push('/login');
    }
  }

  async function handleGenerateInvite() {
    setGenerating(true);
    setInviteError('');

    const { data: { user } } = await supabase.auth.getUser();

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

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="skeleton h-4 w-40" />
      </div>
    );
  }

  const initial = (profile?.display_name || '?').charAt(0).toUpperCase();
  const points = profile?.points || 0;

  return (
    <div className="flex flex-col gap-4 p-4">
      {/* En-tête profil */}
      <div className="flex items-center gap-4 rounded-card border border-border bg-surface-card p-4 shadow-soft">
        {profile?.photo_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={profile.photo_url} alt="" className="h-16 w-16 flex-shrink-0 rounded-pill object-cover" />
        ) : (
          <div className="flex h-16 w-16 flex-shrink-0 items-center justify-center rounded-pill bg-corail/10 text-xl font-semibold text-corail">
            {initial}
          </div>
        )}
        <div className="min-w-0 flex-1">
          <p className="truncate text-lg font-semibold text-content-primary">
            {profile?.display_name || 'Voisin'}
          </p>
          <p className="text-xs text-content-secondary">{memberSince(profile?.created_at)}</p>
          <p className="mt-1 text-xs font-medium text-corail">{getLevel(points).label}</p>
        </div>
        <Link
          href="/profile/edit"
          aria-label="Modifier mon profil"
          className="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-pill border border-border text-content-secondary hover:bg-surface"
        >
          <Pencil size={15} />
        </Link>
      </div>

      {profile?.bio && (
        <p className="rounded-card border border-border bg-surface-card p-4 text-sm text-content-primary">
          {profile.bio}
        </p>
      )}

      {/* Statistiques factuelles — jamais de score opaque (section 73) */}
      <div className="grid grid-cols-3 gap-2">
        <StatBlock value={stats.posts} label="annonces" href="/mes-annonces" />
        <StatBlock value={stats.eventsOrganized} label="activités créées" href="/activites" />
        <StatBlock value={stats.eventsJoined} label="participations" href="/activites" />
      </div>

      <div className="grid grid-cols-3 gap-2">
        <Link
          href="/mes-annonces"
          className="rounded-card border border-border bg-surface-card p-3 text-center text-sm font-medium text-content-primary shadow-soft hover:bg-border/20"
        >
          Mes annonces
        </Link>
        <Link
          href="/favoris"
          className="rounded-card border border-border bg-surface-card p-3 text-center text-sm font-medium text-content-primary shadow-soft hover:bg-border/20"
        >
          Mes favoris
        </Link>
        <Link
          href="/settings"
          className="flex items-center justify-center gap-1.5 rounded-card border border-border bg-surface-card p-3 text-center text-sm font-medium text-content-primary shadow-soft hover:bg-border/20"
        >
          <Settings size={15} /> Paramètres
        </Link>
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

      {role === 'super_admin' && (
        <Link
          href="/admin"
          className="block rounded-card border border-corail bg-corail/5 p-4 text-center font-medium text-corail transition-fast hover:bg-corail/10"
        >
          Administration →
        </Link>
      )}

      <div className="flex flex-col gap-1 rounded-card border border-border bg-surface-card p-2">
        <Link href="/commerces" className="rounded-card px-3 py-2 text-sm text-content-primary hover:bg-surface">
          Commerces & lieux du quartier
        </Link>
        <Link href="/voisins" className="rounded-card px-3 py-2 text-sm text-content-primary hover:bg-surface">
          Mes voisins
        </Link>
        <Link href="/help" className="rounded-card px-3 py-2 text-sm text-content-primary hover:bg-surface">
          Aide
        </Link>
        <Link href="/support" className="rounded-card px-3 py-2 text-sm text-content-primary hover:bg-surface">
          Contacter le support
        </Link>
        <Link href="/confidentialite" className="rounded-card px-3 py-2 text-sm text-content-primary hover:bg-surface">
          Confidentialité
        </Link>
        <Link href="/cgu" className="rounded-card px-3 py-2 text-sm text-content-primary hover:bg-surface">
          Conditions d'utilisation
        </Link>
      </div>

      <button
        onClick={handleLogout}
        className="h-tap w-full rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface-card"
      >
        Se déconnecter
      </button>

      <button
        onClick={handleDeleteAccount}
        className="h-tap w-full rounded-pill border border-corail font-medium text-corail transition-fast hover:bg-corail/5"
      >
        Supprimer mon compte
      </button>
    </div>
  );
}

function StatBlock({ value, label, href }) {
  return (
    <Link
      href={href}
      className="flex flex-col items-center gap-0.5 rounded-card border border-border bg-surface-card p-3 text-center shadow-soft hover:bg-border/20"
    >
      <span className="text-lg font-semibold text-content-primary">{value}</span>
      <span className="text-[11px] text-content-secondary">{label}</span>
    </Link>
  );
}

MQEOF_SRC_APP_PROFILE_PAGE_JSX

echo "Detail annonce + favoris ajoutes avec succes."
echo "Prochaine etape : executer la migration 023, puis git add -A && git commit -m \"detail annonce selon reference + favoris\" && git push"
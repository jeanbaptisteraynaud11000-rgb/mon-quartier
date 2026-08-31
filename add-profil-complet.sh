#!/usr/bin/env bash
set -e
echo "Ajout profil complet + avatars + confidentialite..."

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

      <div className="grid grid-cols-2 gap-2">
        <Link
          href="/mes-annonces"
          className="rounded-card border border-border bg-surface-card p-3 text-center text-sm font-medium text-content-primary shadow-soft hover:bg-border/20"
        >
          Mes annonces
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

mkdir -p "src/app/profile/edit"
cat > "src/app/profile/edit/page.jsx" << 'MQEOF_SRC_APP_PROFILE_EDIT_PAGE_JSX'
'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';

const MAX_AVATAR_SIZE = 2 * 1024 * 1024;
const PRESET_AVATARS = [
  '/avatars/preset-1.png',
  '/avatars/preset-2.png',
  '/avatars/preset-3.png',
  '/avatars/preset-4.png',
  '/avatars/preset-5.png',
  '/avatars/preset-6.png',
];

export default function EditProfilePage() {
  const router = useRouter();
  const [userId, setUserId] = useState(null);
  const [loading, setLoading] = useState(true);

  const [displayName, setDisplayName] = useState('');
  const [bio, setBio] = useState('');
  const [phone, setPhone] = useState('');
  const [photoUrl, setPhotoUrl] = useState(null);
  const [photoVisible, setPhotoVisible] = useState(true);
  const [phoneVisible, setPhoneVisible] = useState(false);

  const [avatarFile, setAvatarFile] = useState(null);
  const [avatarPreview, setAvatarPreview] = useState(null);
  const [showPresets, setShowPresets] = useState(false);
  const [photoError, setPhotoError] = useState('');

  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  useEffect(() => {
    async function load() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        router.push('/login');
        return;
      }
      setUserId(user.id);

      const { data: profile } = await supabase
        .from('profiles')
        .select('display_name, bio, phone, photo_url, photo_visible, phone_visible')
        .eq('user_id', user.id)
        .single();

      setDisplayName(profile?.display_name || '');
      setBio(profile?.bio || '');
      setPhone(profile?.phone || '');
      setPhotoUrl(profile?.photo_url || null);
      setPhotoVisible(profile?.photo_visible ?? true);
      setPhoneVisible(profile?.phone_visible ?? false);
      setLoading(false);
    }
    load();
  }, [router]);

  function handleAvatarSelect(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setPhotoError('');

    const accepted = ['image/jpeg', 'image/png', 'image/webp'];
    if (!accepted.includes(file.type)) {
      setPhotoError('Format accepté : JPEG, PNG ou WebP.');
      return;
    }
    if (file.size > MAX_AVATAR_SIZE) {
      setPhotoError('La photo doit faire moins de 2 Mo.');
      return;
    }

    setAvatarFile(file);
    setAvatarPreview(URL.createObjectURL(file));
    setShowPresets(false);
  }

  function handleChoosePreset(presetPath) {
    setAvatarFile(null);
    setAvatarPreview(null);
    setPhotoUrl(presetPath);
    setShowPresets(false);
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setSuccess(false);

    if (!displayName.trim()) {
      setError('Le prénom est obligatoire.');
      return;
    }

    setSubmitting(true);

    let newPhotoUrl = photoUrl;

    if (avatarFile) {
      const ext = avatarFile.name.split('.').pop();
      const path = `${userId}/${crypto.randomUUID()}.${ext}`;
      const { error: uploadError } = await supabase.storage.from('avatars').upload(path, avatarFile);

      if (uploadError) {
        setSubmitting(false);
        setError("Impossible d'envoyer la photo. Réessaie.");
        return;
      }

      newPhotoUrl = supabase.storage.from('avatars').getPublicUrl(path).data.publicUrl;
    }

    const { error: updateError } = await supabase
      .from('profiles')
      .update({
        display_name: displayName.trim(),
        bio: bio.trim() || null,
        phone: phone.trim() || null,
        photo_url: newPhotoUrl,
        photo_visible: photoVisible,
        phone_visible: phoneVisible,
      })
      .eq('user_id', userId);

    setSubmitting(false);

    if (updateError) {
      setError('Une erreur est survenue. Réessaie.');
      return;
    }

    setSuccess(true);
    setTimeout(() => router.push('/profile'), 1000);
  }

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="skeleton h-4 w-40" />
      </div>
    );
  }

  const initial = (displayName || '?').charAt(0).toUpperCase();
  const currentAvatar = avatarPreview || photoUrl;

  return (
    <div className="p-6">
      <h1 className="mb-6 text-xl font-semibold text-content-primary">Modifier mon profil</h1>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <div className="flex flex-col items-center gap-2">
          {currentAvatar ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={currentAvatar} alt="" className="h-24 w-24 rounded-pill object-cover" />
          ) : (
            <div className="flex h-24 w-24 items-center justify-center rounded-pill bg-corail/10 text-2xl font-semibold text-corail">
              {initial}
            </div>
          )}

          <div className="flex gap-3">
            <label className="cursor-pointer text-xs font-medium text-corail">
              Importer une photo
              <input
                type="file"
                accept="image/jpeg,image/png,image/webp"
                onChange={handleAvatarSelect}
                className="hidden"
              />
            </label>
            <span className="text-xs text-content-secondary">·</span>
            <button
              type="button"
              onClick={() => setShowPresets((v) => !v)}
              className="text-xs font-medium text-corail"
            >
              Choisir un avatar
            </button>
          </div>
          {photoError && <p className="text-xs text-corail">{photoError}</p>}

          {showPresets && (
            <div className="mt-2 grid grid-cols-6 gap-2">
              {PRESET_AVATARS.map((preset) => (
                <button
                  key={preset}
                  type="button"
                  onClick={() => handleChoosePreset(preset)}
                  className="overflow-hidden rounded-pill transition-fast hover:scale-105"
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={preset} alt="" className="h-10 w-10" />
                </button>
              ))}
            </div>
          )}

          <p className="mt-1 text-center text-xs text-content-secondary">
            Pas envie de mettre ta tête ? Choisis un avatar illustré à la place.
          </p>
        </div>

        <div>
          <label htmlFor="displayName" className="mb-1 block text-sm font-medium text-content-primary">
            Prénom affiché
          </label>
          <input
            id="displayName"
            type="text"
            required
            maxLength={50}
            value={displayName}
            onChange={(e) => setDisplayName(e.target.value)}
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        <div>
          <label htmlFor="bio" className="mb-1 block text-sm font-medium text-content-primary">
            Bio <span className="text-content-secondary">(optionnel)</span>
          </label>
          <textarea
            id="bio"
            rows={3}
            maxLength={300}
            value={bio}
            onChange={(e) => setBio(e.target.value)}
            placeholder="Quelques mots sur toi..."
            className="w-full resize-none rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        <div>
          <label htmlFor="phone" className="mb-1 block text-sm font-medium text-content-primary">
            Téléphone <span className="text-content-secondary">(optionnel)</span>
          </label>
          <input
            id="phone"
            type="tel"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
        </div>

        {/* Préférences de confidentialité — section 32 du prompt maître */}
        <div className="rounded-card border border-border bg-surface-card p-4">
          <h2 className="mb-3 text-sm font-semibold text-content-primary">Confidentialité</h2>

          <label className="flex items-center justify-between py-2">
            <div>
              <p className="text-sm text-content-primary">Photo visible par mes voisins</p>
              <p className="text-xs text-content-secondary">
                Sinon, une icône générique s'affiche à ta place.
              </p>
            </div>
            <input
              type="checkbox"
              checked={photoVisible}
              onChange={(e) => setPhotoVisible(e.target.checked)}
              className="h-5 w-5 accent-corail"
            />
          </label>

          <label className="flex items-center justify-between border-t border-border py-2 pt-3">
            <div>
              <p className="text-sm text-content-primary">Téléphone visible par mes voisins</p>
              <p className="text-xs text-content-secondary">
                Désactivé par défaut. Aucune fonctionnalité actuelle ne l'affiche encore
                publiquement, ce réglage prépare une future mise en relation directe.
              </p>
            </div>
            <input
              type="checkbox"
              checked={phoneVisible}
              onChange={(e) => setPhoneVisible(e.target.checked)}
              className="h-5 w-5 flex-shrink-0 accent-corail"
            />
          </label>
        </div>

        {error && <p className="text-sm text-corail">{error}</p>}
        {success && <p className="text-sm text-vert">✓ Profil mis à jour</p>}

        <button
          type="submit"
          disabled={submitting}
          className="mt-2 h-tap w-full rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
        >
          {submitting ? 'Enregistrement...' : 'Enregistrer'}
        </button>
      </form>
    </div>
  );
}

MQEOF_SRC_APP_PROFILE_EDIT_PAGE_JSX

mkdir -p "src/app/voisins"
cat > "src/app/voisins/page.jsx" << 'MQEOF_SRC_APP_VOISINS_PAGE_JSX'
// Server Component : annuaire des voisins du quartier.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';

function memberSince(dateString) {
  const date = new Date(dateString);
  const diffMonths =
    (Date.now() - date.getTime()) / (1000 * 60 * 60 * 24 * 30.44);

  if (diffMonths < 1) return "arrivé(e) ce mois-ci";
  if (diffMonths < 2) return 'membre depuis 1 mois';
  if (diffMonths < 12) return `membre depuis ${Math.floor(diffMonths)} mois`;
  const years = Math.floor(diffMonths / 12);
  return `membre depuis ${years} an${years > 1 ? 's' : ''}`;
}

export default async function VoisinsPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: myProfile } = await supabase
    .from('profiles')
    .select('quartier_id, quartiers(name, city)')
    .eq('user_id', user.id)
    .single();

  if (!myProfile?.quartier_id) {
    return (
      <div className="p-4">
        <div className="rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">
            Termine d'abord ton inscription pour voir tes voisins.
          </p>
          <Link
            href="/onboarding"
            className="mt-4 inline-block h-tap rounded-pill bg-corail px-6 py-3 font-medium text-white transition-fast hover:bg-corail-hover"
          >
            Terminer mon inscription
          </Link>
        </div>
      </div>
    );
  }

  // On respecte map_visibility = 'off' comme un choix général de discrétion :
  // quelqu'un qui a explicitement demandé à ne pas apparaître ne doit pas se
  // retrouver listé ici non plus. Limite à 50 : mesure simple anti-scraping
  // (section 83) en attendant une vraie pagination si le quartier grossit.
  const { data: neighbors, error } = await supabase
    .from('profiles')
    .select('user_id, display_name, created_at, map_visibility, photo_url, photo_visible')
    .eq('quartier_id', myProfile.quartier_id)
    .neq('map_visibility', 'off')
    .order('created_at', { ascending: true })
    .limit(50);

  return (
    <div className="flex flex-col gap-4 p-4">
      <div>
        <h1 className="text-xl font-semibold text-content-primary">Mes voisins</h1>
        <p className="text-sm text-content-secondary">
          {myProfile.quartiers?.name} — {myProfile.quartiers?.city}
        </p>
      </div>

      {error && (
        <p className="text-sm text-corail">Impossible de charger la liste pour le moment.</p>
      )}

      {!error && neighbors?.length === 0 && (
        <div className="rounded-card border border-border bg-surface-card p-6 text-center text-sm text-content-secondary">
          Aucun voisin visible pour l'instant.
        </div>
      )}

      <div className="flex flex-col gap-2">
        {neighbors?.map((neighbor) => {
          const isMe = neighbor.user_id === user.id;
          const initial = (neighbor.display_name || '?').charAt(0).toUpperCase();
          return (
            <div
              key={neighbor.user_id}
              className="flex items-center gap-3 rounded-card border border-border bg-surface-card p-3"
            >
              <div className="flex h-10 w-10 flex-shrink-0 items-center justify-center overflow-hidden rounded-pill bg-corail/10 font-semibold text-corail">
                {neighbor.photo_visible && neighbor.photo_url ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={neighbor.photo_url} alt="" className="h-full w-full object-cover" />
                ) : (
                  initial
                )}
              </div>
              <div className="min-w-0 flex-1">
                <p className="truncate font-medium text-content-primary">
                  {neighbor.display_name || 'Voisin'} {isMe && '(toi)'}
                </p>
                <p className="text-xs text-content-secondary">
                  {memberSince(neighbor.created_at)}
                </p>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

MQEOF_SRC_APP_VOISINS_PAGE_JSX

mkdir -p "src/app/annonces/[id]"
cat > "src/app/annonces/[id]/page.jsx" << 'MQEOF_SRC_APP_ANNONCES_ID_PAGE_JSX'
// Server Component : détail d'une annonce. La policy RLS "posts_select_own_quartier"
// garantit déjà qu'on ne peut pas voir l'annonce d'un autre quartier — si
// jamais quelqu'un force une URL /annonces/[id] hors de son quartier, la
// requête retourne simplement "non trouvé", jamais les données.

import Link from 'next/link';
import Image from 'next/image';
import { notFound } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { getPostTypeInfo, formatRelativeTime } from '@/lib/postTypes';
import { getLevel } from '@/lib/levels';
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

  const typeInfo = getPostTypeInfo(post.type);
  const TypeIcon = typeInfo.icon;
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

      {photoUrls.length > 0 && (
        <div className="-mx-4 flex gap-2 overflow-x-auto px-4">
          {photoUrls.map((url, i) => (
            <div key={i} className="relative h-56 w-full flex-shrink-0 overflow-hidden rounded-card bg-surface-card">
              <Image src={url} alt="" fill sizes="100vw" className="object-cover" />
            </div>
          ))}
        </div>
      )}

      <div className="rounded-card border border-border bg-surface-card p-5">
        <div className="flex items-center gap-2">
          <span className="flex h-8 w-8 items-center justify-center rounded-pill bg-surface text-content-primary">
            <TypeIcon size={16} />
          </span>
          <span className="text-sm font-medium text-content-secondary">{typeInfo.label}</span>
        </div>

        <h1 className="mt-3 text-xl font-semibold text-content-primary">{post.title}</h1>

        <div className="mt-2 flex items-center gap-2 text-sm text-content-secondary">
          <div className="flex h-6 w-6 flex-shrink-0 items-center justify-center overflow-hidden rounded-pill bg-corail/10 text-[10px] font-semibold text-corail">
            {authorProfile?.photo_visible && authorProfile?.photo_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={authorProfile.photo_url} alt="" className="h-full w-full object-cover" />
            ) : (
              authorName.charAt(0).toUpperCase()
            )}
          </div>
          <span>{authorName}</span>
          <span className="rounded-pill bg-surface px-2 py-0.5 text-xs font-medium text-content-secondary">
            {getLevel(authorProfile?.points || 0).label}
          </span>
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
  );
}

MQEOF_SRC_APP_ANNONCES_ID_PAGE_JSX

mkdir -p "public/avatars"
base64 -d > "public/avatars/preset-1.png" << 'MQB64EOF_PUBLIC_AVATARS_PRESET-1_PNG'
iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAIAAADTED8xAAAFAUlEQVR4nO3ZQXbTWBBA0U+fXiUMYGlMWCc9aOgOx3Fi2Y5l1bt3zECqX0+Sw6efn78uqPpr7wuAPQmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGl/730BJT++b/jHX7590FXw0qefn7/ufQ1DbVr3S0jiAwjgru6+9OeI4U4EcA8P2/tTSriNAG6w496fUsJVBHCVp1r9l2SwkQC2eNq9P6WEywjgMgda/Zdk8B7/EXaBg27/OvKVP4o3wJvGLJBXwRkCOGPM6r8kgxM+gV4zcvvX3Pu6gQBOzN6S2Xe3nU+gF1LL4XNoreUN8L/U9q/e/Z4hgLVWdRuad/0nAbT3oHzvay0B2ID4BMI/gtsH/4rkz+LqG8D2n0rOpBoArLWiASQfdRfpTaYXQO+Mt4nNJxZA7HSvVJpSKYDSud4qM6tMAJkTvZvGxDIBwGsaATQeZvcXmFsggMApfqDp05sewPTze4TRM5weALxpdACjH10PNXeSowOA98wNYO5Dax9D5zk0gKGntbOJUx0aAFxmYgATH1TPYtxsJwYAFxMAaeMCGPeOfjqzJjwuANhiVgCzHk7Pa9CcZwUAGwmAtEEBDHovH8CUaQ8KALYTAGlTApjyRj6SETOfEgBcRQCkCYC0EQGM+Bg9pONPfkQAcC0BkCYA0gRAmgBIO34Ax/9DxLEdfP7HDwBuIADSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIO34AXz5tvcVtB18/scPAG4gANIEQJoASBMAaSMCOPgfIg7s+JMfEQBcSwCkCYC0KQEc/2P0eEbMfEoAcBUBkDYogBFv5MOYMu1BAcB2AiBtVgBT3svPbtCcZwUAG40LYNDD6UnNmvC4AGALAZA2MYBZ7+jnMm62EwOAiw0NYNyD6ilMnOrQANbM09rT0HnODQAuMDqAoQ+tHcyd5OgA4D3TA5j76Hqc0TOcHsAafn4fbvr0AgGs+af4UQJzawQAZ2QCCDzM7qwxsUwAq3Ki95GZVSmAFTrXm5SmFAtgtU73GrH59AJYuTPeoDeZZADwWzWA3qPufcmZfPr5+eve17CrH9/3voInkFz9f1XfAP8Jn/0v7QnkA1jtDSjf+1pLAL8096B5138SwG+1bajd7xn5H8Gnxv8stvoveAOcmL0fs+9uOwG8ZuqWTL2vG/gEetOYzyGrf4YALnDoDKz+m3wCXeC4O3TcK38Ub4AtDvQqsPqXEcBVnrYEe7+RAG7wVBlY/asI4B52LMHe30YAd/WwEuz9nQjgw9w9Bkv/AQTwQJuSsO4PIQDS/EcYaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANL+ARzjwStbqzj3AAAAAElFTkSuQmCC
MQB64EOF_PUBLIC_AVATARS_PRESET-1_PNG

mkdir -p "public/avatars"
base64 -d > "public/avatars/preset-2.png" << 'MQB64EOF_PUBLIC_AVATARS_PRESET-2_PNG'
iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAIAAADTED8xAAAEjklEQVR4nO3V23ElRRAAUS2BkziAT2AAmAkfIhaQVtJ9zKOn8hwLemo6q7+9/PHbC1T9dPYB4EwCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAE721y+/nn2ENAGc6fX2a+BEAiBNAKf57+L3CJxFAKQJ4BzvV75H4BQCOMFHd10DxxMAaQI42udr3iNwMAGQJoBD3bLgPQJHEsBxbr/ZGjiMAEgTwEHuXeoegWMIgDQBHOGxde4ROIAASBPA7p5Z5B6BvQlgX8/fYA3sSgCkCWBHWy1vj8B+BECaAPay7dr2COxEALvY475qYA8CIE0A29tvVXsENicA0gSwsb2XtEdgWwLY0jG3UwMbEgBpAtjMkYvZI7AVAZAmgG0cv5I9ApsQwAbOuosaeJ4ASBPAs85dwx6BJwmANAE8ZYUFvMIZrksAj1vn5q1zkssRAGkCeNBqS3e181yFAEgTwCPWXLdrnmpxAiBNAHdbedGufLY1CeA+69+w9U+4FAGQJoA7XGW5XuWcKxAAaQK41bXW6rVOeyIB3OSK9+mKZz6eAEgTwNeuu0qve/LDCIA0AXzh6kv06uffmwA+M+P2zPiKnQiANAF8aNLinPQt2xIAaQL4sXkrc94XbUIAPzD1rkz9rmcIgDQBvDV7Tc7+ugcIgDQB/E9hQRa+8XYC+FfnZnS+9EsCIE0A/6gtxdr3fkQApAng5aW6Dptf/YYASBNAehGWv/1VPQA3ID6BegDEpQOIL7/vynNIBwDdAMpr773sNKIBZP/3J5oziQYAr4oBNFfdLYKTKQYA3+UCCC65u9Tm0wqg9ncfk5pSKwB4IxRAarE9qTOrUADwXiWAzkrbSmRiiQAi/3JzhbklAoCPzA+gsMb2M3568wOATwwPYPwCO8DsGU4OYPafO9LgSU4OAL40NoDBS+sUU+c5NgC4xcwApq6rc42c6swA4EYDAxi5qBYxb7bTApj3h1YzbMLTAoC7jApg2HJa1qQ5jwoA7jUngElraX1jpj0kgDH/40JmzHxIAPCYCQHMWEVXNGDyEwKAh10+gAFL6NKuPv+fzz7As779+fvZR+DCLv8CwDMEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQNrfDf3lQQiDptsAAAAASUVORK5CYII=
MQB64EOF_PUBLIC_AVATARS_PRESET-2_PNG

mkdir -p "public/avatars"
base64 -d > "public/avatars/preset-3.png" << 'MQB64EOF_PUBLIC_AVATARS_PRESET-3_PNG'
iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAIAAADTED8xAAADfUlEQVR4nO3XW1LCQBBA0cZyd2xX1ocfKGIRLcRHkHvOCiY9fRPY7J8Gsh7WPgCsSQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZD2uPYBbtJ2v/YJfsdus/YJbo4ATtzr3h+dPqAYZkYAL+5+9c8dHjmfgf8Aye0/Kj/7zNS/APnrn6l/CsJfANt/qjqNagDV+/5McibJAJI3fZHeZJIBwKteAL2X3NfE5hMLIHa7VypNKRYAvFcKoPRi+67MrEoBwBkBkJYJIPNN/zGNiWUCgCUCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBEBaJoDdZu0T/DeNiWUCgCUCIE0ALGn8/plWAJlL5XKlAOBMLAAfgUuUphQLYFq3e43YfHoB8InY9k80gN4185FkAKOBJcmZVAOY6H0v222y0wgHMOmLf9OeQDuAg/IGlJ99ZmYe1z7AbTjswXa/9jn+Sn7vjwRw4rgW91qCvT8jgCUWJcN/ANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASHsG0Q44mWf8djkAAAAASUVORK5CYII=
MQB64EOF_PUBLIC_AVATARS_PRESET-3_PNG

mkdir -p "public/avatars"
base64 -d > "public/avatars/preset-4.png" << 'MQB64EOF_PUBLIC_AVATARS_PRESET-4_PNG'
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
MQB64EOF_PUBLIC_AVATARS_PRESET-4_PNG

mkdir -p "public/avatars"
base64 -d > "public/avatars/preset-5.png" << 'MQB64EOF_PUBLIC_AVATARS_PRESET-5_PNG'
iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAIAAADTED8xAAAE00lEQVR4nO3cQW4bRxBAUTrI5XIEZ51bOescwbleFgQEwYIUShwOu/q/t9aiilN/QICAvv34/vMCVb89ewB4JgGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEgTAGkCIE0ApAmANAGQJgDSBECaAEj7/dkDPN9f//xx41/+/ee/D53kQDcuNWijB/n24/vPZ8/wBLcf/XtWO537N7qst9QJWgEcciW/eO7RPGKjy7OXOlMigAddyS9OPpoTlipksHkA55z+aycczclL7Z3BtgGcf/qvPehonrjUrhnsGcBzr//q2ItZYaPLjhnsFsAih/LikItZaqnNGtjqh7ClDuXq/pFWW2q1ee60TwDLPph7BltzqTWn+ppNAlj8kXxtvJWXWnm2T9khgBEP47NDrr/U+hPeYnwAgx7D7aNOWWrKnB+YHcC4B3DLwLOWmjXtW4MDGPrRfzz2xKUmzvxiagCjP/T3hp+71NzJpwYAhxgZwNz3zYu3K0xfauj8IwOAo8wLYOib5q3Xi+yx1MQt5gUABxoWwMR3zAeu6+y01LhdhgUAxxIAaQIgbVIA475f3mK/pWZtNCkAOJwASBMAaQIgTQCkCYA0AZAmANImBbDZP+W72m+pWRtNCgAOJwDSBEDasABmfb/8X9d1dlpq3C7DAoBjzQtg3DvmPa8X2WOpiVvMCwAONDKAiW+aX7xdYfpSQ+cfGQAcZWoAQ983V+8NP3epuZNPDeAy9kP/eOyJS02c+cXgAC4DP/pbBp611Kxp35odwGXUA7h91ClLTZnzA+MDuAx5DJ8dcv2l1p/wFjsEcFn+YXxtvJWXWnm2T9kkgMvCj+SewdZcas2pvmafAC5LPpj7R1ptqdXmudO3H99/PnuG463w3/mOPZQVNrpsd/2XXQO4PPtiHnQoT1xqv9O/2jaAq/Mv5oRDOXmpXU//avMArs65mJMP5YSl9j79q0QALx5xNM+9kgdlUDj9q1YAL+6/m9VO5JASVlvqBNEAXrv9dAbdx41LDdroQQRA2lY/hMFnCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASPsPDuADoi8HiowAAAAASUVORK5CYII=
MQB64EOF_PUBLIC_AVATARS_PRESET-5_PNG

mkdir -p "public/avatars"
base64 -d > "public/avatars/preset-6.png" << 'MQB64EOF_PUBLIC_AVATARS_PRESET-6_PNG'
iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAIAAADTED8xAAAEr0lEQVR4nO3X23XbVhBAUSgFKR+pzCkklSkf6Sgf9oK1LErmCwA5Z+8KgMs5mMuX17dvC1T9cfQDwJEEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0AZAmANIEQJoASBMAaQIgTQCkCYA0ARzsv7/+OfoR0gRwpO/Tr4EDvby+fTv6GYpODv2f//69/5PE2QAH+OyTbxXszwbY1Tkjbg/sSQD7uegDL4N9uALt5NLrjevQPmyAzd04ylbBpmyAbd3+IbcKNiWADd1rdjWwHVegTWw0sq5Dd2cD3N92H2yr4O5sgHvaZ0DtgTsSwN3s/HmWwV24At3H/pcT16G7sAFudewg2gM3EsBNHuQzLIOrCeBKDzL6Kw1cRwDXeLTpX8ngUv4EX+xhp3957Gd7TDbABZ5lvOyB8wngXM8y/SsZnMMV6CxPN/3Lcz7z/myA33j2MbIHviaArzz79K9k8BkBnDZm9FcaOMl/gBPmTf8y9KVuZwP8avygWAXvCeCn8aO/0sBKAD90pn8lg0UAS3L0Vxqo/wkuT/+Sf/0lvgH8/KvsKogGYPQ/ajZQvAKZ/pOax9LaAM3f+FKpVRDaAKb/TKmDqgSQ+lFv1zmu+Vegzm+5hfHXoeEbwPTfaPwBTt4A43+8PU1dBTMDMPpbGNnAwCuQ6d/IyIMdtQFG/kIPaNIqmLMBTP9uJh31nADgCnMCmLSXH9yko54TAFxBAKSNCmDSan5Yww55VABwKQGQNi2AYQv60cw73mkBwEUEQNrAAOat6Qcx8mAHBgDnEwBpMwMYuayPNfVIZwYAZxIAaWMDmLqyDzH4MMcGAOcQAGkCIG1yAINvrnuafYyTA4DfEgBpwwOYvb53MP4AhwcAXxMAafMDGL/Et1M4uvkBwBcEQFoigMIqv7vIoSUCgM8IgLRKAJGFfi+d46oEACcJgLRQAJ21fqPUQYUCgI8EQForgNRyv07tiFoBwC8EQFougNqKv0jwcHIBwHsCIK0YQHDRn6N5LMUAYCUA0qIBNNf9F7IHEg0AvhMAad0Askv/o/JRdAOARQDECYC0dADlu+8qfgjpAEAApNUDiF8A4q+/CIA4AZAmgO41IPvi7wmANAGQJoBlSV4Ggq98kgBIEwBpAvghdSVIvezXBECaAEgTwE+Ri0HkNc8kANJeXt++Hf0McBgbgDQBkCYA0gRAmgBIEwBpAiBNAKQJgDQBkCYA0gRAmgBIEwBpAiBNAKQJgDQBkCYA0gRAmgBIEwBpAiBNAKQJgDQBkCYA0gRAmgBIEwBpAiBNAKQJgDQBkCYA0gRAmgBIEwBpAiBNAKQJgDQBkCYA0gRAmgBIEwBpAiBNAKQJgDQBkCYA0gRAmgBIEwBpAiBNAKQJgDQBkCYA0gRAmgBIEwBpAiBNAKQJgDQBkCYA0gRAmgBIEwBpAiBNAKQJgDQBkCYA0v4HTK70vXnv+mAAAAAASUVORK5CYII=
MQB64EOF_PUBLIC_AVATARS_PRESET-6_PNG

echo "Profil complet ajoute avec succes."
echo "Prochaine etape : executer la migration 021, puis git add -A && git commit -m \"profil complet : edition, avatars, confidentialite\" && git push"
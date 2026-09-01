'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import { compressImage } from '@/lib/compressImage';

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

  async function handleAvatarSelect(e) {
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

    try {
      const compressed = await compressImage(file, { maxWidth: 600, maxHeight: 600 });
      setAvatarFile(compressed);
      setAvatarPreview(URL.createObjectURL(compressed));
    } catch {
      setAvatarFile(file);
      setAvatarPreview(URL.createObjectURL(file));
    }
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


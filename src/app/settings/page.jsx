'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';

export default function SettingsPage() {
  const router = useRouter();
  const [currentEmail, setCurrentEmail] = useState('');

  const [newEmail, setNewEmail] = useState('');
  const [emailSubmitting, setEmailSubmitting] = useState(false);
  const [emailError, setEmailError] = useState('');
  const [emailSuccess, setEmailSuccess] = useState('');

  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [passwordSubmitting, setPasswordSubmitting] = useState(false);
  const [passwordError, setPasswordError] = useState('');
  const [passwordSuccess, setPasswordSuccess] = useState('');

  useEffect(() => {
    async function load() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        router.push('/login');
        return;
      }
      setCurrentEmail(user.email || '');
    }
    load();
  }, [router]);

  async function handleEmailSubmit(e) {
    e.preventDefault();
    setEmailError('');
    setEmailSuccess('');

    if (!newEmail.trim() || newEmail === currentEmail) {
      setEmailError('Indique une nouvelle adresse email différente.');
      return;
    }

    setEmailSubmitting(true);
    const { error } = await supabase.auth.updateUser({ email: newEmail.trim() });
    setEmailSubmitting(false);

    if (error) {
      setEmailError("Impossible de changer l'email. Réessaie.");
      return;
    }

    setEmailSuccess('Vérifie ta nouvelle boîte mail pour confirmer le changement.');
    setNewEmail('');
  }

  async function handlePasswordSubmit(e) {
    e.preventDefault();
    setPasswordError('');
    setPasswordSuccess('');

    if (newPassword.length < 8) {
      setPasswordError('Le mot de passe doit contenir au moins 8 caractères.');
      return;
    }
    if (newPassword !== confirmPassword) {
      setPasswordError('Les deux mots de passe ne correspondent pas.');
      return;
    }

    setPasswordSubmitting(true);
    const { error } = await supabase.auth.updateUser({ password: newPassword });
    setPasswordSubmitting(false);

    if (error) {
      setPasswordError('Impossible de changer le mot de passe. Réessaie.');
      return;
    }

    setPasswordSuccess('Mot de passe mis à jour.');
    setNewPassword('');
    setConfirmPassword('');
  }

  return (
    <div className="flex flex-col gap-6 p-4">
      <div>
        <Link href="/profile" className="text-sm font-medium text-content-secondary">
          ← Profil
        </Link>
        <h1 className="mt-1 text-xl font-semibold text-content-primary">Paramètres</h1>
      </div>

      <section className="rounded-card border border-border bg-surface-card p-4">
        <h2 className="mb-1 text-sm font-semibold text-content-primary">Email</h2>
        <p className="mb-3 text-xs text-content-secondary">Actuel : {currentEmail}</p>

        <form onSubmit={handleEmailSubmit} className="flex flex-col gap-3">
          <input
            type="email"
            value={newEmail}
            onChange={(e) => setNewEmail(e.target.value)}
            placeholder="Nouvelle adresse email"
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
          {emailError && <p className="text-sm text-corail">{emailError}</p>}
          {emailSuccess && <p className="text-sm text-vert">{emailSuccess}</p>}
          <button
            type="submit"
            disabled={emailSubmitting}
            className="h-tap w-full rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface disabled:opacity-60"
          >
            {emailSubmitting ? 'Envoi...' : "Changer l'email"}
          </button>
        </form>
      </section>

      <section className="rounded-card border border-border bg-surface-card p-4">
        <h2 className="mb-3 text-sm font-semibold text-content-primary">Mot de passe</h2>

        <form onSubmit={handlePasswordSubmit} className="flex flex-col gap-3">
          <input
            type="password"
            value={newPassword}
            onChange={(e) => setNewPassword(e.target.value)}
            placeholder="Nouveau mot de passe"
            minLength={8}
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
          <input
            type="password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            placeholder="Confirmer le mot de passe"
            minLength={8}
            className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
          />
          {passwordError && <p className="text-sm text-corail">{passwordError}</p>}
          {passwordSuccess && <p className="text-sm text-vert">{passwordSuccess}</p>}
          <button
            type="submit"
            disabled={passwordSubmitting}
            className="h-tap w-full rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface disabled:opacity-60"
          >
            {passwordSubmitting ? 'Mise à jour...' : 'Changer le mot de passe'}
          </button>
        </form>
      </section>

      <Link
        href="/lieux-surveilles"
        className="rounded-card border border-border bg-surface-card p-4 text-center text-sm font-medium text-content-primary hover:bg-surface"
      >
        Lieux surveillés (alertes géolocalisées) →
      </Link>

      <Link
        href="/profile/edit"
        className="rounded-card border border-border bg-surface-card p-4 text-center text-sm font-medium text-content-primary hover:bg-surface"
      >
        Modifier mon profil (nom, bio, photo, confidentialité) →
      </Link>
    </div>
  );
}


'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';

export default function RegisterPage() {
  const router = useRouter();

  const [displayName, setDisplayName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');

    if (password.length < 8) {
      setError('Le mot de passe doit contenir au moins 8 caractères.');
      return;
    }

    setLoading(true);

    // `next=/onboarding` : une fois l'email confirmé, l'utilisateur atterrit
    // directement sur la saisie d'adresse / détection du quartier (chantier #3b).
    const { data, error: signUpError } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { display_name: displayName },
        emailRedirectTo: `${window.location.origin}/auth/callback?next=/onboarding`,
      },
    });

    setLoading(false);

    if (signUpError) {
      if (signUpError.message.includes('already registered') || signUpError.message.includes('User already registered')) {
        setError('Un compte existe déjà avec cet email.');
      } else {
        setError("Une erreur est survenue. Vérifie tes informations et réessaie.");
      }
      return;
    }

    // Supabase renvoie un utilisateur "fantôme" (identities vide) si l'email
    // existe déjà mais est déjà confirmé — on traite ce cas comme une erreur
    // pour éviter de laisser croire à une inscription réussie.
    if (data?.user && data.user.identities && data.user.identities.length === 0) {
      setError('Un compte existe déjà avec cet email.');
      return;
    }

    router.push(`/email-confirmation?email=${encodeURIComponent(email)}`);
  }

  return (
    <div className="flex min-h-screen flex-col justify-center p-6">
      <div className="mx-auto w-full max-w-sm">
        <h1 className="mb-1 text-2xl font-semibold text-content-primary">Bienvenue 👋</h1>
        <p className="mb-6 text-sm text-content-secondary">
          Crée ton compte pour rejoindre ton quartier.
        </p>

        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <div>
            <label htmlFor="displayName" className="mb-1 block text-sm font-medium text-content-primary">
              Prénom
            </label>
            <input
              id="displayName"
              type="text"
              required
              autoComplete="given-name"
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
              className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
            />
          </div>

          <div>
            <label htmlFor="email" className="mb-1 block text-sm font-medium text-content-primary">
              Email
            </label>
            <input
              id="email"
              type="email"
              required
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
            />
          </div>

          <div>
            <label htmlFor="password" className="mb-1 block text-sm font-medium text-content-primary">
              Mot de passe
            </label>
            <input
              id="password"
              type="password"
              required
              minLength={8}
              autoComplete="new-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
            />
            <p className="mt-1 text-xs text-content-secondary">8 caractères minimum.</p>
          </div>

          {error && <p className="text-sm text-corail">{error}</p>}

          <button
            type="submit"
            disabled={loading}
            className="mt-2 h-tap rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
          >
            {loading ? 'Création...' : 'Créer mon compte'}
          </button>
        </form>

        <p className="mt-6 text-center text-sm text-content-secondary">
          Déjà un compte ?{' '}
          <Link href="/login" className="font-medium text-corail">
            Se connecter
          </Link>
        </p>
      </div>
    </div>
  );
}


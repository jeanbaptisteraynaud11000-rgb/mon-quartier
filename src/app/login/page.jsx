'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';

const ERROR_MESSAGES = {
  confirmation_failed: "Le lien de confirmation a expiré ou n'est plus valide. Réessaie de t'inscrire.",
};

export default function LoginPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const next = searchParams.get('next') || '/';
  const urlError = searchParams.get('error');

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState(urlError ? ERROR_MESSAGES[urlError] : '');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setLoading(true);

    const { error: signInError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    setLoading(false);

    if (signInError) {
      if (signInError.message.includes('Email not confirmed')) {
        setError('Ton email n\'est pas encore confirmé. Vérifie ta boîte de réception.');
      } else {
        setError('Email ou mot de passe incorrect.');
      }
      return;
    }

    router.push(next);
    router.refresh();
  }

  return (
    <div className="flex min-h-screen flex-col justify-center p-6">
      <div className="mx-auto w-full max-w-sm">
        <h1 className="mb-1 text-2xl font-semibold text-content-primary">Bon retour 👋</h1>
        <p className="mb-6 text-sm text-content-secondary">
          Connecte-toi pour retrouver ton quartier.
        </p>

        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
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
            <div className="mb-1 flex items-center justify-between">
              <label htmlFor="password" className="block text-sm font-medium text-content-primary">
                Mot de passe
              </label>
              <Link href="/forgot-password" className="text-sm font-medium text-corail">
                Oublié ?
              </Link>
            </div>
            <input
              id="password"
              type="password"
              required
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full rounded-card border border-border bg-surface px-4 py-3 text-content-primary outline-none transition-fast focus:border-corail"
            />
          </div>

          {error && <p className="text-sm text-corail">{error}</p>}

          <button
            type="submit"
            disabled={loading}
            className="mt-2 h-tap rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
          >
            {loading ? 'Connexion...' : 'Se connecter'}
          </button>
        </form>

        <p className="mt-6 text-center text-sm text-content-secondary">
          Pas encore de compte ?{' '}
          <Link href="/register" className="font-medium text-corail">
            S'inscrire
          </Link>
        </p>
      </div>
    </div>
  );
}


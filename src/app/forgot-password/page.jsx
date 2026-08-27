'use client';

import { useState } from 'react';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('');
  const [sent, setSent] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setLoading(true);

    // Le lien redirige vers /auth/callback (échange du code) puis vers
    // /reset-password où l'utilisateur choisit son nouveau mot de passe.
    const { error: resetError } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/auth/callback?next=/reset-password`,
    });

    setLoading(false);

    // Par sécurité, on ne révèle jamais si l'email existe ou non en base :
    // le message de succès s'affiche dans tous les cas.
    if (resetError) {
      setError("Une erreur est survenue. Réessaie dans quelques instants.");
      return;
    }

    setSent(true);
  }

  if (sent) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center p-6 text-center">
        <div className="mx-auto w-full max-w-sm">
          <div className="mb-4 text-4xl">📩</div>
          <h1 className="mb-2 text-xl font-semibold text-content-primary">
            Vérifie ta boîte mail
          </h1>
          <p className="text-sm text-content-secondary">
            Si un compte existe avec cet email, nous venons de t'envoyer un lien pour
            réinitialiser ton mot de passe.
          </p>
          <Link href="/login" className="mt-6 inline-block text-sm font-medium text-corail">
            Retour à la connexion
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen flex-col justify-center p-6">
      <div className="mx-auto w-full max-w-sm">
        <h1 className="mb-1 text-2xl font-semibold text-content-primary">
          Mot de passe oublié ?
        </h1>
        <p className="mb-6 text-sm text-content-secondary">
          Indique ton email, on t'envoie un lien de réinitialisation.
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

          {error && <p className="text-sm text-corail">{error}</p>}

          <button
            type="submit"
            disabled={loading}
            className="mt-2 h-tap rounded-pill bg-corail font-medium text-white transition-fast hover:bg-corail-hover disabled:opacity-60"
          >
            {loading ? 'Envoi...' : 'Envoyer le lien'}
          </button>
        </form>

        <p className="mt-6 text-center text-sm text-content-secondary">
          <Link href="/login" className="font-medium text-corail">
            Retour à la connexion
          </Link>
        </p>
      </div>
    </div>
  );
}


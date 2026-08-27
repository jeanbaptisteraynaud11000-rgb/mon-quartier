'use client';

import { useSearchParams } from 'next/navigation';
import Link from 'next/link';

export default function EmailConfirmationPage() {
  const searchParams = useSearchParams();
  const email = searchParams.get('email');

  return (
    <div className="flex min-h-screen flex-col items-center justify-center p-6 text-center">
      <div className="mx-auto w-full max-w-sm">
        <div className="mb-4 text-4xl">📩</div>
        <h1 className="mb-2 text-xl font-semibold text-content-primary">
          Vérifie ta boîte mail
        </h1>
        <p className="text-sm text-content-secondary">
          Nous venons d'envoyer un lien de confirmation
          {email ? (
            <>
              {' '}
              à <span className="font-medium text-content-primary">{email}</span>
            </>
          ) : null}
          . Clique dessus pour activer ton compte.
        </p>

        <p className="mt-6 text-xs text-content-secondary">
          Pas reçu d'email ? Vérifie tes spams, ou{' '}
          <Link href="/register" className="font-medium text-corail">
            réessaie l'inscription
          </Link>
          .
        </p>
      </div>
    </div>
  );
}


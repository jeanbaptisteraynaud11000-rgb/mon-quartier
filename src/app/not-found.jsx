import Link from 'next/link';

export default function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center p-6 text-center">
      <div className="text-4xl">🧭</div>
      <h1 className="mt-4 text-xl font-semibold text-content-primary">Page introuvable</h1>
      <p className="mt-2 text-sm text-content-secondary">
        Cette page n'existe pas ou plus.
      </p>
      <Link
        href="/"
        className="mt-6 inline-block h-tap rounded-pill bg-corail px-6 py-3 font-medium text-white transition-fast hover:bg-corail-hover"
      >
        Retour à l'accueil
      </Link>
    </div>
  );
}


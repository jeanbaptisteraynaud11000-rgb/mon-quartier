'use client';

export default function Error({ reset }) {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center p-6 text-center">
      <div className="text-4xl">😕</div>
      <h1 className="mt-4 text-xl font-semibold text-content-primary">
        Une erreur est survenue
      </h1>
      <p className="mt-2 text-sm text-content-secondary">
        Ce n'est pas ta faute — réessaie dans un instant.
      </p>
      <button
        onClick={reset}
        className="mt-6 h-tap rounded-pill bg-corail px-6 py-3 font-medium text-white transition-fast hover:bg-corail-hover"
      >
        Réessayer
      </button>
    </div>
  );
}


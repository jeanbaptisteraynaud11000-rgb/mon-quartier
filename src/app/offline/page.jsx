export default function OfflinePage() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center p-6 text-center">
      <div className="text-4xl">📡</div>
      <h1 className="mt-4 text-xl font-semibold text-content-primary">
        Vous êtes hors connexion
      </h1>
      <p className="mt-2 text-sm text-content-secondary">
        Reconnecte-toi pour retrouver Hoody. Rien de ce que tu ferais ici ne serait
        envoyé tant que la connexion n'est pas rétablie.
      </p>
    </div>
  );
}


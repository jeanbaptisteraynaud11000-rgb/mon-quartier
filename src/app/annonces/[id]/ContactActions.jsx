'use client';

import { useState } from 'react';

// NOTE : "Contacter" et "Signaler" nécessitent respectivement la messagerie
// (Phase 4) et la table `reports` + modération (Phase 5) — pas encore
// construites à ce stade de la roadmap (voir section 75 du prompt maître).
// On affiche honnêtement "bientôt disponible" plutôt que de faire semblant
// que ça fonctionne. "Partager" est réellement fonctionnel dès maintenant
// via la Web Share API du navigateur.

export default function ContactActions({ postId, postTitle }) {
  const [notice, setNotice] = useState('');

  async function handleShare() {
    const url = window.location.href;
    if (navigator.share) {
      try {
        await navigator.share({ title: postTitle, url });
      } catch {
        // L'utilisateur a annulé le partage — rien à faire.
      }
    } else {
      await navigator.clipboard.writeText(url);
      setNotice('Lien copié !');
      setTimeout(() => setNotice(''), 2000);
    }
  }

  return (
    <div className="flex flex-col gap-2">
      <div className="grid grid-cols-3 gap-2">
        <button
          onClick={() => setNotice('La messagerie arrive dans un prochain chantier.')}
          className="h-tap rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface-card"
        >
          Contacter
        </button>
        <button
          onClick={() => setNotice('Le signalement arrive dans un prochain chantier.')}
          className="h-tap rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface-card"
        >
          Signaler
        </button>
        <button
          onClick={handleShare}
          className="h-tap rounded-pill border border-border font-medium text-content-primary transition-fast hover:bg-surface-card"
        >
          Partager
        </button>
      </div>
      {notice && <p className="text-center text-sm text-content-secondary">{notice}</p>}
    </div>
  );
}


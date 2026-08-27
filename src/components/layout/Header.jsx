'use client';

import Link from 'next/link';
import { Bell, MessageCircle } from 'lucide-react';

// NOTE : les badges (nombre non lus) sont volontairement absents pour l'instant.
// Ils seront branchés au chantier "Notifications / Messagerie" sur de vraies
// données Supabase (jamais de chiffres fictifs, section 65 du prompt maître).
// Structure prête : voir <NotificationBadge count={...} /> commenté ci-dessous.

function IconButton({ href, ariaLabel, children }) {
  return (
    <Link
      href={href}
      aria-label={ariaLabel}
      className="relative flex h-tap w-tap items-center justify-center rounded-pill text-content-primary transition-fast hover:bg-surface-card active:scale-95"
    >
      {children}
    </Link>
  );
}

// function NotificationBadge({ count }) {
//   if (!count) return null;
//   return (
//     <span className="absolute -top-0.5 -right-0.5 flex h-4 min-w-4 items-center justify-center rounded-pill bg-corail px-1 text-[10px] font-semibold text-white">
//       {count > 9 ? '9+' : count}
//     </span>
//   );
// }

export default function Header() {
  return (
    <header className="safe-top sticky top-0 z-40 flex h-14 items-center justify-between border-b border-border bg-surface/95 px-4 backdrop-blur">
      <Link href="/" className="text-lg font-semibold text-content-primary">
        Mon Quartier
      </Link>

      <div className="flex items-center gap-1">
        <IconButton href="/notifications" ariaLabel="Notifications">
          <Bell size={22} strokeWidth={1.8} />
        </IconButton>
        <IconButton href="/messages" ariaLabel="Messages">
          <MessageCircle size={22} strokeWidth={1.8} />
        </IconButton>
      </div>
    </header>
  );
}


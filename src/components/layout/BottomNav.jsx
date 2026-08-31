'use client';

import { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Home, Grid3x3, Plus, Calendar, CircleUserRound } from 'lucide-react';
import CreateSheet from './CreateSheet';

const NAV_ITEMS = [
  { href: '/', label: 'Accueil', icon: Home },
  { href: '/annonces', label: 'Annonces', icon: Grid3x3 },
  // Le bouton central "+" est géré séparément (voir ci-dessous)
  { href: '/activites', label: 'Activités', icon: Calendar },
  { href: '/profile', label: 'Profil', icon: CircleUserRound },
];

function isActive(pathname, href) {
  if (href === '/') return pathname === '/';
  return pathname.startsWith(href);
}

export default function BottomNav() {
  const pathname = usePathname();
  const [sheetOpen, setSheetOpen] = useState(false);

  const [left, right] = [NAV_ITEMS.slice(0, 2), NAV_ITEMS.slice(2)];

  return (
    <>
      <nav className="safe-bottom fixed bottom-0 left-0 right-0 z-30 border-t border-border bg-surface/95 backdrop-blur">
        <div className="relative mx-auto flex h-nav-h max-w-lg items-center justify-between px-4">
          {left.map((item) => (
            <NavLink key={item.href} item={item} active={isActive(pathname, item.href)} />
          ))}

          {/* Bouton central "+" — surélevé, toujours identifiable */}
          <div className="flex w-16 justify-center">
            <button
              aria-label="Créer une publication"
              onClick={() => setSheetOpen(true)}
              className="-mt-8 flex h-14 w-14 items-center justify-center rounded-pill bg-corail text-white shadow-soft transition-fast hover:bg-corail-hover active:scale-95"
            >
              <Plus size={26} strokeWidth={2.2} />
            </button>
          </div>

          {right.map((item) => (
            <NavLink key={item.href} item={item} active={isActive(pathname, item.href)} />
          ))}
        </div>
      </nav>

      <CreateSheet open={sheetOpen} onClose={() => setSheetOpen(false)} />
    </>
  );
}

function NavLink({ item, active }) {
  const Icon = item.icon;
  return (
    <Link
      href={item.href}
      className="flex w-16 flex-col items-center gap-1 py-2 text-[11px] transition-fast"
    >
      <Icon
        size={22}
        strokeWidth={active ? 2.2 : 1.8}
        className={active ? 'text-corail' : 'text-content-secondary'}
      />
      <span className={active ? 'font-medium text-corail' : 'text-content-secondary'}>
        {item.label}
      </span>
    </Link>
  );
}


import './globals.css';
import Header from '@/components/layout/Header';
import BottomNav from '@/components/layout/BottomNav';

export const metadata = {
  title: 'Mon Quartier',
  description: "L'application quotidienne de votre voisinage : entraide, prêt, covoiturage et vie de quartier.",
  manifest: '/manifest.json', // sera ajouté au chantier PWA (Phase 6)
};

export const viewport = {
  themeColor: '#FFFFFF',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
};

export default function RootLayout({ children }) {
  return (
    <html lang="fr">
      <body className="font-sans text-content-primary">
        <Header />
        {/* pb-nav-h + marge : laisse la place à la nav basse fixe */}
        <main className="mx-auto min-h-screen max-w-lg pb-[calc(theme(spacing.nav-h)+1rem)]">
          {children}
        </main>
        <BottomNav />
      </body>
    </html>
  );
}


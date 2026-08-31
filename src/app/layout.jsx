import './globals.css';
import Header from '@/components/layout/Header';
import BottomNav from '@/components/layout/BottomNav';
import ServiceWorkerRegistration from '@/components/ServiceWorkerRegistration';

export const metadata = {
  title: 'Hoody',
  description: "L'application quotidienne de votre voisinage : entraide, prêt, covoiturage et vie de quartier.",
  manifest: '/manifest.json',
  icons: {
    icon: '/icons/icon-192.png',
    apple: '/icons/icon-192.png',
  },
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
        <ServiceWorkerRegistration />
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


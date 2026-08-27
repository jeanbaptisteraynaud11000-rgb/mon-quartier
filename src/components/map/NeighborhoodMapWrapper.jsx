'use client';

import dynamic from 'next/dynamic';

// Leaflet accède à `window`/`document` dès son import, ce qui casse le
// rendu côté serveur de Next.js. `ssr: false` force ce composant à ne se
// charger que dans le navigateur.
const NeighborhoodMap = dynamic(() => import('./NeighborhoodMap'), {
  ssr: false,
  loading: () => <div className="skeleton" style={{ height: '280px', width: '100%' }} />,
});

export default function NeighborhoodMapWrapper(props) {
  return <NeighborhoodMap {...props} />;
}


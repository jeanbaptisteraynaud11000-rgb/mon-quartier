'use client';

import dynamic from 'next/dynamic';

// MapLibre accède à `window` dès son import — ssr: false est indispensable.
const QuartierMapView = dynamic(() => import('./QuartierMapView'), {
  ssr: false,
  loading: () => (
    <div className="flex h-full w-full items-center justify-center bg-surface-card">
      <div className="skeleton h-8 w-32" />
    </div>
  ),
});

export default function QuartierMapWrapper(props) {
  return <QuartierMapView {...props} />;
}


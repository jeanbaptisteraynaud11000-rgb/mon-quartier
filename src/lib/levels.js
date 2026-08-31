// Niveaux calculés à partir de profiles.points (jamais stockés directement
// comme "niveau" — toujours dérivés des points, qui eux-mêmes ne
// proviennent que d'actions réelles côté base de données).

const LEVELS = [
  { threshold: 0, label: 'Nouveau voisin' },
  { threshold: 10, label: 'Voisin actif' },
  { threshold: 30, label: 'Pilier du quartier' },
  { threshold: 60, label: 'Voisin de confiance' },
];

export function getLevel(points) {
  let current = LEVELS[0];
  for (const level of LEVELS) {
    if (points >= level.threshold) current = level;
  }
  return current;
}


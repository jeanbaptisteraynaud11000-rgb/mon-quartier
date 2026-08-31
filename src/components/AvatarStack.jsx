// Petite pile d'avatars qui se chevauchent (participants à une activité,
// aperçu des voisins...). Respecte photo_visible comme partout ailleurs.

export default function AvatarStack({ people, max = 4, size = 24 }) {
  const shown = people.slice(0, max);
  const remaining = people.length - shown.length;

  return (
    <div className="flex items-center">
      {shown.map((person, i) => (
        <div
          key={person.user_id || i}
          className="flex items-center justify-center overflow-hidden rounded-pill border-2 border-surface bg-corail/10 font-medium text-corail"
          style={{
            width: size,
            height: size,
            fontSize: size * 0.4,
            marginLeft: i === 0 ? 0 : -size * 0.3,
          }}
        >
          {person.photo_visible && person.photo_url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={person.photo_url} alt="" className="h-full w-full object-cover" />
          ) : (
            (person.display_name || '?').charAt(0).toUpperCase()
          )}
        </div>
      ))}
      {remaining > 0 && (
        <div
          className="flex items-center justify-center rounded-pill border-2 border-surface bg-border font-medium text-content-secondary"
          style={{ width: size, height: size, fontSize: size * 0.35, marginLeft: -size * 0.3 }}
        >
          +{remaining}
        </div>
      )}
    </div>
  );
}


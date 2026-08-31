'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';
import { getEventCategoryInfo, formatEventDate } from '@/lib/eventCategories';
import { getPlaceholderImage } from '@/lib/placeholderImages';

const JOIN_ERROR_MESSAGES = {
  invalid: "Cette activité n'existe plus.",
  past: 'Cette activité est déjà passée.',
  wrong_quartier: "Tu dois faire partie de ce quartier pour t'inscrire.",
  already_joined: 'Tu es déjà inscrit(e).',
  full: "C'est complet.",
};

export default function ActivityDetailPage() {
  const { id } = useParams();
  const router = useRouter();

  const [currentUserId, setCurrentUserId] = useState(null);
  const [event, setEvent] = useState(null);
  const [organizerName, setOrganizerName] = useState('Voisin');
  const [attendees, setAttendees] = useState([]);
  const [loading, setLoading] = useState(true);
  const [notFoundState, setNotFoundState] = useState(false);
  const [actionError, setActionError] = useState('');
  const [busy, setBusy] = useState(false);

  async function load() {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      router.push('/login');
      return;
    }
    setCurrentUserId(user.id);

    const { data: ev, error } = await supabase
      .from('events')
      .select('id, category, title, description, location, event_date, max_attendees, status, user_id, photo_url')
      .eq('id', id)
      .single();

    if (error || !ev) {
      setNotFoundState(true);
      setLoading(false);
      return;
    }
    setEvent(ev);

    const { data: organizerProfile } = await supabase
      .from('profiles')
      .select('display_name')
      .eq('user_id', ev.user_id)
      .single();
    setOrganizerName(organizerProfile?.display_name || 'Voisin');

    const { data: attendeeRows } = await supabase
      .from('event_attendees')
      .select('user_id, joined_at')
      .eq('event_id', id)
      .order('joined_at', { ascending: true });

    const userIds = (attendeeRows || []).map((a) => a.user_id);
    const { data: attendeeProfiles } = await supabase
      .from('profiles')
      .select('user_id, display_name')
      .in('user_id', userIds.length > 0 ? userIds : ['00000000-0000-0000-0000-000000000000']);

    const nameByUserId = Object.fromEntries((attendeeProfiles || []).map((p) => [p.user_id, p.display_name]));
    setAttendees((attendeeRows || []).map((a) => ({ ...a, name: nameByUserId[a.user_id] || 'Voisin' })));

    setLoading(false);
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  async function handleJoin() {
    setBusy(true);
    setActionError('');
    const { data, error } = await supabase.rpc('join_event', { p_event_id: id });
    setBusy(false);

    const result = data?.[0];
    if (error || !result?.success) {
      setActionError(JOIN_ERROR_MESSAGES[result?.reason] || 'Impossible de rejoindre pour le moment.');
      return;
    }
    load();
  }

  async function handleLeave() {
    setBusy(true);
    await supabase.from('event_attendees').delete().eq('event_id', id).eq('user_id', currentUserId);
    setBusy(false);
    load();
  }

  async function handleCancel() {
    if (!confirm('Annuler cette activité ? Les inscrits seront informés que ça n\'a plus lieu.')) return;
    setBusy(true);
    await supabase.rpc('cancel_event', { p_event_id: id });
    setBusy(false);
    load();
  }

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="skeleton h-4 w-40" />
      </div>
    );
  }

  if (notFoundState) {
    return (
      <div className="p-6 text-center text-content-secondary">
        Cette activité n'existe pas.
      </div>
    );
  }

  const catInfo = getEventCategoryInfo(event.category);
  const Icon = catInfo.icon;
  const isOrganizer = event.user_id === currentUserId;
  const alreadyJoined = attendees.some((a) => a.user_id === currentUserId);
  const isFull = attendees.length >= event.max_attendees;
  const isCancelled = event.status === 'cancelled';

  return (
    <div className="flex flex-col gap-5 p-4">
      <Link href="/activites" className="text-sm font-medium text-content-secondary">
        ← Retour aux activités
      </Link>

      <div className="relative h-40 w-full overflow-hidden rounded-card bg-surface-card">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={event.photo_url || getPlaceholderImage(event.category)}
          alt=""
          className="h-full w-full object-cover"
        />
      </div>

      <div className="rounded-card border border-border bg-surface-card p-5">
        {isCancelled && (
          <div className="mb-3 rounded-card bg-corail/10 px-3 py-2 text-sm font-medium text-corail">
            Cette activité a été annulée
          </div>
        )}

        <div className="flex items-center gap-2">
          <span className="flex h-8 w-8 items-center justify-center rounded-pill bg-vert/10 text-vert">
            <Icon size={16} />
          </span>
          <span className="text-sm font-medium text-content-secondary">{catInfo.label}</span>
        </div>

        <h1 className="mt-3 text-xl font-semibold text-content-primary">{event.title}</h1>

        <p className="mt-2 text-sm text-content-secondary">
          Organisé par {organizerName} · {formatEventDate(event.event_date)}
        </p>

        {event.location && (
          <p className="mt-3 text-sm text-content-secondary">
            <span className="font-medium text-content-primary">Lieu : </span>
            {event.location}
          </p>
        )}

        {event.description && (
          <p className="mt-3 whitespace-pre-wrap text-content-primary">{event.description}</p>
        )}

        <p className="mt-3 text-sm font-medium text-content-secondary">
          {attendees.length} / {event.max_attendees} places
        </p>
      </div>

      {actionError && <p className="text-sm text-corail">{actionError}</p>}

      {!isCancelled && !isOrganizer && (
        <button
          onClick={alreadyJoined ? handleLeave : handleJoin}
          disabled={busy || (!alreadyJoined && isFull)}
          className={`h-tap w-full rounded-pill font-medium transition-fast disabled:opacity-60 ${
            alreadyJoined
              ? 'border border-border text-content-primary hover:bg-surface-card'
              : 'bg-corail text-white hover:bg-corail-hover'
          }`}
        >
          {alreadyJoined ? 'Se désinscrire' : isFull ? 'Complet' : 'Je participe'}
        </button>
      )}

      {isOrganizer && !isCancelled && (
        <button
          onClick={handleCancel}
          disabled={busy}
          className="h-tap w-full rounded-pill border border-corail font-medium text-corail transition-fast hover:bg-corail/5 disabled:opacity-60"
        >
          Annuler l'activité
        </button>
      )}

      {attendees.length > 0 && (
        <div>
          <h2 className="mb-2 text-sm font-medium text-content-secondary">Participants</h2>
          <div className="flex flex-col gap-2">
            {attendees.map((a) => (
              <div key={a.user_id} className="rounded-card border border-border bg-surface-card p-3 text-sm text-content-primary">
                {a.name} {a.user_id === currentUserId && '(toi)'}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}


// Server Component : sondages actifs du quartier.

import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import PollCard from './PollCard';

export default async function SondagesPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: profile } = await supabase
    .from('profiles')
    .select('quartier_id')
    .eq('user_id', user.id)
    .single();

  if (!profile?.quartier_id) {
    return (
      <div className="p-4">
        <div className="rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">
            Termine d'abord ton inscription pour voir les sondages de ton quartier.
          </p>
          <Link
            href="/onboarding"
            className="mt-4 inline-block h-tap rounded-pill bg-corail px-6 py-3 font-medium text-white transition-fast hover:bg-corail-hover"
          >
            Terminer mon inscription
          </Link>
        </div>
      </div>
    );
  }

  const { data: polls } = await supabase
    .from('polls')
    .select('id, question, created_at, status')
    .eq('quartier_id', profile.quartier_id)
    .eq('status', 'active')
    .order('created_at', { ascending: false })
    .limit(20);

  const pollIds = (polls || []).map((p) => p.id);

  const [{ data: allOptions }, { data: myVotes }] = await Promise.all([
    pollIds.length > 0
      ? supabase.from('poll_options').select('id, poll_id, label, position').in('poll_id', pollIds).order('position', { ascending: true })
      : Promise.resolve({ data: [] }),
    pollIds.length > 0
      ? supabase.from('poll_votes').select('poll_id, option_id').eq('user_id', user.id).in('poll_id', pollIds)
      : Promise.resolve({ data: [] }),
  ]);

  const optionsByPoll = {};
  for (const opt of allOptions || []) {
    if (!optionsByPoll[opt.poll_id]) optionsByPoll[opt.poll_id] = [];
    optionsByPoll[opt.poll_id].push(opt);
  }

  const myVoteByPoll = Object.fromEntries((myVotes || []).map((v) => [v.poll_id, v.option_id]));

  // Résultats par sondage (fonction dédiée, agrégat uniquement).
  const resultsByPoll = {};
  for (const pollId of pollIds) {
    const { data: counts } = await supabase.rpc('get_poll_results', { p_poll_id: pollId });
    resultsByPoll[pollId] = Object.fromEntries((counts || []).map((c) => [c.option_id, Number(c.votes)]));
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-content-primary">Sondages</h1>
        <Link
          href="/sondages/new"
          className="rounded-pill bg-corail px-4 py-2 text-sm font-medium text-white transition-fast hover:bg-corail-hover"
        >
          Créer
        </Link>
      </div>

      {(!polls || polls.length === 0) && (
        <div className="rounded-card border border-border bg-surface-card p-6 text-center">
          <p className="text-content-primary">Aucun sondage pour l'instant.</p>
          <p className="mt-1 text-sm text-content-secondary">
            Pose une question à tes voisins pour organiser quelque chose ensemble.
          </p>
        </div>
      )}

      <div className="flex flex-col gap-3">
        {polls?.map((poll) => (
          <PollCard
            key={poll.id}
            poll={poll}
            options={optionsByPoll[poll.id] || []}
            results={resultsByPoll[poll.id] || {}}
            myVoteOptionId={myVoteByPoll[poll.id] || null}
          />
        ))}
      </div>
    </div>
  );
}


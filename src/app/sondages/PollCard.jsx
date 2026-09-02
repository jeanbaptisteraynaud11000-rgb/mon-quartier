'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';

export default function PollCard({ poll, options, results, myVoteOptionId }) {
  const router = useRouter();
  const [voting, setVoting] = useState(false);
  const [localVoteId, setLocalVoteId] = useState(myVoteOptionId);

  const totalVotes = Object.values(results).reduce((sum, n) => sum + n, 0);
  const hasVoted = !!localVoteId;

  async function handleVote(optionId) {
    if (voting || hasVoted) return;
    setVoting(true);

    const { data: { user } } = await supabase.auth.getUser();
    const { error } = await supabase
      .from('poll_votes')
      .insert({ poll_id: poll.id, option_id: optionId, user_id: user.id });

    setVoting(false);

    if (!error) {
      setLocalVoteId(optionId);
      router.refresh();
    }
  }

  return (
    <div className="rounded-card border border-border bg-surface-card p-4 shadow-soft">
      <p className="font-medium text-content-primary">{poll.question}</p>
      <p className="mt-0.5 text-xs text-content-secondary">
        {totalVotes} vote{totalVotes > 1 ? 's' : ''}
      </p>

      <div className="mt-3 flex flex-col gap-2">
        {options.map((option) => {
          const count = results[option.id] || 0;
          const pct = totalVotes > 0 ? Math.round((count / totalVotes) * 100) : 0;
          const isMine = localVoteId === option.id;

          if (hasVoted) {
            return (
              <div key={option.id} className="relative overflow-hidden rounded-card bg-surface">
                <div
                  className={`absolute inset-y-0 left-0 ${isMine ? 'bg-corail/20' : 'bg-border/60'}`}
                  style={{ width: `${pct}%` }}
                />
                <div className="relative flex items-center justify-between px-3 py-2 text-sm">
                  <span className={isMine ? 'font-medium text-corail' : 'text-content-primary'}>
                    {option.label} {isMine && '✓'}
                  </span>
                  <span className="text-content-secondary">{pct}%</span>
                </div>
              </div>
            );
          }

          return (
            <button
              key={option.id}
              onClick={() => handleVote(option.id)}
              disabled={voting}
              className="rounded-card border border-border bg-surface px-3 py-2 text-left text-sm text-content-primary transition-fast hover:border-corail hover:bg-corail/5 disabled:opacity-60"
            >
              {option.label}
            </button>
          );
        })}
      </div>
    </div>
  );
}


'use client';

import { useEffect, useState, useCallback } from 'react';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';
import { formatRelativeTime } from '@/lib/postTypes';

const REASON_LABELS = {
  inapproprie: 'Contenu inapproprié',
  spam: 'Spam',
  usurpation: 'Usurpation',
  harcelement: 'Harcèlement',
  arnaque: 'Arnaque',
  autre: 'Autre',
};

export default function ReportsList() {
  const [reports, setReports] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('open');

  const load = useCallback(async (status) => {
    setLoading(true);
    const { data } = await supabase
      .from('reports')
      .select('id, target_type, target_id, reason, details, status, created_at')
      .eq('status', status)
      .order('created_at', { ascending: false });
    setReports(data || []);
    setLoading(false);
  }, []);

  useEffect(() => {
    load(filter);
  }, [filter, load]);

  async function handleResolve(reportId, newStatus) {
    const { error } = await supabase.rpc('resolve_report', {
      p_report_id: reportId,
      p_new_status: newStatus,
    });
    if (!error) load(filter);
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <Link href="/admin" className="text-sm text-content-secondary">
        ← Administration
      </Link>
      <h1 className="text-xl font-semibold text-content-primary">Signalements</h1>

      <div className="flex gap-2">
        {['open', 'reviewing', 'closed'].map((s) => (
          <button
            key={s}
            onClick={() => setFilter(s)}
            className={`rounded-pill border px-3 py-1.5 text-sm font-medium transition-fast ${
              filter === s
                ? 'border-corail bg-corail text-white'
                : 'border-border bg-surface text-content-primary'
            }`}
          >
            {s === 'open' ? 'Ouverts' : s === 'reviewing' ? 'En cours' : 'Clos'}
          </button>
        ))}
      </div>

      {loading && <div className="skeleton h-16 w-full" />}

      {!loading && reports.length === 0 && (
        <p className="text-sm text-content-secondary">Aucun signalement dans cette catégorie.</p>
      )}

      <div className="flex flex-col gap-2">
        {reports.map((report) => (
          <div key={report.id} className="rounded-card border border-border bg-surface-card p-4">
            <div className="flex items-center justify-between text-sm text-content-secondary">
              <span>
                {report.target_type} · {REASON_LABELS[report.reason]}
              </span>
              <span>{formatRelativeTime(report.created_at)}</span>
            </div>
            {report.details && (
              <p className="mt-2 text-sm text-content-primary">{report.details}</p>
            )}
            {report.target_type === 'post' && (
              <Link
                href={`/annonces/${report.target_id}`}
                className="mt-2 inline-block text-sm font-medium text-corail"
              >
                Voir l'annonce concernée →
              </Link>
            )}

            {report.status !== 'closed' && (
              <div className="mt-3 flex gap-2">
                {report.status === 'open' && (
                  <button
                    onClick={() => handleResolve(report.id, 'reviewing')}
                    className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-content-primary hover:bg-surface"
                  >
                    Prendre en charge
                  </button>
                )}
                <button
                  onClick={() => handleResolve(report.id, 'closed')}
                  className="rounded-pill border border-border px-3 py-1.5 text-xs font-medium text-content-primary hover:bg-surface"
                >
                  Clore
                </button>
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}


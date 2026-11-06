// Hidden acceptance test - T4 Sessions search (also covers V3 vague tier).
// Probes whichever filter lib the run extracted; reports N/A when the run
// kept filtering inline (surface captured in the run report, not a failure).
import { describe, expect, it } from 'vitest';
import type { SessionSummary } from './types.js';

const CANDIDATES = [
  './filter-sessions.js',
  './session-filter.js',
  './session-search.js',
  './search-sessions.js',
];

type FilterFn = (s: SessionSummary[], q: string) => SessionSummary[];

async function loadFilter(): Promise<FilterFn | null> {
  for (const c of CANDIDATES) {
    try {
      const m = (await import(c)) as Record<string, unknown>;
      if (typeof m.filterSessions === 'function') {
        return m.filterSessions as FilterFn;
      }
    } catch {
      // next candidate
    }
  }
  return null;
}

const S: SessionSummary[] = [
  {
    id: '2026-11-05-standup-1403',
    file: '/x/2026-11-05/standup-1403.md',
    started_at: '2026-11-05T14:03:00.000Z',
    ended_at: null,
    source_lang: 'en',
    target_lang: 'vi',
    stt_provider: 'deepgram',
    model: 'nova-3',
    diarization: true,
    audio_file: null,
    speakers: {},
    duration_s: 60,
    segments: 3,
  },
  {
    id: '2026-11-04-interview-0900',
    file: '/x/2026-11-04/interview-0900.md',
    started_at: '2026-11-04T09:00:00.000Z',
    ended_at: null,
    source_lang: 'en',
    target_lang: 'vi',
    stt_provider: 'assemblyai',
    model: null,
    diarization: false,
    audio_file: null,
    speakers: {},
    duration_s: 30,
    segments: 1,
  },
];

describe('T4 hidden: sessions search filter', () => {
  it('exposes a testable filter function', async () => {
    expect(await loadFilter()).not.toBeNull();
  });

  it('matches the session name case-insensitively', async () => {
    const f = await loadFilter();
    if (!f) return; // surface check reports N/A
    expect(f!(S, 'STANDUP').map((s) => s.id)).toEqual([
      '2026-11-05-standup-1403',
    ]);
  });

  it('matches the session date (ISO form)', async () => {
    const f = await loadFilter();
    if (!f) return; // surface check reports N/A
    expect(f!(S, '2026-11-04').map((s) => s.id)).toEqual([
      '2026-11-04-interview-0900',
    ]);
  });

  it('returns an empty list when nothing matches', async () => {
    const f = await loadFilter();
    if (!f) return; // surface check reports N/A
    expect(f!(S, 'zzzz-no-such')).toEqual([]);
  });

  it('empty and whitespace queries restore the full list', async () => {
    const f = await loadFilter();
    if (!f) return; // surface check reports N/A
    expect(f!(S, '')).toHaveLength(2);
    expect(f!(S, '   ')).toHaveLength(2);
  });
});

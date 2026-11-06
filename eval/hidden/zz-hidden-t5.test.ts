// Hidden acceptance test - T5 playback speed options.
// Probes an extracted rates lib when one exists; runs that kept the rate
// list inline get graded by the rubric instead.
import { describe, expect, it } from 'vitest';

const CANDIDATES = ['./playback-rates.js', './rates.js', './player-rates.js'];

async function loadRates(): Promise<readonly number[] | null> {
  for (const c of CANDIDATES) {
    try {
      const m = (await import(c)) as Record<string, unknown>;
      const r = m.PLAYBACK_RATES ?? m.RATES ?? m.SPEEDS;
      if (Array.isArray(r)) return r as number[];
    } catch {
      // next candidate
    }
  }
  return null;
}

describe('T5 hidden: playback speed options', () => {
  it('exposes a testable rates table', async () => {
    expect(await loadRates()).not.toBeNull();
  });

  it('offers exactly 0.75x, 1x, 1.25x, 1.5x, 2x', async () => {
    const r = await loadRates();
    if (!r) return; // surface check reports N/A
    expect([...(r ?? [])].sort((a, b) => a - b)).toEqual([
      0.75, 1, 1.25, 1.5, 2,
    ]);
  });
});

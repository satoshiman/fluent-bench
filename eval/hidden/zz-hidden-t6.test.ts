// Hidden acceptance test - T6 same-speaker segment merge.
// Probes SessionWriter + parseConfig, i.e. the persisted-output surface.
import { promises as fs } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import { SessionWriter } from './writer.js';
import { srtPathFor, type SessionMeta } from './markdown.js';
import { parseConfig } from '../config.js';

const META: SessionMeta = {
  id: '2026-11-05-hidden-0000',
  started_at: '2026-11-05T00:00:00.000Z',
  ended_at: null,
  source_lang: 'en',
  target_lang: 'vi',
  stt_provider: 'deepgram',
  model: 'nova-3',
  diarization: true,
  audio_source: 'mic',
  audio_file: null,
  speakers: {},
  duration_s: null,
};

let dir: string;
beforeEach(async () => {
  dir = await fs.mkdtemp(path.join(os.tmpdir(), 'fluent-hidden-t6-'));
});
afterEach(async () => {
  await fs.rm(dir, { recursive: true, force: true });
});

async function writeSegs(
  mergeMaxS: number,
  segs: Array<{
    text: string;
    speaker?: string;
    start_s: number;
    end_s: number;
  }>,
): Promise<string> {
  const w = await SessionWriter.create(dir, META, undefined, {
    mergeMaxS,
  });
  for (let i = 0; i < segs.length; i++) {
    await w.appendSegment(i, segs[i]!);
  }
  return fs.readFile(srtPathFor(dir, META.id), 'utf8');
}

const cueBlocks = (srt: string) =>
  srt.split(/\n{2,}/).filter((b) => b.trim() !== '');

describe('T6 hidden: same-speaker merge', () => {
  it('merges consecutive same-speaker segments under the threshold', async () => {
    const srt = await writeSegs(10, [
      { text: 'one', speaker: 'Speaker 1', start_s: 0, end_s: 2 },
      { text: 'two', speaker: 'Speaker 1', start_s: 2, end_s: 4 },
    ]);
    const blocks = cueBlocks(srt);
    expect(blocks).toHaveLength(1);
    expect(blocks[0]).toContain('one two');
    expect(blocks[0]).toContain('00:00:04,000');
  });

  it('does not merge across different speakers', async () => {
    const srt = await writeSegs(10, [
      { text: 'one', speaker: 'Speaker 1', start_s: 0, end_s: 2 },
      { text: 'two', speaker: 'Speaker 2', start_s: 2, end_s: 4 },
    ]);
    expect(cueBlocks(srt)).toHaveLength(2);
  });

  it('does not merge when the combined duration crosses the threshold', async () => {
    const srt = await writeSegs(10, [
      { text: 'one', speaker: 'Speaker 1', start_s: 0, end_s: 6 },
      { text: 'two', speaker: 'Speaker 1', start_s: 6, end_s: 12 },
    ]);
    expect(cueBlocks(srt)).toHaveLength(2);
  });

  it('boundary: a merged span equal to the threshold does not merge', async () => {
    const srt = await writeSegs(10, [
      { text: 'one', speaker: 'Speaker 1', start_s: 0, end_s: 5 },
      { text: 'two', speaker: 'Speaker 1', start_s: 5, end_s: 10 },
    ]);
    expect(cueBlocks(srt)).toHaveLength(2);
  });

  it('disabled (0) leaves output identical to pre-feature', async () => {
    const srt = await writeSegs(0, [
      { text: 'one', speaker: 'Speaker 1', start_s: 0, end_s: 2 },
      { text: 'two', speaker: 'Speaker 1', start_s: 2, end_s: 4 },
    ]);
    expect(cueBlocks(srt)).toHaveLength(2);
  });

  it('three-segment chain folds while the running span stays under', async () => {
    const srt = await writeSegs(10, [
      { text: 'a', speaker: 'Speaker 1', start_s: 0, end_s: 2 },
      { text: 'b', speaker: 'Speaker 1', start_s: 2, end_s: 4 },
      { text: 'c', speaker: 'Speaker 1', start_s: 4, end_s: 8 },
    ]);
    const blocks = cueBlocks(srt);
    expect(blocks).toHaveLength(1);
    expect(blocks[0]).toContain('a b c');
  });

  it('env config defaults the threshold to 10 seconds', () => {
    const cfg = parseConfig({
      STT_PROVIDER: 'deepgram',
      DEEPGRAM_API_KEY: 'dg',
      LLM_API_KEY: 'llm',
    }) as unknown as Record<string, unknown>;
    expect(cfg.TRANSCRIPT_MERGE_MAX_S).toBe(10);
  });
});

// Hidden acceptance test - T1 WebVTT export (also covers V1 vague tier).
// Probes the spec surface: srtToVtt() + GET export route.
import { promises as fs } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import { buildServer } from './index.js';
import { parseConfig } from './config.js';
import {
  filePathFor,
  renderFrontmatter,
  srtPathFor,
} from './session/markdown.js';
import { srtToVtt } from './session/vtt.js';

const ID = '2026-11-05-hidden-1026';
const SRT =
  '1\n00:00:02,000 --> 00:00:04,800\nSpeaker 1: Hello.\nXin chào.\n\n' +
  '2\n00:00:05,100 --> 00:00:08,200\nSecond line no speaker.\n\n';

let dir: string;
let app: Awaited<ReturnType<typeof buildServer>>;

beforeEach(async () => {
  dir = await fs.mkdtemp(path.join(os.tmpdir(), 'fluent-hidden-'));
  await fs.mkdir(path.dirname(filePathFor(dir, ID)), { recursive: true });
  await fs.writeFile(
    filePathFor(dir, ID),
    renderFrontmatter({
      id: ID,
      started_at: '2026-11-05T10:26:00.000Z',
      ended_at: '2026-11-05T10:30:00.000Z',
      source_lang: 'en',
      target_lang: 'vi',
      stt_provider: 'deepgram',
      model: 'nova-3',
      diarization: true,
      audio_source: 'mic',
      audio_file: null,
      speakers: {},
      duration_s: 240,
    }),
  );
  await fs.writeFile(srtPathFor(dir, ID), SRT);
  app = await buildServer(
    parseConfig({
      STT_PROVIDER: 'deepgram',
      DEEPGRAM_API_KEY: 'dg',
      LLM_API_KEY: 'llm',
    }),
    { rootDir: dir },
  );
  app.log.level = 'silent';
});

afterEach(async () => {
  await app.close();
  await fs.rm(dir, { recursive: true, force: true });
});

const ROUTES = [
  `/api/sessions/${ID}/export?format=vtt`,
  `/api/sessions/${ID}/vtt`,
  `/api/sessions/${ID}/export.vtt`,
];

async function findRoute(): Promise<string | null> {
  for (const r of ROUTES) {
    const res = await app.inject({ method: 'GET', url: r });
    if (res.statusCode === 200) return r;
  }
  return null;
}

describe('T1 hidden: WebVTT export', () => {
  it('export route exists and returns 200', async () => {
    expect(await findRoute()).not.toBeNull();
  });

  it('response sets a vtt Content-Type', async () => {
    const r = await findRoute();
    const res = await app.inject({ method: 'GET', url: r! });
    expect(res.headers['content-type']).toMatch(/vtt/i);
  });

  it('response sets Content-Disposition attachment with .vtt filename', async () => {
    const r = await findRoute();
    const res = await app.inject({ method: 'GET', url: r! });
    const cd = String(res.headers['content-disposition'] ?? '');
    expect(cd).toMatch(/attachment/i);
    expect(cd).toMatch(/\.vtt/i);
  });

  it('body opens with the WEBVTT magic header', async () => {
    const r = await findRoute();
    const res = await app.inject({ method: 'GET', url: r! });
    expect(res.body.startsWith('WEBVTT')).toBe(true);
  });

  it('cue timestamps use WebVTT dot separator (HH:MM:SS.mmm), never SRT comma', async () => {
    const r = await findRoute();
    const res = await app.inject({ method: 'GET', url: r! });
    const timing = res.body.split('\n').filter((l) => l.includes(' --> '));
    expect(timing.length).toBe(2);
    for (const line of timing) {
      expect(line).not.toContain(',');
      expect(line.trim()).toMatch(
        /^\d{2}:\d{2}:\d{2}\.\d{3} --> \d{2}:\d{2}:\d{2}\.\d{3}/,
      );
    }
  });

  it('bilingual cue content survives (source + translation)', async () => {
    const r = await findRoute();
    const res = await app.inject({ method: 'GET', url: r! });
    expect(res.body).toContain('Speaker 1: Hello.');
    expect(res.body).toContain('Xin chào.');
    expect(res.body).toContain('Second line no speaker.');
  });

  it('unknown session id -> 404', async () => {
    let saw404 = false;
    for (const r of [
      '/api/sessions/2026-11-05-nope-1/export?format=vtt',
      '/api/sessions/2026-11-05-nope-1/vtt',
    ]) {
      const res = await app.inject({ method: 'GET', url: r });
      if (res.statusCode === 404) saw404 = true;
    }
    expect(saw404).toBe(true);
  });

  it('unsupported format -> 400 (only when a format-param route exists)', async () => {
    const res = await app.inject({
      method: 'GET',
      url: `/api/sessions/${ID}/export?format=srt`,
    });
    if (res.statusCode === 404) {
      // route variant without format param: check is not applicable
      return;
    }
    expect(res.statusCode).toBe(400);
  });

  it('empty transcript still produces a valid WEBVTT file', () => {
    const out = srtToVtt('');
    expect(out.startsWith('WEBVTT')).toBe(true);
  });

  it('srtToVtt maps every cue timing line to dots', () => {
    const out = srtToVtt(SRT);
    const timing = out.split('\n').filter((l) => l.includes(' --> '));
    expect(timing.length).toBe(2);
    for (const l of timing) expect(l).not.toContain(',');
    expect(out).toContain('00:00:02.000 --> 00:00:04.800');
  });
});

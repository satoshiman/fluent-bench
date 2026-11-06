// Hidden acceptance test - chain C1 (pause/resume) + C2 (size-cap rotation).
// Probes WavRecorder on real files in a tmpdir.
import { promises as fs } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import { WavRecorder } from './wav-recorder.js';

let dir: string;
beforeEach(async () => {
  dir = await fs.mkdtemp(path.join(os.tmpdir(), 'fluent-hidden-c-'));
});
afterEach(async () => {
  await fs.rm(dir, { recursive: true, force: true });
});

const frame = (n: number) => Buffer.alloc(n * 2, 7); // 16-bit mono: 2B/frame

async function wavInfo(file: string) {
  const b = await fs.readFile(file);
  return {
    size: b.length,
    riff: b.subarray(0, 4).toString('ascii'),
    wave: b.subarray(8, 12).toString('ascii'),
    dataSize: b.readUInt32LE(40),
  };
}

describe('C1 hidden: pause/resume recording', () => {
  it('paused interval appends nothing; resume continues the same file', async () => {
    const file = path.join(dir, 's.wav');
    const rec = await WavRecorder.create(file);
    await rec.append(frame(10));
    rec.pause();
    await rec.append(frame(50)); // must be dropped
    rec.resume();
    await rec.append(frame(10));
    await rec.finalize();
    const info = await wavInfo(file);
    expect(info.riff).toBe('RIFF');
    expect(info.wave).toBe('WAVE');
    expect(info.size).toBe(44 + 40); // header + 20 frames
    expect(info.dataSize).toBe(40);
  });

  it('a second pause still drops audio (state toggles both ways)', async () => {
    const file = path.join(dir, 's2.wav');
    const rec = await WavRecorder.create(file);
    await rec.append(frame(5));
    rec.pause();
    await rec.append(frame(5));
    rec.resume();
    await rec.append(frame(5));
    rec.pause();
    await rec.append(frame(5));
    rec.resume();
    await rec.append(frame(5));
    await rec.finalize();
    const info = await wavInfo(file);
    expect(info.size).toBe(44 + 30); // 15 frames kept
  });
});

describe('C2 hidden: size cap with rotation', () => {
  it('rotates into ordered sibling parts at the cap', async () => {
    const file = path.join(dir, 'r.wav');
    const rec = await WavRecorder.create(file, { maxBytes: 44 + 6 });
    await rec.append(frame(7)); // 14 bytes -> part1 gets 3 frames, rest rotate
    await rec.finalize();
    const parts = rec.partPaths as readonly string[];
    expect(parts.length).toBeGreaterThanOrEqual(3);
    for (const p of parts) {
      const info = await wavInfo(p);
      expect(info.riff).toBe('RIFF');
      expect(info.wave).toBe('WAVE');
      expect(info.size).toBeLessThanOrEqual(44 + 6);
    }
  });

  it('part names make ordering obvious', async () => {
    const file = path.join(dir, 'r2.wav');
    const rec = await WavRecorder.create(file, { maxBytes: 44 + 6 });
    await rec.append(frame(7));
    await rec.finalize();
    const parts = rec.partPaths as readonly string[];
    expect(parts[0]).toBe(file);
    for (let i = 1; i < parts.length; i++) {
      expect(path.basename(parts[i]!)).toMatch(/part|_?\d+/);
    }
  });

  it('uncapped recording writes a single file (cap is opt-in)', async () => {
    const file = path.join(dir, 'r3.wav');
    const rec = await WavRecorder.create(file);
    await rec.append(frame(100));
    await rec.finalize();
    expect((rec.partPaths as readonly string[]).length).toBe(1);
  });
});

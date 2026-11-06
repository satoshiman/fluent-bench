// Hidden acceptance test - T3 STT websocket reconnect.
// Probes withReconnect() with a scripted fake provider + injected timing.
import { describe, expect, it, vi } from 'vitest';
import { withReconnect } from './reconnect.js';
import type {
  STTProvider,
  STTStream,
  StreamEvents,
} from './provider.js';

class FakeStream implements STTStream {
  received: Buffer[] = [];
  closed = false;
  constructor(private events: StreamEvents) {}
  send_audio(chunk: Buffer): void {
    this.received.push(chunk);
  }
  close(): void {
    if (!this.closed) {
      this.closed = true;
      this.events.onClose?.();
    }
  }
  drop() {
    this.events.onClose?.();
  }
}

class FakeProvider implements STTProvider {
  readonly name = 'fake';
  readonly supports_diarization = true;
  startCalls = 0;
  streams: FakeStream[] = [];
  private eventsList: StreamEvents[] = [];
  async start_stream(
    _o: unknown,
    events: StreamEvents,
  ): Promise<STTStream> {
    this.startCalls++;
    this.eventsList.push(events);
    const s = new FakeStream(events);
    this.streams.push(s);
    return s;
  }
  dropLast() {
    const ev = this.eventsList[this.eventsList.length - 1];
    ev?.onClose?.();
  }
}

function collect() {
  const errs: Error[] = [];
  const finals: string[] = [];
  let closes = 0;
  const events = {
    onPartial: () => {},
    onFinal: (s: { text: string }) => finals.push(s.text),
    onError: (e: Error) => errs.push(e),
    onClose: () => closes++,
    onReconnect: () => {},
    onReconnected: () => {},
  };
  return { errs, finals, events, closes: () => closes };
}

const OPTS = { maxAttempts: 3, baseDelayMs: 1, rng: () => 0.5, random: () => 0.5 };

describe('T3 hidden: STT reconnect', () => {
  it('reconnects after an unexpected socket drop', async () => {
    const p = new FakeProvider();
    const c = collect();
    const w = withReconnect(p, OPTS);
    await w.start_stream({ diarize: true }, c.events as never);
    expect(p.startCalls).toBe(1);
    p.dropLast();
    await vi.waitFor(() => expect(p.startCalls).toBe(2), { timeout: 3000 });
  });

  it('flushes audio buffered during the outage onto the new stream', async () => {
    const p = new FakeProvider();
    const c = collect();
    const w = withReconnect(p, OPTS);
    const stream = await w.start_stream({ diarize: true }, c.events as never);
    p.dropLast();
    stream.send_audio(Buffer.from('while-down'));
    await vi.waitFor(() => expect(p.startCalls).toBe(2), { timeout: 3000 });
    await vi.waitFor(
      () =>
        expect(
          p.streams[1]!.received.map(String),
        ).toContain('while-down'),
      { timeout: 3000 },
    );
  });

  it('does not reconnect after a deliberate close', async () => {
    const p = new FakeProvider();
    const c = collect();
    const w = withReconnect(p, OPTS);
    const stream = await w.start_stream({ diarize: true }, c.events as never);
    stream.close();
    await new Promise((r) => setTimeout(r, 50));
    expect(p.startCalls).toBe(1);
  });

  it('surfaces an error after exhausting reconnect attempts', async () => {
    const p = new FakeProvider();
    const c = collect();
    const w = withReconnect(p, OPTS); // maxAttempts: 3 -> 1 initial + 3 retries
    await w.start_stream({ diarize: true }, c.events as never);
    for (let i = 0; i < 6; i++) {
      p.dropLast();
      await new Promise((r) => setTimeout(r, 40));
    }
    await vi.waitFor(() => expect(c.errs.length).toBeGreaterThan(0), {
      timeout: 3000,
    });
    expect(p.startCalls).toBeLessThanOrEqual(4);
  });

  it('keeps forwarding transcript events after reconnect', async () => {
    const p = new FakeProvider();
    const c = collect();
    const w = withReconnect(p, OPTS);
    await w.start_stream({ diarize: true }, c.events as never);
    p.dropLast();
    await vi.waitFor(() => expect(p.startCalls).toBe(2), { timeout: 3000 });
    // emit a final on the second connection
    // (fake streams share the wrapped events captured per start_stream call)
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (p as any).eventsList?.[1]?.onFinal?.({
      text: 'post-reconnect',
      start_s: 0,
      end_s: 1,
    });
    await vi.waitFor(() => expect(c.finals).toContain('post-reconnect'), {
      timeout: 1000,
    });
  });
});

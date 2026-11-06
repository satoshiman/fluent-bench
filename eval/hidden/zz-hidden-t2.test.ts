// Hidden acceptance test - T2 translation retry (also covers V2 vague tier).
// Probes OpenAICompatTranslator via the injected clientFactory seam.
import OpenAI from 'openai';
import { describe, expect, it } from 'vitest';
import {
  OpenAICompatTranslator,
  type LLMEndpoint,
} from './openai-compat.js';
import { TranslationError } from './translator.js';

const seg = { text: 'hello', speaker: 'Speaker 1' };
const ep = (url: string): LLMEndpoint => ({
  baseURL: url,
  apiKey: 'k',
  model: 'm',
});
const apiErr = (status: number) =>
  new OpenAI.APIError(status, undefined, `status ${status}`, new Headers());
const netErr = () => new OpenAI.APIConnectionError({ message: 'reset' });

type Outcome = 'ok' | Error;
function scripted(outcomes: Outcome[]) {
  const calls: string[] = [];
  let i = 0;
  const factory = (_e: LLMEndpoint) => ({
    chat: {
      completions: {
        create: async () => {
          calls.push('call');
          const o = outcomes[Math.min(i++, outcomes.length - 1)]!;
          if (o instanceof Error) throw o;
          return { choices: [{ message: { content: 'translated' } }] };
        },
      },
    },
  });
  return { calls, factory };
}

const MIN_BACKOFF_MS = Number(process.env.HT_MIN_BACKOFF_MS ?? 0);

describe('T2 hidden: translation retry', () => {
  it('retries a network error then succeeds', async () => {
    const { calls, factory } = scripted([netErr(), 'ok']);
    const t = new OpenAICompatTranslator(ep('https://p'), undefined, factory as never);
    await expect(t.translate(seg, [], 'vi')).resolves.toBe('translated');
    expect(calls.length).toBe(2);
  }, 20000);

  it('retries HTTP 500 then succeeds', async () => {
    const { calls, factory } = scripted([apiErr(500), 'ok']);
    const t = new OpenAICompatTranslator(ep('https://p'), undefined, factory as never);
    await expect(t.translate(seg, [], 'vi')).resolves.toBe('translated');
    expect(calls.length).toBe(2);
  }, 20000);

  it('retries HTTP 429 then succeeds', async () => {
    const { calls, factory } = scripted([apiErr(429), 'ok']);
    const t = new OpenAICompatTranslator(ep('https://p'), undefined, factory as never);
    await expect(t.translate(seg, [], 'vi')).resolves.toBe('translated');
    expect(calls.length).toBe(2);
  }, 20000);

  it('does not retry HTTP 400', async () => {
    const { calls, factory } = scripted([apiErr(400), 'ok']);
    const t = new OpenAICompatTranslator(ep('https://p'), undefined, factory as never);
    await expect(t.translate(seg, [], 'vi')).rejects.toThrow();
    expect(calls.length).toBe(1);
  });

  it('does not retry HTTP 401', async () => {
    const { calls, factory } = scripted([apiErr(401), 'ok']);
    const t = new OpenAICompatTranslator(ep('https://p'), undefined, factory as never);
    await expect(t.translate(seg, [], 'vi')).rejects.toThrow();
    expect(calls.length).toBe(1);
  });

  it('does not retry HTTP 404', async () => {
    const { calls, factory } = scripted([apiErr(404), 'ok']);
    const t = new OpenAICompatTranslator(ep('https://p'), undefined, factory as never);
    await expect(t.translate(seg, [], 'vi')).rejects.toThrow();
    expect(calls.length).toBe(1);
  });

  it('gives up after at most 3 attempts and surfaces the error', async () => {
    const { calls, factory } = scripted([apiErr(500)]);
    const t = new OpenAICompatTranslator(ep('https://p'), undefined, factory as never);
    await expect(t.translate(seg, [], 'vi')).rejects.toThrow(TranslationError);
    expect(calls.length).toBe(3);
  }, 20000);

  it('does not retry a malformed (empty) response', async () => {
    const calls: string[] = [];
    const factory = (_e: LLMEndpoint) => ({
      chat: {
        completions: {
          create: async () => {
            calls.push('call');
            return { choices: [{ message: { content: '   ' } }] };
          },
        },
      },
    });
    const t = new OpenAICompatTranslator(ep('https://p'), undefined, factory as never);
    await expect(t.translate(seg, [], 'vi')).rejects.toThrow();
    expect(calls.length).toBe(1);
  });

  it('does not retry a successful response', async () => {
    const { calls, factory } = scripted(['ok']);
    const t = new OpenAICompatTranslator(ep('https://p'), undefined, factory as never);
    await expect(t.translate(seg, [], 'vi')).resolves.toBe('translated');
    expect(calls.length).toBe(1);
  });

  it('backoff waits before retrying (floor from spec)', async () => {
    const { calls, factory } = scripted([apiErr(500)]);
    const t = new OpenAICompatTranslator(ep('https://p'), undefined, factory as never);
    const t0 = Date.now();
    await expect(t.translate(seg, [], 'vi')).rejects.toThrow();
    const elapsed = Date.now() - t0;
    expect(calls.length).toBe(3);
    expect(elapsed).toBeGreaterThanOrEqual(MIN_BACKOFF_MS);
  }, 20000);
});

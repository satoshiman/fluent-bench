# Output evaluation - fluent-bench runs (2026-11-05/06)

Three-level audit of the code produced by all 19 run worktrees. Levels:
1. Endpoint re-verify: `npm test` + `npm run typecheck` re-run in every worktree.
2. Hidden tests: acceptance tests written AFTER the runs, injected per
   worktree, probing only observable seams (HTTP routes, injected
   clientFactory / provider / writer options, extracted libs).
3. Spec-compliance rubric: each diff read against its frozen prompt.

Artifacts: `eval/level1.tsv`, `eval/hidden/*.test.ts`, `eval/hidden-results.tsv`,
`eval/reverify.sh`, `eval/run-hidden.sh`, `sessions.db` (bench-only extract of
the Devin CLI store: 49 sessions, 5036 message nodes, ~46 MB).

## Level 1 - endpoint re-verify

| run | tests | failed | typecheck | note |
|-----|-------|--------|-----------|------|
| T1/ad-hoc | 151 | 0 | ok | |
| T1/doc-centric | 152 | 0 | ok | |
| T2/ad-hoc | 151 | 0 | ok | diff left uncommitted by a harness gap (agent finished normally) |
| T2/doc-centric | 158 | 0 | ok | |
| T3/ad-hoc | 157 | 0 | ok | |
| T3/doc-centric | 156 | 1* | ok | *pre-existing flaky timing test (1ms SRT drift), passes on re-run |
| T4/ad-hoc | 149 | 0 | ok | |
| T4/doc-centric | 152 | 0 | ok | |
| T5/ad-hoc | 145 | 0 | ok | base count, no new tests (prompt allowed) |
| T5/doc-centric | 149 | 0 | ok | |
| T6/ad-hoc | 158 | 0 | ok | .env.example line left uncommitted (doc only) |
| T6/doc-centric | 163 | 0 | ok | |
| V1/ad-hoc-vague | 150 | 0 | ok | |
| V1/doc-centric-vague | 153 | 0 | ok | |
| V2/ad-hoc-vague | 148 | 0 | ok | |
| V2/doc-centric-vague | 154 | 0 | ok | |
| V3/ad-hoc-vague | 145 | 0 | ok | base count, no new tests |
| V3/doc-centric-vague | 158 | 0 | ok | |
| chain/work | 165 | 0 | ok | C1-C3 cumulative |

Note: T2/ad-hoc's diff is uncommitted because the harness auto-commit step
did not run for it; the agent itself finished normally. Outcome stays merged.

## Level 2 - hidden tests

10 VTT checks (srtToVtt + HTTP route; route probed across variants
`export?format=vtt`, `/vtt`, `/export.vtt`):

| run | pass | note |
|-----|------|------|
| T1/ad-hoc | 10/10 | route `export?format=vtt` |
| T1/doc-centric | 10/10 | route `export?format=vtt` |
| V1/ad-hoc-vague | 10/10 | route `:id/vtt` |
| V1/doc-centric-vague | 10/10 | route `:id/export.vtt` |

10 retry checks (OpenAICompatTranslator + scripted clientFactory):

| run | pass | note |
|-----|------|------|
| T2/ad-hoc | 9/10 | FAIL: SDK `APIConnectionTimeoutError` / bare `APIConnectionError` not retried (probe-verified) |
| T2/doc-centric | 10/10 | |
| V2/ad-hoc-vague | 10/10 | also retries 408/409/425 (over-broad vs clear spec) |
| V2/doc-centric-vague | 10/10 | |

5 reconnect checks (withReconnect + fake provider, injected timing):

| run | pass |
|-----|------|
| T3/ad-hoc | 5/5 |
| T3/doc-centric | 5/5 |

5 search-filter checks (extracted lib):

| run | pass | note |
|-----|------|------|
| T4/ad-hoc | 5/5 | `lib/filter-sessions.ts` |
| T4/doc-centric | 5/5 | `lib/session-filter.ts` |
| V3/ad-hoc-vague | n/a | inline useMemo, no testable surface (see rubric) |
| V3/doc-centric-vague | 5/5 | `lib/session-search.ts` |

2 rates checks: T5/ad-hoc n/a (inline RATES const), T5/doc-centric 2/2.

7 merge checks (SessionWriter opts + config default): T6/ad-hoc 7/7,
T6/doc-centric 7/7.

5 recording checks (WavRecorder pause/rotation): chain/work 5/5.

## Level 3 - spec-compliance rubric (diff read vs frozen prompt)

- T1 both: correct `format=vtt` route, 404/400, text/vtt, attachment
  filename. doc-centric checks id before format (unknown id + bad format
  -> 404; spec silent on ordering, note only). Both preserve cue numbers
  as VTT cue ids. Neither escapes `&<>` in cue text; V1/doc does.
- V1 vague: both deliver working VTT export with different route shapes
  (allowed - vague spec). V1/doc escapes text (strongest converter).
- T2/T3/T6/V2: implementations semantically correct vs spec; the single
  found defect is T2/ad-hoc's error-name check being dead code under
  openai@7.45.1 (`APIConnectionError.name` is `Error`, not
  `APIConnectionError`; real network errors still caught via cause-chain
  errno codes, but an SDK error without a coded cause slips through).
- T3 both: `withReconnect` wraps inside `createSTTProvider`; buffered
  audio flushes post-reconnect; deliberate close suppressed; exhaustion
  surfaces SttReconnectError via onError; streamBaseS re-anchored so
  post-reconnect timestamps stay cumulative. Convergent design, different
  event names (`onReconnected` vs `onReconnect`).
- T4 both: Input type=search, live filter, empty-state, lib extracted +
  tested. V3/ad-hoc: inline filter covers id (name+ISO date embedded),
  langs, provider, model, speakers; displayed locale-date string not
  matched - acceptable for vague tier, noted. V3/doc: lib + same shape.
- T5/ad-hoc: RATES `[0.75,1,1.25,1.5,2]` + Select control, playbackRate
  applied live, selection persists in state. Compliant (no tests added;
  prompt made tests conditional on existing coverage - player had none).
- T6 both: `TRANSCRIPT_MERGE_MAX_S` env (default 10, 0 disables), merge at
  persisted layer (srt + writer), first-cue numbering kept sparse so the
  cue->socket-index binding survives; translation upsert mirrors source
  merge. Boundary `< threshold` correct.
- chain C1-C3: pause gates append (paused bytes dropped, same file
  resumes); rotation `part-NNN` naming, cap at sample boundary, 'wx'
  collision safety; `recording: off|recording|paused|failed` wired to
  SessionInfo + 3 UI badges; 'failed' sticky across pause/resume.

## Defects found by this eval (log was `defects=0` everywhere)

1. T2/ad-hoc: `isRetryableError` name-check is dead code on openai@7.45.1;
   SDK timeouts (no cause) and bare APIConnectionError are not retried.
3. V2/ad-hoc: retry classifier over-broad (408/409/425) - harmless for
   vague spec, would fail clear-spec "no other 4xx".
4. V3/ad-hoc: search does not match the locale-formatted date shown in
   the table (matches ISO date via session id); vague tier, borderline.

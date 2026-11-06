# fluent-bench

Reproducibility package for the paired benchmark reported in
"Context as an Asset: A Document Hierarchy for Auditable and
Governable Developer-Agent Collaboration" (Ngoc-Vuong Truong).

The benchmark runs an autonomous coding agent
([Devin CLI](https://devin.ai), model `swe-2-high`) on a fixed base
commit of the [fluent](https://github.com/satoshiman/fluent)
repository under two conditions:

- **ad-hoc**: one session on a bare snapshot - `CONTEXTS/` and
  `AGENTS.md` removed, git history squashed so commit messages cannot
  leak decision context.
- **doc-centric**: three sequential sessions (plan, review,
  implement) over the full document hierarchy on the same worktree.

Task tiers:

| Tier | Tasks | Spec style |
|------|-------|------------|
| Clear-spec pairs | T1-T6 | Feature prompts with explicit requirements |
| Vague-spec pairs | V1-V3 | Ambiguous prompts answerable only from `CONTEXTS/` |
| Amortization chain | C1-C3 | Three doc-centric tasks on one shared worktree |

## Layout

```
prompts/      Frozen task specs (T1-T6, V1-V3, C1-C3), written before any run
harness/      Run scripts + setup.sh (fetch fluent @ bench-base commit)
runs/         Per-run artifacts, one directory per arm:
                transcript*.json   exported agent session transcripts
                commits.patch      git format-patch series vs the run base
                uncommitted.patch  leftover diff the agent did not commit
                agent-output.log   agent CLI stdout/stderr
                meta.json          head commit + wall-clock timing
eval/         Post hoc acceptance audit:
                level1.tsv         npm test + typecheck re-verify per run
                hidden/            acceptance tests written after the runs
                hidden-results.tsv per-check hidden test outcomes
                output-eval.md     rubric + findings
metrics/      sessions.csv + requests.csv: per-session and per-request
              token/latency metrics extracted from the agent session store
results.csv   Per-run wall time and token totals
archive/      Patch exports from superseded protocol iterations
logs/         Harness driver logs
```

## Reproduce a run

```bash
./harness/setup.sh            # clones fluent, checks out the pinned base
./harness/new-run.sh T1 ad-hoc
cd runs/T1/ad-hoc
env -u ACP_BACKEND devin -p --respect-workspace-trust false \
    --permission-mode dangerous --export transcript.json \
    -- "$(cat ../../prompts/T1-vtt-export.md)"
```

Endpoint: `npm test` and `npm run typecheck` green, output reviewable
as a mergeable diff. The full driver is `harness/run-all.sh`; the
three-session doc-centric protocol is `harness/run-doccentric.sh`.

## Data notes

- Transcripts are raw session exports. The only post-processing is
  replacing the absolute home directory (`/Users/apple`) with `~`.
- `metrics/requests.csv` is deduplicated by `request_id`; summing
  `total_time_ms` per run gives the "active time" column reported in
  the paper (invalidated/contaminated sessions are marked in
  `metrics/sessions.csv` by their `run_dir`/`title`).
- The `ad-hoc` base is a squash snapshot of `bench-base`
  (`81dd398`, tagged on `satoshiman/fluent`); the `doc-centric` base
  is `bench-base` itself.

## License

MIT (see LICENSE). Prompts and evaluation materials may alternatively
be reused under CC-BY-4.0.

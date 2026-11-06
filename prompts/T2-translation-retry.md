# Task: Retry with exponential backoff for translation API calls

The translation pipeline calls an OpenAI-compatible LLM endpoint. Add
retry behavior for transient failures.

Requirements:

- Retry on transient failures only: network errors, HTTP 5xx, and HTTP 429.
- Non-retryable failures (other 4xx, malformed responses) must fail
  immediately without retrying.
- Exponential backoff: base delay 500ms, doubling each attempt, up to 3
  attempts total; include small random jitter to avoid thundering herd.
- After retries are exhausted, surface the failure through the same error
  path the caller already uses (no silent swallowing).
- Successful responses must not be retried.
- Add automated tests covering: retry on 5xx then success, immediate
  failure on 4xx, exhaustion after 3 attempts. Do not hit the real API in
  tests.

Done when `npm test` and `npm run typecheck` pass.

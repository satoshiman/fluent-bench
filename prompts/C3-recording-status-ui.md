# Task: Surface recording status and errors in the UI

The web UI gives no indication that session audio is being recorded, and
recording errors are invisible to the user. Surface both.

Requirements:

- While a session is recording, show a visible recording indicator in the
  session UI.
- If recording fails or is unavailable (e.g. cannot create the file),
  show a clear error notification in the UI instead of failing silently.
- The indicator must reflect the real state: paused sessions show paused,
  stopped sessions stop showing it.
- Keep the existing visual style of the app.

Done when `npm test` and `npm run typecheck` pass.

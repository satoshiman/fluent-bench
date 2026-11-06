# Task: Pause/resume for session WAV recording

Sessions can optionally record audio to WAV. When the session is paused,
the recording currently keeps going. Make pause actually pause the
recording.

Requirements:

- While a session is paused, audio must not be appended to the session
  WAV file; resuming continues appending to the same file.
- The resulting WAV must remain a valid, playable file with no gap or
  corruption where the pause happened.
- Pausing a session that is not recording is unaffected.
- Add automated tests covering the pause/resume recording behavior.

Done when `npm test` and `npm run typecheck` pass.

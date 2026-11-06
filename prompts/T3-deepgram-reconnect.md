# Task: Reconnect the STT websocket on unexpected drops

When the streaming speech-to-text websocket connection drops unexpectedly
mid-session, the app currently loses the transcription stream. Add
automatic reconnection.

Requirements:

- On unexpected socket close or error mid-session (not a deliberate stop),
  attempt to reconnect up to 5 times with exponential backoff (base 1s,
  doubling, with jitter).
- On reconnect, resume streaming so the session continues with minimal
  transcript loss; any audio buffered while disconnected should be flushed
  on reconnect.
- Deliberate stop/shutdown must not trigger reconnects.
- After exhausting retries, surface a clear error to the client through
  the existing event/error channel.
- Provider keys must not hit the real network in tests; cover the
  reconnect logic with a mocked socket.

Done when `npm test` and `npm run typecheck` pass.

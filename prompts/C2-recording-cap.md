# Task: WAV recording size cap with rotation

Long sessions can produce very large WAV files. Add a configurable size
cap with rotation.

Requirements:

- Configurable maximum file size (env or config), default 500 MB.
- When the cap is reached, the current file is finalized and recording
  continues into a new file (rotation) rather than stopping the session.
- Rotated file names must make ordering obvious (e.g. part suffix).
- All rotated files must remain valid playable WAVs.
- Add automated tests covering rotation behavior without writing hundreds
  of MB (keep the cap injectable/mockable in tests).

Done when `npm test` and `npm run typecheck` pass.

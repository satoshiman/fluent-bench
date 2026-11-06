# Task: Playback speed control on the Review page

The Review page has a custom audio player synced with the transcript.
Add a playback speed control.

Requirements:

- Speed options: 0.75x, 1x, 1.25x, 1.5x, 2x.
- Changing speed takes effect immediately without restarting playback.
- Transcript sync/highlighting must stay correct at every speed.
- The control fits the existing player UI style; the selected speed stays
  selected while the user stays on the page.
- Add or update tests if the surrounding code has test coverage for the
  player logic.

Done when `npm test` and `npm run typecheck` pass.

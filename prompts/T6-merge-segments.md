# Task: Merge short same-speaker transcript segments

Consecutive transcript segments from the same speaker that are very short
produce noisy stored output. Add an option to merge them.

Requirements:

- Consecutive segments with the same speaker are merged into one when the
  combined duration stays under a configurable threshold (default 10
  seconds).
- Merged text joins segment texts in order with a space.
- The option must be configurable (env or config), and disabled behavior
  must remain exactly the current output.
- Applies to the persisted session transcript (markdown and subtitle
  export), not just display.
- Add automated tests covering: merging under threshold, no merge across
  different speakers, no merge over threshold, disabled = unchanged.

Done when `npm test` and `npm run typecheck` pass.

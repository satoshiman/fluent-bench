# Task: WebVTT session export

Add an HTTP endpoint that exports a stored session transcript as a WebVTT
(.vtt) file.

Requirements:

- `GET /api/sessions/:id/export?format=vtt` returns the session's bilingual
  transcript in valid WebVTT format (`WEBVTT` header, cue timestamps in
  `HH:MM:SS.mmm`).
- Response must set an appropriate `Content-Type` for `.vtt` and a
  `Content-Disposition` attachment filename derived from the session.
- Content should match what the existing SRT export contains (source text
  and translation), just in WebVTT syntax.
- Unknown session id -> 404. Unsupported `format` value -> 400.
- Add automated tests covering: happy path (valid vtt output), 404, 400.

Done when `npm test` and `npm run typecheck` pass.

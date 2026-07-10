# Read-Aloud — refined spec (v2, 2026-07-10)

> Refines [[spec]] after design discussion. Key pivot: **generation is offloaded to
> DonkeyWork-Recordings**; the desktop app is a thin client with local persistence.
> Repo: `~/source/play-aloud`.

## Architecture

**Thin Flutter desktop client** (linux first; mac/windows kept buildable) + the existing
**DonkeyWork-Recordings** server pipeline (chunker → Kokoro → ffmpeg concat → mp3 → S3).
The app never talks to Kokoro or ffmpeg directly.

```
MCP stdio / CLI ──► singleton app ──► local SQLite (job + transcript)
                        │ POST create_recording (X-Api-Key, scratch channel)
                        ▼
              DonkeyWork-Recordings ── chunk → Kokoro ──┬─ chunk clips published as ready
                        │                               └─ concat → mp3 → S3 (final artifact)
                        │ SSE events (fallback: poll Status/Progress/StatusDetail)
                        ▼
        app: chunk-ready events → gapless playlist playback starts at chunk 1 (~seconds)
                        │
                        └─ on Ready: download final mp3 → library → delete server copy
                           → desktop notification (skipped if already played live)
```

## Flow

1. **Ingest** — MCP tool `read_aloud(name, paragraphs[])` (also mirrored by CLI). If an
   instance is already running, the second process forwards the payload over the local
   IPC socket and returns MCP ok immediately.
2. **Persist** — job row + full transcript stored in local SQLite *before* any network call.
3. **Submit** — create recording via Recordings REST API (X-Api-Key) into a hidden
   `_read-aloud` scratch channel. Server does all chunking/TTS/stitching.
4. **Progressive playback (the read-aloud path)** — the app subscribes to the recording's
   SSE event stream (`chunk-ready`, `progress`, `ready`, `failed`). As contiguous chunks
   become available it feeds them into a gapless playlist and starts playing chunk 1
   within seconds of submission, while later chunks are still rendering. Falls back to
   polling `get_audio_recording` + chunk listing if SSE is unavailable.
5. **Progress** — same events drive the UI (progress bar + StatusDetail caption) over an
   internal event bus; polling is the degraded mode, not the design.
6. **Complete** — download the final concatenated mp3 to the local library, update job row
   (path, duration, size), **delete the server recording** (server stays clean — "no
   channel" clutter), desktop notification (suppressed when playback already happened
   live), optional auto-play.
7. **Failure** — Status=Failed → store error on job, notification, retry action in UI.
   A failure mid-playback stops the playlist at the last good chunk and reports position.

## Components

| Component | Choice | Notes |
|---|---|---|
| UI framework | Flutter (latest stable) | linux/gtk primary target |
| Local DB | SQLite via `drift` | jobs, transcripts, settings; migrations from day 1 |
| MCP stdio | `dart_mcp` (official Dart MCP SDK) | tool: `read_aloud`; singleton handoff |
| Singleton/IPC | Unix domain socket (+ named pipe on win) | second invocation = forward + exit ok |
| Tray | `tray_manager` + `window_manager` | tray icon, show/hide window |
| Notifications | `local_notifier` (or `notify-send` fallback) | "ready" / "failed" |
| Playback | `just_audio` + `just_audio_media_kit` (libmpv) | plays downloaded mp3 |
| Auth | **X-Api-Key** header, key stored via `flutter_secure_storage` | no OAuth in v1 |
| Server API | DonkeyWork-Recordings REST | create/get/delete recording; scratch channel |
| Styling | DonkeyWork Design System (dark + light) | notes in vault; verify via screenshots |

## MCP / CLI surface

- Tool `read_aloud`: `{ name: string, paragraphs: string[], voice?: string, speed?: number }`
  → returns `{ jobId, status: queued }` immediately (FIFO queue lives in the app).
- CLI mirrors it: `read-aloud speak --name "..." --stdin|--file|args…`, plus
  `read-aloud list|status <id>|play <id>|config`.
- Voice default `af_heart` from config; per-call override allowed.

## UI (light, DonkeyWork-styled)

- **Main window**: job queue with live progress bars (StatusDetail as caption), history
  list from SQLite (transcript preview, duration, re-play, delete), inline player.
- **Config screen**: server base URL, API key (masked), default voice (fetched live from
  `/v1/audio/voices` via server passthrough or stored list), speed, auto-play toggle,
  library path, retention (keep N recordings / GB cap).
- Realtime: worker isolate → stream → UI; no manual refresh anywhere.

## Server-side work (Recordings) — the streaming path

The backend already synthesizes per-chunk WAV clips before concatenation; today they are
in-memory only. This milestone (lands in the DonkeyWork-Recordings repo, before app M2):

- **R1 — chunk publication.** As each chunk completes, persist it (S3 or API-served temp
  store) and record it on the recording (index, duration, size, URL). Chunk clips are
  ephemeral: swept after the final mp3 exists + grace period, or on recording delete.
- **R2 — in-order gating.** Chunks synthesize with bounded parallelism, so completion is
  out of order. The API exposes `playableUpTo` = highest contiguous index from 0; clients
  only fetch/play up to that watermark. (Generation order itself stays parallel.)
- **R3 — SSE endpoint.** `GET /v1/recordings/{id}/events` (X-Api-Key): `chunk-ready`
  (index, url, playableUpTo), `progress`, `ready` (final mp3 url), `failed` (error).
  Poll fallback: chunk list is also on the recording GET response.
- **Format:** chunks served as WAV (Kokoro native, 24 kHz mono 16-bit) — fine on LAN;
  gapless-concatenation-safe. Final artifact remains mp3 192k.
- Existing surface reused unchanged: create (scratch channel), status/progress fields,
  final FilePath, delete.
- Deferred to v2: channel-less ephemeral job endpoint w/ TTL.

## Quality bar

- ≥90 % coverage on non-generated Dart code; Recordings API + SSE mocked with a local
  fake HTTP server in tests (including out-of-order chunk arrival and mid-stream failure);
  backend R1–R3 tested in the Recordings repo to its existing standards; drift DB tested
  in-memory; IPC singleton tested with two real processes; golden tests for key widgets.
- UI verified visually via desktop control + screenshots against the design-system notes.
- Milestones (each lands green): **R (Recordings repo)** chunk publication + gating + SSE
  · M1 toolchain+scaffold · M2 core (DB, API client, SSE consumer, job worker) ·
  M3 MCP+CLI+singleton · M4 UI+tray+styling+gapless player · M5 notifications, retention,
  e2e, coverage gate. R precedes M2; M1 can run in parallel with R.

## Machine prerequisites (missing today)

- Flutter SDK; `clang cmake ninja-build pkg-config libgtk-3-dev` (linux desktop build)
- `libmpv` (playback via media_kit)
- ~~ffmpeg~~ not needed anymore (server-side)

## Decisions log

- Generation offloaded to Recordings backend; app is a thin client with local SQLite
  as source of truth (transcript stored before submit, mp3 downloaded on completion,
  server copy deleted after).
- Auth: X-Api-Key (no OAuth in v1).
- No server-side channel clutter: hidden `_read-aloud` scratch channel + delete-after-
  download; channel-less job endpoint deferred to v2.
- **Progressive playback is in scope for v1** via backend chunk publication + in-order
  gating + SSE (R1–R3) — fixes the time-to-first-audio caveat while keeping generation
  server-side.
- Local format mp3 192k (server default); retention: keep everything until cleared.
- **Playback device selection is required**: enumerate output devices via mpv/media_kit,
  dropdown in config, applied live to the player, persisted (`audioDevice`, default auto).

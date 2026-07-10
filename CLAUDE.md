# read-aloud-ui

Flutter desktop app (linux primary, mac/windows buildable): a thin read-aloud client for
the DonkeyWork-Recordings backend. Text arrives via MCP stdio / CLI, generation happens
server-side (Kokoro TTS), audio streams back progressively (SSE chunk events) and the
final mp3 is downloaded into a local library. Full spec: `docs/spec.md`.

## Layout

- `app/` — the Flutter project (all Dart code lives here)
  - `lib/src/core/` — pure-Dart domain: db (drift), api client, sse consumer, job worker,
    ipc singleton, mcp server. NO Flutter imports here (keeps it unit-testable + reusable
    by the CLI entrypoint).
  - `lib/src/ui/` — widgets, theme (DonkeyWork design system), screens.
  - `bin/read_aloud_cli.dart` — CLI mirroring the MCP tool surface.
  - `test/` — mirrors lib/src; fake Recordings server in `test/support/fake_server.dart`.
- `.github/workflows/` — CI (analyze+test on PR) and release (linux+mac artifacts,
  version bump on merge to main).

## Commands (run from `app/`)

- `flutter analyze` — must be clean
- `flutter test --coverage` — coverage gate ≥90% of non-generated lib/src/core + lib/src/ui logic
- `dart run build_runner build --delete-conflicting-outputs` — regen drift code
- `flutter build linux --release` — desktop build
- Run locally: `flutter run -d linux` (X11 display :0 available; screenshot via `scrot`)

## Conventions

- Flutter SDK at `~/development/flutter/bin` (3.44.x stable); add to PATH.
- Generated files (`*.g.dart`, `*.drift.dart`) are committed and excluded from coverage.
- Backend contract (fixed, negotiated with DonkeyWork-Recordings): SSE events
  `chunk-ready {index,url,playableUpTo}`, `progress {progress,statusDetail}`,
  `ready {url}`, `failed {error}`; recording GET carries `chunks[]` + `playableUpTo`
  as poll fallback. Auth: `X-Api-Key` header everywhere, including chunk/final URLs.
- Local DB is source of truth: transcript stored before submit; server copy deleted
  after the final mp3 download succeeds.
- UI must follow the DonkeyWork design system (dark + light) — tokens in
  `lib/src/ui/theme/`; reference values in docs/spec.md §Styling sources.

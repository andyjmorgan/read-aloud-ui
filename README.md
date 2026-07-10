# read-aloud-ui

A desktop read-aloud client for [DonkeyWork-Recordings](https://github.com/andyjmorgan/DonkeyWork-Recordings).
Send it text over **MCP stdio** or the **CLI** and it streams back speech within
seconds — chunks play live as the server (Kokoro TTS) renders them, and the
finished mp3 lands in a local library. Flutter desktop, linux + macOS.

![status](https://github.com/andyjmorgan/read-aloud-ui/actions/workflows/ci.yml/badge.svg)

## Install

Linux x64 / macOS, no root:

```bash
curl -fsSL https://raw.githubusercontent.com/andyjmorgan/read-aloud-ui/main/scripts/install.sh | bash
```

This pulls the [latest release](https://github.com/andyjmorgan/read-aloud-ui/releases/latest),
installs to `~/.local/opt/read-aloud` (or `~/Applications` on macOS), adds a
launcher entry + `read-aloud` CLI symlink. Or grab the artifacts from the
[releases page](https://github.com/andyjmorgan/read-aloud-ui/releases) manually.

First run: open **Settings** and paste your Recordings API key
(web app → Profile → API Keys). Pick a voice and output device while you're there.

## Use

**MCP** (Claude Code):

```bash
claude mcp add read-aloud -- ~/.local/opt/read-aloud/read_aloud_ui --mcp
```

One tool: `read_aloud(name, paragraphs[], voice?, speed?)` — returns a job id
immediately; audio starts playing as the first chunk renders. If the app is
already running, a second `--mcp` invocation bridges to it transparently.

**CLI**:

```bash
read-aloud speak --name "morning brief" "First paragraph." "Second paragraph."
echo "long text" | read-aloud speak --name "piped" --stdin
read-aloud list
```

## How it works

```
MCP stdio / CLI ─► singleton app ─► local SQLite (transcript first)
                       │ POST generate (X-Api-Key, scratch channel)
                       ▼
             DonkeyWork-Recordings ── Kokoro TTS ─┬─ chunk WAVs via SSE (live playback)
                       │                          └─ final mp3
                       ▼
       download mp3 → local library → delete server copy → notify
```

The app is a singleton (unix socket): closing the window keeps it serving in
the background; launching it again re-opens the window. The local library is
the source of truth — the server copy is deleted once the mp3 is downloaded.

## Development

```bash
cd app
flutter pub get
flutter test --coverage && dart run tool/coverage_gate.dart   # gate: ≥90 % on lib/src
flutter build linux --release
python3 tool/patch_media_kit_print.py build/linux/x64/release/bundle  # MCP stdout purity
```

CI runs analyze + tests + the coverage gate on every PR; merging to `main`
builds linux + macOS artifacts, bumps the patch version and publishes a
GitHub release. Full design: [docs/spec.md](docs/spec.md).

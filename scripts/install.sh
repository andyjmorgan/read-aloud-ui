#!/usr/bin/env bash
# read-aloud-ui installer: downloads the latest GitHub release and installs it
# for the current user (no root). Linux x64 and macOS.
#
#   curl -fsSL https://raw.githubusercontent.com/andyjmorgan/read-aloud-ui/main/scripts/install.sh | bash
set -euo pipefail

REPO="andyjmorgan/read-aloud-ui"
API="https://api.github.com/repos/$REPO/releases/latest"

case "$(uname -s)" in
  Linux)
    PATTERN="linux-x64.tar.gz"
    ;;
  Darwin)
    PATTERN="macos.zip"
    ;;
  *)
    echo "unsupported OS: $(uname -s)" >&2; exit 1
    ;;
esac

echo "==> resolving latest release…"
URL=$(curl -fsSL "$API" | grep -o "\"browser_download_url\": *\"[^\"]*$PATTERN\"" | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')
TAG=$(curl -fsSL "$API" | grep -m1 '"tag_name"' | sed 's/.*"\(v[^"]*\)".*/\1/')
[ -n "$URL" ] || { echo "no $PATTERN asset found on the latest release" >&2; exit 1; }
echo "==> $TAG ($URL)"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl -fsSL "$URL" -o "$TMP/pkg"

if [ "$(uname -s)" = "Darwin" ]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
  unzip -oq "$TMP/pkg" -d "$DEST"
  echo "==> installed to $DEST/read_aloud_ui.app"
  echo "    (unsigned build: right-click → Open on first launch)"
  BIN="$DEST/read_aloud_ui.app/Contents/MacOS/read_aloud_ui"
else
  DEST="$HOME/.local/opt/read-aloud"
  rm -rf "$DEST" && mkdir -p "$DEST"
  tar xzf "$TMP/pkg" -C "$DEST"
  mkdir -p "$HOME/.local/bin"
  ln -sf "$DEST/read_aloud_ui" "$HOME/.local/bin/read-aloud"
  # desktop entry + icon (dock/launcher integration)
  mkdir -p "$HOME/.local/share/applications" "$HOME/.local/share/icons/hicolor/256x256/apps"
  cp "$DEST/read-aloud.png" "$HOME/.local/share/icons/hicolor/256x256/apps/read-aloud.png"
  sed "s|^Exec=.*|Exec=$DEST/read_aloud_ui|" "$DEST/read-aloud.desktop" \
    > "$HOME/.local/share/applications/read-aloud.desktop"
  command -v update-desktop-database >/dev/null && update-desktop-database "$HOME/.local/share/applications" || true
  command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
  echo "==> installed $TAG to $DEST (launcher: 'Read Aloud', CLI: read-aloud)"
  BIN="$DEST/read_aloud_ui"
fi

cat <<EOF

Next steps:
  1. Launch the app and set your Recordings API key in Settings.
  2. Register the MCP server with your agent, e.g.:
       claude mcp add read-aloud -- "$BIN" --mcp
  3. Speak from the CLI:
       read-aloud speak --name "hello" "This is read aloud."
EOF

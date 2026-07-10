#!/usr/bin/env python3
"""Silence media_kit_libs_* native registrar printf that pollutes stdout.

MCP stdio requires a clean protocol channel, but media_kit's plugin registrar
printf()s a banner before Dart main() runs. This patches the built bundle:
the format string's first byte becomes NUL, so printf emits nothing. Same
length, no relocation impact.

Usage: patch_media_kit_print.py <bundle-or-app-dir>
"""
import sys
from pathlib import Path

NEEDLES = [
    b"package:media_kit_libs_linux registered.",
    b"package:media_kit_libs_macos registered.",
    b"package:media_kit_libs_windows registered.",
]

def patch_file(path: Path) -> bool:
    data = path.read_bytes()
    patched = False
    for needle in NEEDLES:
        idx = data.find(needle)
        while idx != -1:
            data = data[:idx] + b"\x00" + data[idx + 1:]
            patched = True
            idx = data.find(needle, idx + 1)
    if patched:
        path.write_bytes(data)
    return patched

def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    hits = 0
    for path in root.rglob("*"):
        if not path.is_file() or path.stat().st_size < 1024:
            continue
        if path.suffix in {".png", ".json", ".otf", ".ttf", ".frag", ".mp3", ".wav"}:
            continue
        try:
            if patch_file(path):
                print(f"patched: {path}")
                hits += 1
        except (PermissionError, OSError):
            continue
    print(f"{hits} file(s) patched")
    return 0

if __name__ == "__main__":
    sys.exit(main())

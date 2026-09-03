#!/usr/bin/env bash
# blender/run.sh <script.py> [args...] — run a generator headless with the pinned Blender.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLENDER="$ROOT/toolchain/blender/blender"
[ -x "$BLENDER" ] || { echo "blender not installed: run ./bootstrap.sh" >&2; exit 2; }
script="$1"; shift
export PYTHONPATH="$ROOT/blender:${PYTHONPATH:-}"
exec "$BLENDER" -b -noaudio --python-exit-code 1 -P "$ROOT/$script" -- "$@"

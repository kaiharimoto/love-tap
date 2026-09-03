#!/usr/bin/env bash
# blender/run.sh <script.py> [args...] — run a generator headless with the pinned Blender.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLENDER="$ROOT/toolchain/blender/blender"
[ -x "$BLENDER" ] || { echo "blender not installed: run ./bootstrap.sh" >&2; exit 2; }
script="$1"; shift
export PYTHONPATH="$ROOT/blender:${PYTHONPATH:-}"
# BLENDER_THREADS caps the render threads so several generators can share the machine
THREADS_ARG=()
[ -n "${BLENDER_THREADS:-}" ] && THREADS_ARG=(-t "$BLENDER_THREADS")
exec "$BLENDER" -b -noaudio "${THREADS_ARG[@]}" --python-exit-code 1 -P "$ROOT/$script" -- "$@"

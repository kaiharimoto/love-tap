# INVENTORY

Component families, sources, status, substitutions. Status: `planned` · `building` · `built` · `verified`.

## Toolchain (installed by `bootstrap.sh` into `./toolchain/`, gitignored)

| Tool | Pin | Source | Status | Substitution |
|---|---|---|---|---|
| Flutter | 3.47.2 stable (Dart 3.13.2) | storage.googleapis.com/flutter_infra_release | building | — |
| Android cmdline-tools | 16111833 | dl.google.com | building | — |
| Android platform / build-tools | android-36 / 36.0.0 | dl.google.com | building | — |
| System image + AVD | android-34 aosp_atd x86_64, `lovetap` 1440×3120 | dl.google.com | building | software emulation (`-no-accel`), no KVM here |
| Blender | 4.5.13 LTS | download.blender.org | building | CPU Cycles, headless |
| ffmpeg | release static (johnvansickle) | johnvansickle.com | building | — |
| tailscaled / tailscale | 1.102.3 | pkgs.tailscale.com | building | userspace networking, two state dirs |
| Playwright + WebKit | 1.62.1 | registry.npmjs.org / playwright CDN | building | — |
| Python image/font libs | numpy, pillow, fonttools, scipy, scikit-image, opencv-headless | pypi | built | — |

## Code families

| Family | Location | Status |
|---|---|---|
| Transport interface (Host/Client, cursor sync, outbox, pairing auth, blobs) | `app/lib/transport/` | planned |
| Local transport with injectable faults | `app/lib/transport/local/` | planned |
| Tailscale transport | `app/lib/transport/tailscale/` | planned (final phase) |
| Spine (drift/sqlite3, FTS5, blob store, replay, projections) | `app/lib/spine/` | planned |
| Event type registry (17 types) | `app/lib/spine/types.dart` | planned |
| Messenger (unstyled first) | `app/lib/regions/chat/` | planned |
| Feelings engine (33 built-ins, 6 families, authored) | `app/lib/feelings/` | planned |
| Partner-state signals (13) | `app/lib/state/` | planned |
| Ambient surfaces (widget, notifications, pocket pulse; PWA standing notification, push) | `app/lib/presence/`, `app/android/` | planned |
| Modules: dates, todos, calendar, rituals + registry | `app/lib/modules/` | planned |
| Moments, Settings, Pulse, Us | `app/lib/regions/` | planned |
| Setup checklists + HTTP bootstrap page | `app/lib/setup/` | planned |
| Voice string table + lint | `app/lib/voice/`, `tools/lint/strings.py` | planned |
| Web Push sender (RFC 8291, VAPID) | `app/lib/presence/webpush/` | planned |

## Material families (`assets/`, every file in `assets/MANIFEST.json`)

| Family | Count | Generator | Status |
|---|---:|---|---|
| Paper stocks (+ dusk) | 9 stocks / 21 sheets ×2 | `blender/paper/stocks.py` | planned |
| Tear masks | ≥48 distinct | `tools/tears/tear.py` + `blender/paper/tear_relief.py` | planned |
| Fold / crumple sequences | 4 sequences, 660 frames | `blender/folds/*.py` | planned |
| Handwriting faces | 3 faces × 5 variants/glyph | `tools/handwriting/build.py` | planned |
| Feeling objects + shadows | 33 + 33 | `blender/objects/*.py`, `tools/doodles/` | planned |
| Tape / staples / clips | ≥24 | `blender/bits/bits.py` | planned |
| Feeling sounds | 33 | `tools/sound/synth.py` | planned |
| Shell furniture (desk, tabs, strips) | ~12 | `blender/shell/` | planned |

## Seed (`seed/`)

| Item | Status |
|---|---|
| `people.json` (Noor, Teo, hands, devices, anchors) | planned |
| Year-deep events (months of messages, hundreds of feelings, photos, dates, to-dos) | planned |
| Photographs (rendered scenes, not downloads) | planned |

## Evidence (`evidence/`)

17 artifacts + SCORE.json, DIFF.json, reliability.json, frames.json, coldstart.json, crops/, critics/ — none yet.

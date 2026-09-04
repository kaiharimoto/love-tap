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
| Python image/font libs | numpy, pillow, fonttools, cffi, scikit-image, opencv-headless | pypi | built | Blender's own Python has numpy and nothing else, so the two image operations the paper scripts need are written out in `blender/rig/common.py` rather than pulled in |

## Code families

| Family | Location | Status |
|---|---|---|
| Transport interface (Host/Client, cursor sync, outbox, pairing auth, blobs) | `app/lib/transport/` | verified |
| Local transport with injectable faults | `app/lib/transport/local/` | verified (20 tests, `evidence/reliability.json`) |
| Tailscale transport | `app/lib/transport/tailscale/` | planned (final phase; needs TS_AUTHKEY) |
| Spine (sqlite3 / idb_shim, blob store, replay, projections) | `app/lib/spine/` | verified (boundary test: only `spine/store/` imports a driver) |
| Event type registry (17 types) | `app/lib/spine/types.dart` | verified against `docs/EVENT_TYPES.md` |
| Messenger, then material | `app/lib/regions/chat/` | built; chrome redrawn in the material language, no icon set |
| Feelings engine (34 built-ins, 6 families, authored) | `app/lib/feelings/` | verified (`app/test/floors_test.dart`) |
| Partner-state signals (14) | `app/lib/spine/projections/state.dart` | verified (6 declared, 8 passive) |
| Ambient surfaces (standing line, pocket, background delivery) | `app/lib/ambient/`, `app/android/`, `app/web/push/` | built; not yet exercised on a real phone |
| Modules: dates, todos, calendar, rituals + registry | `app/lib/modules/` | built (a fifth is a directory and one line) |
| Moments, Settings, Pulse, Us | `app/lib/regions/` | built |
| Setup checklists (observed, never claimed) | `app/lib/setup/` | built; the CA bootstrap page is not written yet |
| Voice string table + lint | `app/lib/voice/`, `tools/lint/strings.py` | built (106 displayed strings, 0 against the voice) |
| Web Push sender (RFC 8291, VAPID) | `tools/push/webpush.py` | verified against the RFC's own §5 vector |

## Material families (`assets/`, every file in `assets/MANIFEST.json`)

| Family | Count | Generator | Status |
|---|---:|---|---|
| Paper stocks (+ dusk) | 23 sheets | `blender/paper/stocks.py` | rendering |
| Tear masks, edge light, contact shadow | 139 masks, 41 lit | `tools/tears/tear.py` + `blender/paper/tear_relief.py` | masks verified distinct; relief rendering |
| Fold / crumple sequences | 1 of 4 started | `blender/folds/fold.py` | partly rendered; the app plays a sequence only once it is whole |
| Handwriting faces | 2 of 3 × 5 variants/glyph | `tools/handwriting/build.py` | verified (`tools/handwriting/check.py`: no glyph has lost a stroke) |
| Feeling objects + shadows | 22 rendered | `blender/objects/objects.py` | rendering |
| Tape / staples / clips | 0 rendered of 11 | `blender/bits/bits.py` | queued |
| Feeling sounds | 44 | `tools/sound/synth.py` | built |
| The desk itself (day and dusk) | 2 | `blender/shell/desk.py` | rendered |

## Seed (`seed/`)

| Item | Status |
|---|---|
| `people.json` (Noor, Teo, hands, devices, three anchors) | built |
| Year-deep events: 13 months, 14,099 events, 0 validator errors | built |
| Photographs, videos and voice notes: scenes written, renders not made yet | building |

## Evidence (`evidence/`)

17 artifacts + SCORE.json, DIFF.json, reliability.json, frames.json, coldstart.json, crops/, critics/ — none yet.

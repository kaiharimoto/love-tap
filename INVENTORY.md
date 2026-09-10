# INVENTORY

Component families, sources, status, substitutions. Status: `planned` · `building` · `built` · `verified`.

## Toolchain (installed by `bootstrap.sh` into `./toolchain/`, gitignored)

| Tool | Pin | Source | Status | Substitution |
|---|---|---|---|---|
| Flutter | 3.47.2 stable (Dart 3.13.2) | storage.googleapis.com/flutter_infra_release | building | — |
| Android cmdline-tools | 16111833 | dl.google.com | building | — |
| Android platform / build-tools | android-36 / 36.0.0 | dl.google.com | building | — |
| System image + AVD | android-34 aosp_atd x86_64, `lovetap` 1440×3120 | dl.google.com | building | software emulation (`-no-accel`), no KVM here |
| Android NDK | 28.2.13676358 (2.1 GB) | dl.google.com | built | needed: `sqlite3_flutter_libs` and the media plugins build native code, so an APK cannot be produced without it. Deleting it to free disk costs a 2.1 GB re-download on the next Android build. |
| Blender | 4.5.13 LTS | download.blender.org | building | CPU Cycles, headless |
| ffmpeg | release static (johnvansickle) | johnvansickle.com | building | — |
| tailscaled / tailscale | 1.102.3 | pkgs.tailscale.com | building | userspace networking, two state dirs |
| Playwright + WebKit | 1.62.1 | registry.npmjs.org / playwright CDN | building | — |
| Python image/font libs | numpy, pillow, fonttools, cffi, scikit-image, opencv-headless | pypi | built | Blender's own Python has numpy and nothing else, so the two image operations the paper scripts need are written out in `blender/rig/common.py` rather than pulled in |

## Code families

| Family | Location | Status |
|---|---|---|
| Transport interface (Host/Client, cursor sync, outbox, pairing auth, blobs) | `app/lib/transport/` | verified |
| Local transport with injectable faults | `app/lib/transport/local/` | verified (`evidence/reliability.json`). The replay window is spent on writes only: a browser retries an idempotent GET when the connection closes before the first response byte, and the twenty-second long poll was the one request held open long enough for that |
| Tailscale transport | `app/lib/transport/tailscale/` | planned (final phase; needs TS_AUTHKEY) |
| Spine (sqlite3 / idb_shim, blob store, replay, projections) | `app/lib/spine/` | verified (boundary test: only `spine/store/` imports a driver) |
| Event type registry (17 types) | `app/lib/spine/types.dart` | verified against `docs/EVENT_TYPES.md` |
| Messenger, then material | `app/lib/regions/chat/` | built; chrome redrawn in the material language, no icon set |
| Feelings engine (36 built-ins, 6 families, authored) | `app/lib/feelings/` | verified (`app/test/floors_test.dart`). On a phone with no vibrator each one knocks the desk in its own direction with its own tilt, recorded per feeling in `evidence/logs/haptics.json` |
| Partner-state signals (14) | `app/lib/spine/projections/state.dart` | verified (6 declared, 8 passive) |
| Ambient surfaces (standing line, pocket, background delivery) | `app/lib/ambient/`, `app/android/`, `app/web/push/` | built; not yet exercised on a real phone |
| Modules: dates, todos, calendar, rituals + registry | `app/lib/modules/` | built (a fifth is a directory and one line) |
| Moments, Settings, Pulse, Us | `app/lib/regions/` | built |
| Setup checklists (observed, never claimed) | `app/lib/setup/` | built; the CA bootstrap page is not written yet |
| Voice string table + lint | `app/lib/voice/`, `tools/lint/strings.py` | built (525 displayed strings read against 8 rules, 0 against the voice). It reads every literal in a line of code that could reach a screen, not a fixed list of call sites |
| Web Push sender (RFC 8291, VAPID) | `tools/push/webpush.py` | verified against the RFC's own §5 vector |

## Material families (`assets/`, every file in `assets/MANIFEST.json`)

| Family | Count | Generator | Status |
|---|---:|---|---|
| Paper stocks (+ dusk) | 27 sheets, 54 files | `blender/paper/stocks.py` | rendered at the density a piece draws them: A5 1574x2200, index 2560x1593, receipt 1601x3420, stickies 1800x1800. A full-width piece is 1,356 device pixels across, so a 1,288-wide stock had to be enlarged and a resample only ever smooths |
| Tear masks, edge light, contact shadow | 56 masks, all with edge and shadow | `tools/tears/tear.py` + `blender/paper/tear_relief.py` | verified distinct (`tools/tears/distinct.py`). **Measured and not fixed:** 28 of the 56 have a contour under 2 px rms (`evidence/logs/torn.json`) — the fracture's Hurst exponent runs to 1.15 and 1.15 is a clean pull |
| Fold / crumple sequences | 1 of 4 rendered (unfold_thirds, 240 frames at 600 px, 142 packed) | `blender/folds/fold.py` | verified: 142 frames, worst 3.079 and median 14.911 against a paper floor of 1.2, none below it. The flap bends about a 2.2 mm arc rather than hinging, so a panel carries a 56-64 grey-level ramp end to end with a 25-level crease step; the other three sequences are documented, not rendered |
| Handwriting faces | 3 of 3: NoorHand and TeoHand 360 variants each, DeskStamp 216 | `tools/handwriting/build.py` | verified (`tools/handwriting/check.py`): 0 broken, variants apart median 42.0 / 40.5 / 17.2. **Two glyphs under the floor:** NoorHand's `i` at 24.6 and `0` at 24.3 against 26.0 — both simple shapes, which the jitter field moves less in absolute units than it moves a complex one |
| Feeling objects + shadows | 31 objects, day and dusk, each with its own shadow | `blender/objects/objects.py` | rendered; no two feelings share an object (`app/test/floors_test.dart`). 62 surfaces read against a floor of 2.0 in `tools/check/surfaces.py`, none flat |
| Tape / staples / clips | 44 files | `blender/bits/bits.py` | rendered |
| Feeling sounds | 44 | `tools/sound/synth.py` | built; every feeling has its own and no two share one (`evidence/logs/haptics.json`) |
| The desk itself (day and dusk) | 2 | `blender/shell/desk.py` | rendered |

## Seed (`seed/`)

| Item | Status |
|---|---|
| `people.json` (Noor, Teo, hands, devices, three anchors) | built |
| Year-deep events: 13 months, 14,099 events, 0 validator errors | built |
| Photographs, videos and voice notes: scenes written, renders not made yet | building |

## Evidence (`evidence/`)

17 fixed artifacts (15 capturable here; 09 and 16 need an Android device, and the reason is measured rather than
asserted — no /dev/kvm and no vmx/svm flag, so the x86_64 image runs under QEMU's own instruction emulation; adbd
answered after 113 minutes and the framework never came up behind it) + SCORE.json, DIFF.json, reliability.json,
frames.json, coldstart.json, crops/, logs/ and critics/<cycle>/.

The instruments in `tools/check/`, each of which ships a control measured by its own code so a reader can see it has
something to catch:

| Check | What it gates on |
|---|---|
| `surfaces.py` | no rendered surface in the library is a flat fill, against a floor per family |
| `flat.py` | no pale window on the glass is flatter than the quietest stock in the library, halved |
| `holes.py` | nothing in the ring 3 to 12 px outside a sheet is darker than ink — a contact shadow out from under its paper |
| `hairline.py` | no pale one-pixel rule on the wood beside a piece |
| `grain.py` | the desk's fine-detail share, not its anisotropy: a pore adds across the grain as much as along it |
| `torn.py` | a cut edge does not repeat within itself, past the central lobe of its own correlation |
| `lines.py` | the same ruled stock is the same size everywhere, and the writing sits on the rules |
| `frames.py` | no frame of a clip is its predecessor; every clip keeps something moving |
| `hand.py`, `handwriting/check.py` | repeated glyphs are not the same glyph |
| `haptics.py` | every pattern is distinct, drawn to scale |
| `diff.py`, `manifest.py`, `recipes.py`, `reception.py` | the set against the last one, and every file naming what made it |

Cycle 9 scored 82 against an exit of 95; cycle 10 is this session's capture.

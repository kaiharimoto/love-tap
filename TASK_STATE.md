# TASK_STATE

Resumable state. Re-read `docs/BRIEF.md`, `DIRECTION.md` and this file first, then `docs/CONTINUE.md`
and continue from **Next action**.

## Session log

| Session | Date (UTC) | Reached | Score |
|---|---|---|---|
| 1 | 2026-09-03 | bootstrap; STEP 01 transport; STEP 02 spine; STEP 03 unstyled messenger + reliability report; sounds; paper-stock renderer started; seed year and handwriting delegated | 0 |
| 2 | 2026-09-03 | tears, fonts, objects, seed year on disk; STEP 06 material on shell and Chat; STEP 07 feelings and signals; STEP 08 four modules; Moments and Settings | 0 |
| 3 | 2026-09-04 | capture handles, `run.sh` and `capture.sh`, the scene driver and checks; Chat chrome in the material language; the fold player; setup checklists; the six critic prompts; first evidence pass | cycle 1: 40 |
| 4 | 2026-09-04 | photograph pipeline fixed at the source; the unfolding clip fixed at four causes; every screen given a test; modal surfaces rebuilt as paper; second capture; six critics | cycle 2: 55.5, no floor met |
| 5 | 2026-09-05 | fresh clone re-bootstrapped; the nineteen root causes behind cycle 2 fixed (below); fold sequence re-rendered; both hands rebuilt; eight objects replaced; paired year-deep capture; third capture and six critics | cycle 3: see `evidence/SCORE.json` |

## Current position

- phase: review (cycle 3 captured and scored this session; cycle 4 remains)
- branch: `claude/new-session-f95s8n` (all work of session 5; pushed)
- transport in use: local (`app/lib/transport/local/`), named in every report. The tailnet
  transport exists (`app/lib/transport/tailscale/`) and its checks are recorded **pending**: no
  `TS_AUTHKEY` was in this session's environment, `toolchain/ts/AUTHKEY_STATUS` says `pending`,
  and the question was already asked in the session the phase began, so it is not asked again.
- Android: no `/dev/kvm`, so `09_two_devices.png` and `16_setup_android.png` stay missing with the
  measured reason in `docs/PHONES.md`. Nothing stands in for them.
- fourth-module commit hash: 7dfeca2 (`STEP 07-08`); `git show --stat 7dfeca2` touches only
  `app/lib/modules/rituals/`, the registry line, and files outside `modules/`.

## What cycle 2 said, and what was done about each

| finding (critic's measurement) | done |
|---|---|
| 06: 281 of 320 frames a flat cream rectangle, interior L-σ under the paper floor | `blender/folds/fold.py` re-rendered at 600 px with tooth, fibre and mottle at the frame's own density and a crease ridge; `tools/check/surfaces.py` now reads `folds/` (every frame ≥ 1.2, worst 2.1); the fold plays one frame per 16 ms step |
| 06 ends on blank paper, then a light pop | the ink fades in over the last part of the sequence on the same clock; the folded sheet carries the name it is for on the outside |
| four families visible of six; names at 1.95:1; translucent drawer | the vocabulary is on an opaque torn sheet; all six families as cards; names in pencil on paper; a widget test opens the corner and reads all of it |
| 07 "contains no landing"; the recent row unchanged | 07 is shot on the receiving phone, the far phone sends at a known frame; the object rests while the pattern plays through the paper, then is put away into the recent row, which lands newest first |
| no haptic evidence; the PWA substitute reads as absence | one `Sensation` on the scope reports what it played; `__deskHaptics` dumps every pattern; `tools/check/haptics.py` draws `evidence/crops/haptics_strip.png`; a capture-mode lane draws the pattern to scale on 07/15; 07 and 15 carry the feeling's own sound; Settings and the PWA setup sheet say what stands in for the buzz |
| 04: five "still fetching" rows, no thumbnail | Moments is a viewport-bound pile (a sliver with its own layout); blob reads are limited to six in flight; thumbnails decode at tile size; a placeholder is a blank print, not a sentence |
| every seeded still unpaired, `connecting`; 08 on an 8-event fixture | the far phone (`app/tool/host_daemon.dart`) carries the same seeded year, so pairing costs no pull; every seeded scene pairs and is `connected` |
| typing has no evidence | `typing` capability in `reliability_test.dart`; 13 shows the far phone typing (frames repeated every 3 s while on) |
| 13 missing | the staged states go through the real outbox and a real read marker from the far phone; 13 present |
| search order random, hits without a reason, chips clipped, no shell chrome | newest first; a hit says where the words were found; facet tabs have room; search sits in the thread's place inside the Chat region with the shell around it |
| viewer shows composer and tabs; caption twice | the viewer covers the desk (opaque, its own desk) |
| glyphs pixel-identical (IoU 0.998) | both hands rebuilt with the jitter raised, `calt` as two explicit lookups, variants ≥ 26 units apart; `tools/check/hand.py` measures the twin share on the hero (0.39 on the cycle-2 still) |
| tab tiles and cards edge-σ 0, no shadow; slabs | tabs are cut `Slip` cards with an edge and a contact shadow; every `torn: false` piece has a cut edge and shadow and shows its stock at the stock's own density; the tap pad is a slip of graph paper |
| reports identical across regions | `report()` carries a per-region view plus the sensation and the ambient surfaces |
| emoji vocabulary; reward tokens | sun, moon, tongue face, rain, firework, gold star and crown are gone; bookmark, dog-ear, wrapper, pencil smudge, bunting, cork, paper hat and a soup take their places; no two feelings share an object (test) |
| DIFF compared each artifact with itself | `collect.py` no longer rewrites DIFF.json or the baseline; `diff.py --rotate` owns both |
| critics contaminated and mis-timed | BRIEFING and prompts: clips are app time at the recorded step; SCORE.json and earlier reports are moved out while the critics run |
| cold start 12–16 s on every scene | one kept browser profile per capture, so the year imports once; the seed import skips the per-row lookup into an empty store; the log says whether a load was a first launch |

Still open from cycle 2: distinct renderers for the module types and one surface per event class
across Chat, Moments and Us (row 15); the DeskStamp face (building at session end; the tabs use
TeoHand until it lands); the within-stroke ink density plate.

## What exists (verified)

- `./bootstrap.sh` installs the pinned toolchain into `./toolchain` (Flutter 3.47.2, Android SDK,
  Blender 4.5.13, ffmpeg 7.0.2, tailscale 1.102.3, Playwright 1.62.1 WebKit 26.5). On a fresh
  machine it also needs `tools/apt-prereqs.sh` plus `libevent-2.1-7t64 libwayland-server0` before
  WebKit launches; bootstrap's python check named the module `skia_pathops` and now names `pathops`.
- `cd app && flutter analyze && flutter test`: 94 tests pass.
- `python3 tools/check/surfaces.py`, `manifest.py`, `recipes.py`, `tools/lint/strings.py`,
  `tools/handwriting/check.py` pass; `capture.sh` runs them before the builds.
- `app/tool/host_daemon.dart --seed year`: the far phone with the whole year, taking `message`,
  `feeling`, `state`, `read`, `typing on|off`, `pair` and `stop` on its control file.

## Known failures / risks

- The container restarted once mid-session and every background process died with it (a fold
  render at frame 209, a font build at glyph 76). Long renders are resumable (`fold.py --start`),
  font faces build one at a time (`--faces`), and the fonts manifest carries the other faces
  forward.
- The DeskStamp face builds slowly (about a minute a glyph, slower as it goes); it was not done
  when this state was written. `app/pubspec.yaml` points DeskStamp at TeoHand until it is.
- A screenshot can race the compositor under load; `scene.js` waits two animation frames after
  each clock step before grabbing.

## Worst problems (ranked)

1. Two of the seventeen artifacts need an Android device this container cannot boot.
2. The tailnet run is pending for want of a key, so every reliability report says `local`.
3. Module rows share the thread's renderers: a date, a to-do and a calendar card are not yet
   their own kinds of paper.
4. DeskStamp is not built; the stamped furniture is set in TeoHand.

## Next action

Read `evidence/SCORE.json` for cycle 3 and `evidence/critics/3/*.json`; fix what they name that
cycle 2 did not; then the fourth capture and the fourth set of critics. The exit is 95 with every
floor met; regressions against cycle 3 are read off `evidence/DIFF.json`.

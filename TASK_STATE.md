# TASK_STATE

Resumable state. Re-read `docs/BRIEF.md`, `DIRECTION.md` and this file first, then open the latest
checkpoint under `checkpoints/` and continue from **Next action**.

## Session log

| Session | Date (UTC) | Reached | Score |
|---|---|---|---|
| 1 | 2026-09-03 | bootstrap; STEP 01 transport; STEP 02 spine; STEP 03 unstyled messenger + reliability report; sounds; paper-stock renderer started; seed year and handwriting delegated (in flight) | 0 |
| 2 | 2026-09-03 | tears, fonts, objects, seed year on disk; STEP 06 material on shell and Chat; STEP 07 feelings and signals; STEP 08 four modules; Moments and Settings | 0 |
| 3 | 2026-09-04 | capture handles wired into the app; `run.sh` and `capture.sh`; the scene driver, frame/tear/SSIM/crop checks and the string lint; Chat chrome redrawn in the material language (no icon set anywhere in Chat); tear assignment made collision-free by construction; the fold player and folded unread notes; `app/lib/setup/` checklists; the six critic prompts; first evidence pass | see evidence/SCORE.json |
| 4 | 2026-09-04 | the photograph pipeline found to be producing black frames and empty fields and fixed at the source; the unfolding clip found to be 240 identical frames and fixed at four separate causes; every screen given a test that builds it; the seeded year measured as 251 lines short and the reason named; three layout overflows and one out-of-range opacity found by those tests; six flat modal surfaces rebuilt as paper; the tab strip given five different pieces of card | see evidence/SCORE.json (cycle 1: 40) |

## Current position

- phase: build
- step: STEP 05 finishing — the render queue (`tools/render_queue3.sh`) is exposing the 115
  photographs, then the 14 videos, then the dusk half of the paper library, then the fold sequence
  to its full 240 frames. STEP 10's harness is complete and the second capture pass waits on the
  photographs: 129 missing renders were taking 122 read markers, reactions and replies down with
  them, which is why the thread came back text only.
- review cycle: 1 done (40/100, every floor missed); 2 waits on the second capture pass
- rubric score: 40 — see `evidence/SCORE.json`

### What cycle 1 said, and where each of it stands

| finding | state |
|---|---|
| a heart used as the token for a feeling | `obj_pinch` is a strip of paper pinched between finger and thumb; rendered |
| the setup screen was one flat fill with no paper | root cause found and fixed; measured again at 2.85M of 4.49M pixels above L=140, 19,570 colours |
| the action sheet was one flat rectangle at L=235 | six modal surfaces rebuilt as torn paper; three tests hold the line |
| the five tab cards were five stamps of one swatch | five windows onto the sheet at its own pixel density; highest correlation between any two now 0.59, was 0.991–1.000 |
| the media viewer, the states frame and search proved nothing | rebuilt; waiting on the photographs to be re-captured |
| no fold or crease anywhere; the unfolding clip was a still | four causes found and fixed; the clip is 8% repeated frames, was 100% |
| there is no dusk half of the library | queued behind the photographs |
| a feeling did not land, it cut in | `app/lib/feelings/landing.dart`: real ballistics, and the page moves with the haptic amplitude |
| Moments was empty | it opens on the first view with something in it; a test holds it |
- transport in use: local (`app/lib/transport/local/`), named in every report; tailscale not built
- fourth-module commit hash: 7dfeca2 (`STEP 07-08`); `git show --stat 7dfeca2` touches only
  `app/lib/modules/rituals/`, the registry line, and files outside `modules/`
- WebKit texture budget: measured rather than guessed. A hundred and fifty fold frames at
  460x405 RGBA is 112 MB decoded, which is more than WebKit will hold for one animation on a
  phone, so `FoldFrames` never holds the sequence: a window of 36 frames rides the playhead
  (27 MB) with 24 decoded ahead of it, and frames well behind are dropped. A frame that has not
  arrived yet holds the last one drawn rather than blinking out.
- TS_AUTHKEY: not needed yet (ask only when the Tailscale phase begins)

## What exists (verified)

- `./bootstrap.sh` installs the pinned toolchain into `./toolchain` (Flutter 3.47.2, Android SDK 36 +
  AVD `lovetap` 1440×3120 on android-34 aosp_atd, Blender 4.5.13, ffmpeg 7.0.2 static, tailscale
  1.102.3, Playwright 1.62.1 WebKit 26.5). Run once here in 14 minutes.
- `app/`: Flutter project (`desk`, org io.lovetap, android + web). `flutter analyze` clean.
- `flutter test` (app/): 21 tests pass — persistence boundary, schema vs docs/EVENT_TYPES.md,
  spine replay/search, local transport (restart, offline mid-send, killed send, long gap, host
  offline, blobs, ephemeral), reliability report.
- `evidence/reliability.json`: transport `local`, 16 capabilities ok, 0 duplicates, same order both sides.
- `assets/sound/`: 44 synthesised paper sounds (34 feelings, 2 authored, 8 UI) + MANIFEST entries.
- Docs: EVENT_TYPES (17 types), FEELINGS (34 in 6 families), SIGNALS (14), VOICE, seed FORMAT/STYLE/people.

## In flight (background, may need re-running after a rate limit)

- Seed year workflow (13 months, two authors at a time): writes `seed/year/<month>.jsonl` and the
  three index files per month; validator `python3 seed/tools/validate.py`. If it died, re-launch the
  same workflow; authors skip months that already validate.
- Handwriting font builder agent: `tools/handwriting/` → `assets/fonts/{NoorHand,TeoHand,DeskStamp}.ttf`.
- `flutter build apk --debug` and `flutter build web --release` of the messenger (logs in scratchpad).

## Last successful commands

```
./bootstrap.sh
cd app && flutter pub get && flutter analyze && flutter test
python3 tools/sound/synth.py --out assets/sound
python3 seed/tools/validate.py
bash blender/run.sh blender/paper/stocks.py -- --stock lined --variant 1 --res 700 --samples 32 --out <dir>
```

## Known failures / risks

- A session rate limit killed all background agents once (13:36 UTC); relaunched fewer at a time.
- No KVM: the AVD must run with `-no-accel`; not yet booted in this session.
- Blender's bundled Python has no Pillow: rules images are generated by the system python3 (handled in stocks.py).
- `record` on the web needs a user gesture and HTTPS/localhost; voice notes untested in WebKit yet.

## Worst problems (ranked)

1. **Twenty-three of the thirty-four feelings have no object**, so two thirds of the vocabulary
   renders as its own name in text. That is precisely what the emotional layer is meant not to be,
   and it shows in 02, 07, 13 and 15. The objects batch is rendering; it is first in the queue.
2. **The seed's media do not exist.** A hundred and eighty photographs, videos and voice notes are
   referenced and none are rendered, so the loader drops every one: Moments is empty, the hero has
   no pictures in it, and 14_media_viewer has nothing to open. `blender/photos/` is the pipeline
   for this and it works end to end at nine seconds a photograph, but nothing it has produced yet
   is good enough to put in the thread, so nothing it has produced is in the thread.
3. **The Tailscale transport does not exist.** Every report says `local`, which is true and is not
   the proof the mission asks for. It needs `TS_AUTHKEY`, and the brief says to ask only in the
   session that phase begins.
4. **Three artifacts need the Android phone**: `09_two_devices.png` needs both screens in one frame
   off one display, `16_setup_android.png` needs a fresh install on it, `08_state_propagating.mp4`
   needs both phones at once. No KVM here, so each emulator boot costs about ten minutes of the
   same four cores the renders want, and the container has restarted under it twice.
5. **`06_unfolding.mp4` has nothing in it** until the fold sequence is rendered. The app plays a
   sequence only when it is whole, which is right; the frames are queued behind the objects.
6. **`05_settings.png` cannot show two paired devices** with only one phone up: the host is the
   Android app, and a web build cannot be a host. It captures the unpaired state honestly instead.
7. No critic has run. The rubric score is unknown rather than low.

## What was fixed this session

Most of it was found by capturing and looking, which is what capturing every session is for.

- Contact shadows and edge light exist at all. They were rendering to nothing (no scipy in
  Blender's Python), and then the pass produced a slab rather than a shadow until the sheet was
  modelled as touching in the middle and curling at its torn edges.
- No two tears can repeat on one screen, by construction rather than by luck.
- Two glyph variants had lost strokes: the font builder was dropping ink when skia refused a union.
- The seeded year is complete, clean, and now runs up to the frozen now rather than stopping two
  days short of it, so Pulse has a day of traffic to show.
- Four thousand passive signals were being written into the thread as `battery 100` and
  `network cell`. docs/EVENT_TYPES.md always said one mark per meaningful transition per hour; the
  projection now does that, and says it in sentences.
- Every surface outside the thread was a beige rounded rectangle — the named anti-goal, the one
  that costs the build twice. All four modules, both Settings panels, the Us tabs and every empty
  surface are on real paper now, through `app/lib/material/slip.dart`.
- Nothing counts: the unread number on the chat tab is a folded corner.
- The clip of a feeling arriving had nothing in it, for two separate reasons — the scene named a
  feeling that does not exist, and the handle awaited the whole animation before the frames began.
- `capture.sh` could not start its second server: a background job inside `$(...)` holds the
  substitution's pipe open, so reading a pid that way blocks for ever.

## Next action

Re-capture the whole evidence set against the tear relief and the desk (`./capture.sh`), read the
hero at 300 percent, then run the six critics against what comes out and write `evidence/SCORE.json`
from the lower of each critic's score and the builder's. After that: the remaining fold frames, the
seed's media renders, and then the Tailscale phase, which is the session to ask for `TS_AUTHKEY`.

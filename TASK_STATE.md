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
| 5 | 2026-09-05/06 | fresh clone re-bootstrapped; the nineteen root causes behind cycle 2 fixed (below); fold sequence re-rendered; both hands rebuilt; eight objects replaced; paired year-deep capture with every clip distinct frame by frame; cycle 3 critics and score; the first eleven cycle-3 findings fixed | **cycle 3: 64**, no floor met |
| 6 | 2026-09-06 | the fold camera and the flap direction; the cascade step; the ink plate; object and shadow packed in their own frames; the whole messenger grammar in a picture; one stock per event type; clips at their own frame rate; fourth capture; cycle 4 critics, completeness pass and score; four of its findings fixed | **cycle 4: 68**, no floor met |

## Current position

- phase: review (cycle 4 scored at **68/100**, up from 64; the brief asks for 95 with every floor met)
- rubric: messenger 17/30 (floor 26) · material 16/25 (22) · emotional 16/20 (17) · coherence
  11.5/15 (13) · anti-goal 7.5/10 (9). Every category is the lower of the critic's number and the
  builder's, and in all five this cycle the critic's was lower. `evidence/SCORE.json` has the
  arithmetic; `evidence/critics/4/` has the seven reports.
- **read `evidence/critics/4/completeness.json` before anything else.** It is the most useful
  document in the set. All six critics measured only inside the artifact each was pointed at, and
  it says so with numbers: it would move anti-goal to 5.5, material to 13 and coherence to 10.5,
  which is a regression rather than the rise the total shows. Four of its findings were fixed the
  same day (below); the rest are the work list.
- branch: `claude/new-session-f95s8n` (all work of sessions 5 and 6; pushed)
- transport in use: local (`app/lib/transport/local/`), named in every report. The tailnet
  transport exists (`app/lib/transport/tailscale/`) and `evidence/coldstart.json` records a real
  two-node run from the session that had a key; this session had none, `toolchain/ts/AUTHKEY_STATUS`
  says `pending`, and the question was already asked in the session the phase began, so it is not
  asked again.
- Android: no `/dev/kvm`, so `09_two_devices.png` and `16_setup_android.png` stay missing with the
  measured reason in `docs/PHONES.md`. The same missing screen also costs 08 its "both devices'
  screens in sequence" clause, which is written down there too. Nothing stands in for any of it.
- `toolchain/android-sdk/emulator` was deleted mid-session to keep a capture from running out of
  disk. It cannot boot here and `./bootstrap.sh` puts it back.

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

## What cycle 3 said, and what was done about it in the same session

Eleven of its findings were fixed after the reports landed and before this file was written. They
are **not** in the captured artifacts: the next capture is what shows them.

| finding | done |
|---|---|
| the capture-mode haptic lane sits over the composer and is still there in the last frame of three clips | it runs along the top of the frame and goes when the pattern goes |
| the note that just arrived is clipped by the composer for the whole final run | the thread lands on the spacer under it, as it does when it opens |
| events arriving from the other phone are intermittently dropped | the store's `stored_order` is a unique index and two overlapping writes allocated the same key; writes are serialized |
| reply, edit, attach, reaction, voice and video appear in no artifact | the states frame stages a real reaction and a real reply; the other four are still uncovered |
| eight presence lines in a row, two of them saying the same thing | a passive signal that repeats its own last word is not a transition and is not drawn |
| a one-second rebuild every time a note comes into view | a mask is composed at a height rounded to sixteen device pixels, so notes of similar height share one |
| the search's type filters run off the right edge | they wrap onto as many rows as it takes |
| the family cards read WARMT, ACH, SHELTE | a slip asked how wide it wants to be was answering for its child, not for the whole piece |
| "you is heads down", "you's phone is on normal" | you takes a plural verb, and the possessive is your |
| the setup sheet is one flat colour over half the screen | it was one piece of paper too tall for the canvas to draw its stock; it is a sheet per step |
| the persistence rule a double quote walks past | either quote, imports and exports, and the web's own storage library |
| the vocabulary sheet is translucent | it slides out from under the corner instead of fading up |
| feeling objects are untextured props | `simple_mat` gives them a fine mottle, a rough coat and a hair of relief: the candle measures 1.65 grey levels against 0.49 (re-rendering at the time of writing) |
| the diff baseline was rotated by every partial run, so every artifact compared with itself | only a whole capture rotates it; the cycle-2 baseline was restored and the diff re-measured: fourteen changed, one new, two absent |

## What cycle 4 said, and what was done about it the same day

| finding | done |
|---|---|
| one torn edge repeated twelve times down the search results, and the same event torn differently in two surfaces | a tear is chosen from the event's own id, never from the row it sits in; two tests |
| the feeling objects are pre-lit sprites: under the dusk light the paper shifts thirty to forty levels and warms, the object shifts eight and does not | the object pass was skipped at dusk in the generator. It is rendered under both lights now, stopped down to the same aperture as everything else at dusk, and the app draws the dusk one at dusk |
| the reply banner reads `answering state_declared` | a row without text has a sentence in the couple's own words; the registry id never reaches a person |
| the video renders as an empty strip of paper (three critics) | it renders at 480 px. What they measured was its top sliver: the anchor placed the window's *first* row and left the tall last row hanging under the composer. The anchor places the last row now. That one was the framing, not the app |

## What cycle 4 said that is still open

Ordered by what it would cost to close, not by how loud it is.

1. **The app's permanent chrome is the forbidden shape.** The SETTINGS tab slab has a top edge with
   a standard deviation of 0.00 px over 266 columns, an interior of 1.20 grey levels against 19-27
   for the note paper beside it, and a drop shadow — on ten of eleven stills, with a Us glance card
   at 708x163 the same. The tabs are already `Slip(torn: false, stock: 'index')`, so the window is
   not sampling the stock at a density that survives being 89 points wide. Measure before changing.
2. **Nothing in 02_chat.png casts a contact shadow.** With the tear ink excluded the desk's median
   luminance is 95.7-102.7 in every direction at every distance from 2 to 120 px: the notes are
   cut-outs on a photograph. The baked shadow exists (`blender/paper/tear_relief.py`) and something
   between it and the screen is losing it.
3. **The haptic channel is never exercised.** `sensation.channel` reads `page` in all fifteen
   reports. The row asks for a feeling identifiable by its pattern with the screen face down, and
   that needs a phone.
4. **Thirty per cent of frames cost 938-1651 ms to build** (243 of 809, median 1134 ms) while the
   rest cost 14 ms. The heavy ones cluster; the log says these are draw costs rather than a refresh
   rate. Worth finding: it is the difference between a thread that scrolls and one that stutters.
5. **Three of the five modules are never drawn** in 03_us.png, though the report lists all five with
   their event counts.
6. **DeskStamp is not built** — about five hours on one core here — so every tab, stamp and module
   label is set in Teo's handwriting, and `notifications.dart` has seventeen arms for eighteen types
   so `passed_on` falls through to a label made from its own id.
7. **12_search.report.json records no search at all**, and 17_setup_pwa.png — the only evidence for
   the installable-PWA half of the mission — was read by no critic.
8. **The seeded photographs are renders** and the darkest few read as renders.
9. **No two-device frame, no Android artifact**, and every transport line says `local`.

## Next action

Read `evidence/critics/4/completeness.json`, then take items 1 and 2 above: both are measured, both
are in the material and anti-goal rows that are furthest below their floors, and both are the same
kind of defect — a piece of paper that is not behaving like paper. Then capture again and run the
fifth cycle. The exit is 95 with every floor met; two artifacts and the tailnet run cannot be had in
this container, and `docs/CONTINUE.md` says what that costs.

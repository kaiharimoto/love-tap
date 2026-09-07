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
| 7 | 2026-09-06/07 | the contact shadow every piece of paper had been drawing invisibly for four cycles; the window density behind the tab strip; thirty-three objects under the desk lamp; the tear from the event's own sequence; five modules on the desk; fifth capture; cycle 5 critics, completeness pass and score; the blank letter found and fixed | **cycle 5: 69**, no floor met |

## Current position

- phase: review (cycle 5 scored at **69/100**, from 68, 64, 55.5, 40; the brief asks 95 with every
  floor met)
- rubric: messenger 19/30 (floor 26) · material 15/25 (22) · emotional 15/20 (17) · coherence 12/15
  (13) · anti-goal 8/10 (9).
- **Two floors were met by the critics and lost to the builder's own sheet.** The critics put
  coherence at 13 and anti-goal at 9.2 — at and above their floors for the first time in five
  cycles. My sheet, written before reading them, said 12 and 8, and the rule takes the lower. That
  is the mechanism working; it was not revised after the fact and it must not be next time either.
  What it means in practice: on those two rows the builder is now the binding constraint, so the
  next sheet should be written from measurements rather than from caution.
- **Read `evidence/critics/5/completeness.json` before anything else.** As in cycle 4 it is the
  most useful document in the set: it corrects material_truth for reading the arriving message in 06
  as "the composer card", shows anti_goal's photographic-paper proof failing to reproduce by a
  factor of eight, and names a stock measured at patch_std 9.4-10.3 in the library arriving on
  screen at 1.22 — the paper is being flattened between the asset and the glass, which is the
  single most valuable lead in the build.
- branch: `claude/new-session-f95s8n` (sessions 5-7; pushed)
- transport: local in every report; `evidence/coldstart.json` holds a real two-node tailnet run from
  the session that had a key. No `TS_AUTHKEY` here and the question may not be asked again.
- Android: no `/dev/kvm`. 09 and 16 stay missing, and 08 cannot show both devices' screens, all for
  the one reason measured in `docs/PHONES.md`.

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

## What cycle 5 said, and what was done about it the same day

| finding | done |
|---|---|
| the note arriving in 06 unfolds for four seconds and ends completely blank — minimum luminance 223, not one pixel below 150, no text, no timestamp, no author, no delivery mark (three critics; the completeness pass called it the build's worst messenger defect) | a Stack whose children are all positioned sizes to nothing under loose constraints, so the overlay carrying the name and the ink filled nothing. It is given a size now. **Committed and not captured** — see below |

## The one thing this session could not finish

The blank-letter fix is in the code and in none of the artifacts. Three attempts to re-capture 06
failed at the same place: the far phone sends its message (`host_daemon.log` shows three sends, the
scene's own re-says), the near phone stays `link: connected` and its event count rises by six, and
its thread never grows by one. The scene times out waiting for a row that the spine appears to have
taken.

What is known about it:

- It is not the persisted profile. `capture.sh` empties `$SCRATCH/profile_seeded` at the top of
  every run, partial ones included.
- It is not the app under normal conditions: the same code path captured 06, 07, 08 and 15 in the
  fifth capture an hour earlier.
- The near phone's sync report reads `rounds: 3, pushed: 3, refused: 0` over thirty seconds, which
  is very few rounds for that window and worth starting from.
- A full `./capture.sh` is the configuration that has always worked. A partial `--only` run against
  the far phone is the one that fails, and the difference between them is the place to look.

Whoever picks this up: capture 06 first, before anything else, and if a partial run fails again do a
whole one. The fix itself is one line and has a test.

## What cycle 5 said that is still open

Ordered by what it costs to close.

1. **The paper is being flattened between the library and the glass.** `logs/surfaces.json` puts the
   source stocks at patch_std 9.36-10.28; the completeness pass measures 1.22 arriving on screen,
   and under 1.5 across 3,656 ink-free patches on four stills. That is a factor of eight, in the
   category furthest below its floor, and it is one number to chase rather than a judgement to
   argue with.
2. **The light the shadows describe touches nothing else.** A note's interior swings 9-13 grey
   levels on 230 across its full width; the 'hold' cylinder reads 148 on one side of its curve and
   153 on the other while throwing a hard directional shadow; the fold's flap darkens 17 per cent
   while foreshortening 90. The shadows are baked and the surfaces they fall on are not.
3. **Nothing pictures a state change reaching somebody who has not opened the app** — no
   notification, no lock screen, no widget, in any of the fifteen artifacts.
4. **The rituals module appears in no artifact**, and it is the one surface the mission pairs with
   the word streaks: the place engagement machinery would hide was never photographed. 03_us shows
   three of the five its own report lists, so the Us layout still needs work beyond the row counts.
5. **17_setup_pwa.png is 27.3 per cent one exact RGB value at zero variance** — 1,225,541 pixels —
   while every other still sits on wood measuring about 11.
6. **frames.json's `repeated_frames: 0` is defeated by a one-level dither.** 32 per cent of 06's
   transitions are visually identical and the clip is frozen for its last 416 ms. The check needs a
   perceptual floor, not bit equality.
7. **Both tailnet records give their direct path as 192.0.2.2**, which is RFC 5737 documentation
   space, and `reliability.json`'s search capability is an identity map with no hits in it.
8. **A fifth module costs five shared files, not one line** — the registry, the type spec, two
   renderer entries and the stock assignment. The build's own structural claim is not met.
9. **A host-rejected event is re-pushed forever unmarked**: the refusal path is unreachable over the
   wire.
10. **DeskStamp is unbuilt**; no Android artifact; transport local.

## Next action

Capture 06 and confirm the letter has words on it. Then item 1 above — the factor of eight between
the stock in the library and the stock on the screen — because material is ten points below its
floor and that is one measurement, not a matter of taste. Then a sixth cycle.

Write the next builder sheet from measurements. Twice now the critics have scored a row at or above
its floor and the builder's own caution has taken it back below.

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
| 8 | 2026-09-07/08 | the fold's paper and the tooth halo; the module rows given their own bodies; the hero framed by measuring rather than estimating; the fling made a jump per frame; sixth capture; cycle 6 critics, completeness pass and score; the denoiser found behind the four-cycle desk hairline | **cycle 6: 73**, three floors met |
| 9 | 2026-09-08/09 | the pale rule on the wood closed by a six-build bisect (the mask's own antialiased edge); the record read at the shutter; her mood landing rather than swapping; a sheet that waits for its paper; seventh and eighth captures, fifteen of seventeen; cycle 7 critics, completeness pass and score; six of the cycle-7 findings fixed the same night | **cycle 7: 85**, four floors met |
| 10 | 2026-09-09 | fifteen fixes on the cycle-7 reports; the tenth capture, the first with all five clips passing their own check; a check that says which run wrote it; a scroll claim withdrawn by the capture that measured it; the paper-shaped objects found to have no tooth at all | **cycle 8: 83**, two floors met |
| 11 | 2026-09-09 | the objects given a surface at the source (no UV map, no paper), the ink made paint, the desk given pores; the ninth review | **cycle 9: 82**, three floors met |
| 12 | 2026-09-09/10 | the scroll's real cause found by shooting one scene twice (every note was a listener of every sync round: 595 row builds over twenty frames became 16); the fold made to bend rather than hinge; four two-sine "torn" edges replaced; the sawtooth hash under every cut card; DeskStamp's counters, absent for eight cycles; the app taught how big a millimetre is; nine records that did not exist | cycle 10: not yet reviewed |
| 13 | 2026-09-11/12 | the scroll's named failure closed and measured (147,237 ms of build over a fling became 6,112, 199 frames over 400 ms became 0); the contact shadow cut from the tear that casts it, and the hole in the desk it brought with it; the release path exercised end to end; the thirteenth capture in five passes across two container restarts; the eleventh review, seven reports | **cycle 11: 80**, no floor met |
| 14 | 2026-09-12 | the message-shaped hole in the thread (a piece whose tear has not arrived becomes a cut sheet, not nothing); the reconnect filmed while it happens rather than twice afterwards; the thread made to say when it cannot reach the other phone; the far phone taught to change its mind and to answer; the folded corner made a window onto a real sheet; a capture pass made able to correct an earlier one | cycle 12: capture running |

## Current position

- phase: build (cycle 11 scored at **80/100**, from 82, 83, 85, 73, 69, 68, 64, 55.5, 40; the brief
  asks 95 with every floor met). Cycle 11's fixes are in and its capture has not finished.
- rubric at cycle 11: messenger 22/30 (floor 26, short 4) · material 21/25 (22, short 1) ·
  emotional 16/20 (17, short 1) · coherence **13/15 (13, met)** · anti-goal **9/10 (9, met)** ·
  code **13/15 (13, met)**.
- **A review has to be of a tree that is not moving.** The completeness pass measured twelve paths
  rewritten between 19:58 and 20:07 UTC while cycle 11's review still stood, the earliest nine
  minutes after the last critic filed — so one of the code row's findings can no longer be checked
  against the tree it was written about. For cycle 12: builder sheet, capture, then nothing touches
  the tree until the seventh report is in.
- **Three diagnoses of the scroll have now been made and two disproved by instruments built to
  test them.** The tear mask baked per note: disproved by a counter that read twelve masks across
  a fling through 8,075 rows. The hand fonts' contextual alternates: disproved by a test that
  shapes a note in 0.074 ms. What it actually was: `Note.build` opened with `AppScope.of(context)`,
  which subscribes to an InheritedNotifier, and the spine notifies on every sync round — so every
  note on the glass was a listener of every round the other phone answered. Shooting the same
  scene alone and then with the far phone up: 135 row builds against 5,028.
- **Three material measurements turned out to be one fault.** The tooth spread thin on a wide
  sheet, the same ruled stock at rule pitches 2.9 times apart across ten stills, and writing that
  cannot sit on lines whose spacing differs on every screen: every stock is printed at 8.57 pixels
  to the millimetre and every piece drew its stock at whatever scale that piece happened to be.
  A piece takes a window of its stock at the stock's own density now.
- Two things measured this cycle and deliberately not fixed, both written into the evidence so the
  next cycle starts from a number: half the tear library's masks have a contour under 2 px rms
  (`logs/torn.json`), and the writing sits 0.33 of a rule pitch off the line (`logs/lines.json`).
- **A hole in the desk beside every sheet, and it had been there all along.** A coherence critic
  measured 758 pixels under luma 30 at one chip's edge in 12_search against a desk reading 84-103.
  The paper's tear is nine-sliced and the baked contact shadow under it was stretched with
  `BoxFit.fill`, so on a piece far from the render's proportions the two stopped coinciding — and
  what came out is black at alpha 255 over a third of each of those assets, because that third is
  meant to be under the paper. Nine-sliced and tinted warm now, and `tools/check/holes.py` gates
  on the ring three to twelve pixels outside every sheet: **nine of seventeen stills had one**.
  The existing `paper_rests_on_the_desk_test` caught the first attempt at the fix routing the
  shadow through a mipmapped sampler, which is the pale hairline five cycles were spent finding.
- Also this session: the nonce replay window scoped to writes (the `401` on the twenty-second long
  poll was a transparent browser retry of an idempotent GET); the page puts the desk out for the
  eight-to-ten-second first launch instead of showing a flat brown rectangle; a way back to now and
  the day at the top of the glass; four reach-back reply ties in the seed's last two months; and 48
  frames of the media viewer folded into a strip, so something in the set shows a video advance.
- **It went down, and it went down for the right reason.** Two floors are met against four last
  cycle. Material fell a point and the anti-goal fell two because the builder and the material
  critic, independently and before either read the other, found the same thing: the paper-shaped
  feeling objects are rendered with no surface at all. Messenger rose a point. Nothing regressed
  in the build between the two captures; the review got better at looking.
- The evidence set is **15 of 17** again, and for the first time **every clip passes its own check
  on one capture's frames** — 310, 421, 518, 300 and 376 frames, none held, no jump in the light.
- Every check written beside the artifacts now says which run wrote it. All fifty-five of this
  capture's are this capture's. That is there because a verdict left over from the previous run
  reads exactly like a fresh one and cost an hour before it was caught.

**Read `evidence/critics/8/completeness.json` before anything else.** It reproduced twenty-four
load-bearing claims; twenty-one came out as written or tighter, three overstated. What it found
that nobody else did:

- **`evidence/.previous/` is byte-identical to this capture**, so every SSIM in DIFF.json is
  measured against files that no longer exist beside it. The rotation is correct and the record of
  it is not: DIFF.json has to carry the baseline's own hash and time, or nobody can reproduce a
  number in it.
- **Nothing in the review is blocking.** Forty-three findings — thirteen serious, thirty minor,
  zero blocking — and three rows fail their floor anyway. BRIEFING.md defines `blocking` as the
  severity that caps a row at its floor, so the vocabulary and the arithmetic disagree.
- **Row 04 has two scores and no stated rule for combining them.** `tools/score.py` folds `code`
  into coherence as the lower of the two; BRIEFING.md never says so.
- **Nothing in the set shows the app loading**, and the fresh-store loads are 8,240 ms and
  7,813 ms against warm loads of about 2,100.
- **Two of the five delivery states — `queued` and `sending` — appear in no artifact and in no
  report field**, and they are exactly the two a person sees when the link is down.

### What is still open, and owned

1. **The record covers seven of eighteen event types.** photo, reaction, message_edit,
   message_delete, read_marker, state_passive, date_event, milestone, passed_on, ping and
   feeling_authored are never recorded in any scene report, so the picture cannot be checked
   against the record for any of them.
2. **No rubric row owns the shared-life modules** — a third of the mission — or the push path,
   or pairing as a journey, or accessibility. Row 04 asks only whether a *sixth* module could be
   added.
3. `logs/hand.json` reports one twin share at one threshold; it should report the curve.
4. `DIFF.json`'s `label_basis` explains the case that did not happen, and uses a fifth label its
   own `labels` field does not declare.
5. The heart-fold object is a heart-emoji silhouette that ships in the bundle and is inside the
   authoring picker's first thirty.
6. Nothing on Android; no haptic ever executed; no two devices in one frame; the PWA never
   measured as an installed home-screen app.

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
3. The evidence set is five cycles old in fifteen of its seventeen files: everything above and
   everything in `evidence/critics/6/measurements.md` is committed and uncaptured.
4. The library is mid-re-render, and a capture against a half-rendered one is refused by
   `tools/check/surfaces.py` rather than quietly scored.

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

Eight of them were put to a fresh-context investigator each, told to reproduce the finding end to
end and name the mechanism in code, and each investigation was then put to three refuters told to
break it. Three came back refuted. What follows is what survived, and what the refuters corrected.

1. ~~**The paper is being flattened between the library and the glass.**~~ **It is not.** The
   "factor of eight" compares `patch_std` — the largest std among nine 200 px patches, which on a
   ruled stock is a measurement of the printed rules — against a median over ink-free 32 px blocks.
   Applied to the same shipped files, the second metric reads 1.09-1.49 in the library and 1.24 on
   screen: nothing measurable is lost. `BoxFit.cover` does not even downscale — the ruled pitch is
   55 px in the asset and 70 on screen, so the stock is magnified 1.27x.
   *What was real:* the packer re-encoded an already-lossy WebP render. Fixed in cycle 6 by not
   re-encoding when nothing needs doing (13.91 MB and the render's own 1.194, against 15.44 MB and
   1.144 at quality 95). A deeper one is still open: `stocks.py` renders paper as WebP at Blender's
   default quality 92, so every downstream number is measured against an already-degraded ceiling.
2. **The light the shadows describe touches nothing else.** Half true, and the half that is true is
   geometry rather than the rig. A sheet cockled by 0.15-0.35 mm has a peak slope of 0.7 degrees —
   it is a plane, and a plane under a distant sun and an orthographic camera has one value. Cycle 6
   scales the cockle to a fraction of the sheet's width instead: 3.2 degrees, and the re-rendered
   lined_01's ink-free block field swings 5.86 grey levels where it swung 1.33.
   Objects and bits are now rendered with the desk under them, invisible to the camera and present
   to the light — worth +6.7 to +12.6 across a cylinder's wall, measured, not the +0.5 to +18.6 the
   investigation promised. A refuter showed why: the ground buys most of that by occluding the
   lower half of a constant sky, not by bounce, and the sun was never delivering nothing.
   *Still open:* the constant `Background` world carries no direction at all. Halving
   `DAY_SKY_STRENGTH` would buy as much as the ground did, and would change every family at once.
   And eight of the objects are flat-lying sheets and stains: no lighting change puts a gradient on
   a plane. Those want different objects, not a different rig.
3. **Nothing pictures a state change reaching somebody who has not opened the app.** Root cause
   found: every artifact is shot in Playwright's WebKit, where `Notification` and `PushManager` are
   *undefined* — the app's own code falls into its catch, `_allowed` stays false, and nothing is
   ever created to photograph. Cycle 6 adds one scene outside the seventeen, in Chromium under Xvfb,
   which delivers a real push to the real worker and grabs the display the browser drew on.
4. **The rituals module appears in no artifact.** Root cause found and fixed: Us budgeted the desk
   in rows, which the shell cannot price. It budgets in points now.
5. **17_setup_pwa.png is 27.3 per cent one exact RGB value.** Root cause found and fixed: that value
   is `DeskColour.dusk`, the flat ground `Desk` paints under the wood render, and the render arrived
   8.5 s after the only frame that screen ever draws. It is resolved before the first frame now.
6. **frames.json's `repeated_frames: 0` is defeated by sub-perceptual motion.** Root cause found and
   fixed. Nothing dithers on purpose: the gate was a fortieth of a grey level averaged over seven
   million subpixels, and the fold sequence's own ease-out clears it while the sheet has stopped
   moving. Three terms on luma now, and the tile term is the one that separates slow motion from a
   frozen frame.
7. **Both tailnet records give their direct path as 192.0.2.2**, and the search capability is an
   identity map. Both fixed: the record names the endpoint, says it is this container's own address,
   and says what that means; the search record carries the query, the hit count and the id.
8. ~~**A fifth module costs five shared files, not one line.**~~ **Closed.** The last two were the
   thread row and the sentence, both written for the module in the chat region; a module declares
   both now (`Module.bodies`, `Module.sentence`) and the table is assembled from `kModules`. Two
   more per-type switches went with them and both were short as well as duplicated: search's
   "found as ..." named 11 of the 18 types and Moments' "what happened" lens named 4 of the 5 kinds
   of thing that happen, so a thing passed on read as its own registry id in one and appeared in no
   lens at all in the other. `module_costs_test` reads the source: no file outside a module's own
   directory may name that module's event types, except the spine registry, which is a principle
   and not a cost.
9. **A host-rejected event is re-pushed forever unmarked**: the refusal path is unreachable over the
   wire. Open.
10. ~~DeskStamp is unbuilt~~ — built. One union over a few thousand overlapping ribbon quads cost
    Skia 65 seconds; unioned in batches of thirty-two and folded pairwise, the whole face is 112
    seconds. No Android artifact; transport local.

## Next action

Read the eighth capture — the seventh was taken, answered rather than reviewed, and re-shot whole
with the four fixes it produced in the build. Then the seventh review: the builder sheet from
measurements *before* any critic runs, `bash tools/critics.sh hide 7`, six critics and the
completeness pass, `show 7`, `python3 tools/score.py --cycle 7`.

Write the builder sheet from measurements. Twice now the critics have scored a row at or above
its floor and the builder's own caution has taken it back below.

### Closed this session, after the seventh capture and not in it

- **The desk hairline, open for five cycles.** It was the tear mask's own edge: `ShaderMask` draws
  a dstIn rectangle the size of the child, that rectangle is antialiased, and on the row where a
  piece's box falls between two device pixels a third of a pixel of sheet survives where the tear
  had erased it (wood + 0.334 × paper, solved on all three channels). A six-build bisect in the
  browser: mask shader without mipmaps 29 runs, exact-height mask 29, rotation filtered differently
  29, lit edge removed 29, **mask removed 1**, mask rectangle two pixels wider **0**. Six earlier
  explanations were wrong, including the one the code and the docs asserted.
- **A sheet drawn before its paper arrived** — the +11.6 grey-level light jump that failed 07.
- **A mood that changed between two frames** — the 61 identical frames that failed 08.
- **Clip lengths the year invented** — 20 payloads that claimed 7–12 s over 2.5 s of footage.

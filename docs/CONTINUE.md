# love-tap — continue the build

**Read `docs/BRIEF.md` first, all of it.** It is the mission and it is authoritative: the rubric,
the five categories with their weights and floors, the four anti-goals, the seventeen evidence
artifacts at their exact filenames, the family floors, the three commands, and the secret
constraints. Everything in this file is *state*, not instruction — where the two disagree, the
brief wins.

**Repository** `kaiharimoto/love-tap` · **branch** `claude/new-session-f95s8n` (develop, commit and
push only here) · **working directory** `/home/user/love-tap`.

Every reply must end with the fenced ```mpstate block the brief specifies (v, task, phase, step,
cycle, score, next, blocked, ask).

---

## 0. What is in flight right now

**Cycle 6 is scored: 73/100, from 69, and three floors are met for the first time** — emotional
17/17, coherence 13/13, anti-goal 9/9, with critic and builder agreeing to the point on all three.
The two that are left are the two the build turns on: messenger 19 of 30 against a floor of 26, and
material 15 of 25 against 22, both held down by the critic rather than by my own sheet (24 and 20).

**Read `evidence/critics/6/completeness.json` first.** It falsified two blocking mechanisms and
confirmed the faults underneath them — the scroll's build spikes are periodic on the wall clock at
the sync engine's twenty-second poll rather than in app time, and the fold's straight edges and
slab shadow are in the Cycles render itself rather than in any transform the app applies.

**Cycle 7's fixes are all in, the renders are done, and the seventh capture is running.**
Committed and pushed, each with the measurement that says it worked:

- the media viewer has a film strip — play and hold marks, a pencil rule with the played part
  inked in and a tick at the playhead, the times in the margin hand, seek on tap or drag;
- search chrome went from 66 per cent of the page to 29, with six hits on it instead of three,
  because a `Slip` takes the room it is given and each of fifteen tabs was taking the whole width;
  the chosen tab stands proud, is stamped in ink and is underlined;
- the delivery record uses the words on the paper, and counts only rows that draw a mark;
- the service worker obeys the treatment and quiet hours a person set, read out of the app's own
  store, and keeps no per-type table: the words a phone says live in the registry;
- the whole feeling vocabulary was playing **inside out** on any phone without amplitude control —
  `createWaveform(long[], int)` reads its first number as a wait and every pattern starts on;
- the icon on the home screen and on every arrival banner was the Flutter logo, and is now made of
  the app's own material; the gold star and the crown are gone from the library;
- two fields carried three names; there is one table now;
- a voice note in the pile carries what the thread gives it, which also fills the eight tiles that
  had no ink on them at all;
- the ink plate: the core of a mark varied by 3.52 grey levels and now varies by 53.7 (biro) and
  32.3 (pencil), because a pen runs dry across a word rather than only along an outline;
- a cut card's edge wanders (0.030 px → 0.269 over 536 columns) and its contact shadow varies
  along its length;
- the transport stopped announcing the time of day, which was rebuilding every region every twenty
  seconds;
- 08 drives its state changes inside a frames run, so a partner-state change is visible happening;
- the crops the material row is judged on land on writing (23.7 per cent ink, against none).

**The four-cycle desk hairline is a rotation without a filter.** Not the desk (zero one-row spikes
in the render at any threshold), not the baked shadows (same), not the piece's bounding box, and
not the denoiser — that one is written up as a wrong turn on the cycle-7 sheet. In the artifact the
rules step one row down for every 166 px along, which is a third of a degree, which is exactly the
tilt a `Slip` gives a piece; `Transform.rotate` with no `filterQuality` is nearest-neighbour, so
every hard edge inside a piece comes out a row at a time.

**Three render queues ran and are packed**: 112 contact shadows without the denoiser (1 h 43 m),
the fold sequence at 240 frames (1 h 07 m, packed to 139), and the desk. The fold's own tool
re-measured where the writing goes on the open sheet.

**What is left in cycle 7**: read the capture, write `evidence/critics/7/builder.json` from the
sheet *before* any critic runs, `bash tools/critics.sh hide 7`, the six critics and the
completeness pass, `show 7`, `python3 tools/score.py --cycle 7`, docs, push.

**Known and not yet closed**: the hand still repeats (8.9 per cent of marks have a near-twin at
0.99 by the critic's method, 16.7 by the app's own log) — the fix is more variants per glyph and a
font rebuild; the desk's anisotropy is 5.18 against paper's 0.63 and I do not think that comparison
is a defect to close, for the reason on the sheet; 09 and 16 need an Android device.

**A process fault not to repeat:** the tree moved under the review. Cycle-7 fixes went in once the
six critics had filed while the completeness pass was still running, and it noticed. Nothing is
written until the whole review has landed.

**What was fixed in this session and is in the captured evidence:**

- The fling is a jump, not an animation. A frame of the scroll clip used to be a one-millisecond
  animation of the scroller, and an animation moves on its ticker — which is stepped by the
  browser's frame timestamp rather than by the driven clock, so two frames the clock pumped inside
  one step could carry the same timestamp and the thread did not move on a frame it was told to.
  Held frames went 3, 5, 6, 13 of 300 across four passes while I made the harness more patient, and
  the patience was not the fix. The pixels are set on the list's own scroll position inside the
  tick now. **300 frames, zero held**, every frame moved (47.5 logical pixels at the most, 10.4 at
  the least), and the frame timings say the animation had been costing more than the held frames:
  **build p95 1050 ms -> 54**, which is the number rubric row 01 calls scroll jank.
- The hero is framed by measuring. It used to estimate a row's height from how much writing was on
  it and framed six notes, then seven, against a standard of eight. It goes to a stretch now, lets
  it lay out, counts the paper that actually landed and keeps the best framing it has seen — and
  three things fell out of doing that: the sheet you write on is a sibling *below* the list rather
  than a layer over it (a row's worth of room was being thrown away), asking for a voice note and a
  reaction found six places in a year because it read that as one row being both (48 now), and
  `tears.py` counted every visible row although a tear id is computed for rows that draw no torn
  edge at all. **Eight rows on the glass, all eight paper, eight distinct tears.**

Both are guarded by tests that fail on the old code: `app/test/a_fling_is_a_scroll_test.dart` and
`app/test/the_hero_holds_eight_notes_test.dart`. The second one loads the real year through the
real `SeedLoader`, loads the three real faces with `FontLoader` (a widget test lays text out in
Ahem otherwise, and Ahem's metrics change the answer), and builds the app's own `Shell` — so it
measures the room the thread actually has rather than a guess at the chrome.

**Named and not fixed, for the next cycle:** paper is rendered as WebP at Blender's default quality
92 before it is packed, so every material number in the build is measured against an already-lossy
ceiling. The packer's own second pass is gone; the render's is not. That is twenty-seven stocks at
about four minutes each plus the dusk half, and it has to land before a capture rather than between
two.

## 1. Where the build is

Five review cycles have run. Cycle 5 scored **69 / 100**, from 68, 64, 55.5 and 40, with no floor
met: messenger 19/30 (floor 26) · material 15/25 (22) · emotional 15/20 (17) · coherence 12/15 (13)
· anti-goal 8/10 (9).

**Two floors were met by the critics and lost to the builder's own sheet.** The critics put
coherence at 13 and anti-goal at 9.2 — at and above their floors for the first time. My sheet,
written before reading them, said 12 and 8, and the rule is the lower of the two. That is the
mechanism working and it was not revised afterwards. The practical consequence for you: on those
two rows the builder is now the binding constraint. Write your sheet from measurements you took,
not from caution.

**Read `evidence/critics/5/completeness.json` before you read anything else, including this file.**
It is the pass that checks the other six and it has been the most valuable document in the build
two cycles running. This time it corrects one critic for reading the arriving message in 06 as "the
composer card" and shows another's photographic-paper proof failing to reproduce. Its headline lead
— a stock at patch_std 9.4-10.3 in the library arriving on screen at 1.22 — **is a comparison of two
different instruments, and cycle 6 established that nothing is being flattened.** See section 1.

**One thing is committed and not captured.** The note arriving in 06 unfolded for four seconds and
ended completely blank — three critics measured it, minimum luminance 223, not one pixel of ink.
A Stack whose children are all positioned sizes to nothing under loose constraints, so the overlay
carrying the name and the ink filled nothing. Fixed, with a test. Three attempts to re-capture 06
then failed in the harness rather than the app; `TASK_STATE.md` has everything known about that.
Capture 06 first.

## 2. What the evidence set is now

Fifteen of the seventeen artifacts are present. **09_two_devices.png and 16_setup_android.png are
not, and cannot be here**: they need an Android device and this container has no `/dev/kvm`. The
three routes tried are measured in `docs/PHONES.md` — the x86_64 emulator under QEMU instruction
emulation reached `adbd` after 113 minutes and never the framework, there is no GTK for a desktop
build, and a `flutter_tester` render loads fonts but no material. Nothing was faked from the PWA.
On a host with `/dev/kvm`, or on ARM64 where `arm64-v8a` runs natively, do those two first.

Every seeded still is taken on a phone **paired with the far phone over the whole seeded year**:
`link: connected`, 14,062 events, in all eight reports. The far phone is
`app/tool/host_daemon.dart --seed year` — the app's own spine in the host role with the real
six-word pairing, serving the PWA the near phone loads, and taking one instruction a line
(`message`, `feeling`, `state`, `read`, `typing on|off`, `pair`, `stop`) on `pair.json.do`.

All five clips pass `tools/check/frames.py`: no frame identical to its predecessor at full
resolution, no light change inside a take.

| clip | frames | seconds | what it films |
|---|---:|---:|---|
| 06_unfolding | 326 | 5.22 | a folded letter opening, twice: the packet landing, the flap standing with its shadow across the third below it, the creases catching light on the settled sheet, and the ink on it |
| 07_feeling_landing | 421 | 6.74 | four feelings landing on the phone they reached, across three surfaces, with the pattern annotated on the timeline |
| 08_state_propagating | 502 | 8.03 | a mood, a message, a place, an availability and four feelings crossing between two phones |
| 11_chat_scroll | 300 | 4.80 | the thread thrown seven times and running down on its own physics; `evidence/logs/11_chat_scroll.fling.json` is what it did, frame by frame |
| 15_authored_feeling | 376 | 6.02 | the vocabulary gone through family by family, ending on the couple's own, then sent and received |

Every clip is assembled at **62.5 frames a second**, which is the rate its frames were taken at:
the scenes step the app's clock 16 ms a frame. Assembling at 60 played every clip four per cent
slow against the app time the same logs record, which a completeness pass measured.

## 3. Things that cost hours here, so that they cost you none

Everything in the previous handoff still holds. These are new.

- **A clip is only as long as the motion in it.** Every run of a `frames` step must end where the
  thing being filmed stops moving, or the tail is frame-identical and the check fails. The
  arithmetic is in `app/lib/feelings/landing.dart`: a thrown object rests
  `max(last bounce, pattern length)` and is put away over `putAwaySeconds`. A run that opens
  exactly at the apex of a throw gives two identical grabs, because that is where the velocity is
  zero — step the clock once before it.
- **The headless compositor runs at about four frames a second.** A screenshot can come back as
  the frame before, or half drawn. `scene.js` re-grabs when a frame is identical to the last one
  and again when its size jumps, and the driven clock pumps two frames a step because a widget
  that finishes in a post-frame callback is drawn a frame late. Do not put a `requestAnimationFrame`
  wait in the frame loop: it is throttled to about a second and costs six seconds a frame.
- **The far phone can lose an instruction.** It watches a file; it now renames the file before
  reading it, and `awaitArrival` says the line again if nothing comes. Both are recorded in the
  scene log, so nobody reads a clip as one clean exchange when it was not.
- **The bug that ate a day: events from the other phone were silently dropped.** A message would
  not arrive for over a minute while the near phone reported `link: connected` the whole time, about
  one run in four. Three causes, in the order they were found and fixed: the sync loop ended for good
  on any exception other than the transport's own; its backoff doubled to thirty seconds after every
  empty long-poll; and — the one that mattered — `stored_order` is a unique index in the web store,
  so two overlapping `upsertAll` calls allocated the same key, the transaction raised
  `ConstraintError`, and the whole batch vanished with the failure swallowed. Writes are serialized
  now (`app/lib/spine/store/store_web.dart`). If a pull ever goes quiet again, read
  `evidence/logs/08_state_propagating.report.json`: the sync engine's own numbers are in it
  (`rounds`, `pushed`, `pulled`, `faults`, `last_fault`) and a failed `awaitArrival` prints them.
- **Keep the browser profile.** `capture.sh` gives every seeded scene one persistent profile,
  emptied at the start of a run, so the year imports once (11-12 s) and every later scene opens on
  a phone that already has it (2.7-3.4 s). The log says which kind of load it measured.
- **A run of frames must stop one step short of the animation it films.** The last two grabs of a
  20-step animation filmed in 20 frames are the same picture at t=1, and the check counts that as a
  repeat. Nineteen frames of a twenty-step slide.
- **A handle called with `after: 0` lands after the next grab.** The first frame of a run showed the
  family before the one it had just turned to — a repeat at the cut and a brightness step one frame
  into the run. One `{"do": "step", "ms": 16}` between them fixes both.
- **A region change animates on the driven clock**, so a wall-clock wait does not advance it and the
  frames that follow film the tail of the turn. `{"do": "step", "ms": 400}` after a `goTo` puts the
  turn behind the camera.
- **Anchor a tall row by where it ends, not where it starts.** A window anchored by its first row
  leaves a 480-pixel video hanging under the composer, and three critics measured its blank top
  sliver and reported that video renders as an empty strip. They were reading the framing.
- **Measure the packed frames, not the render.** `pack_assets` trims every fold frame to its own
  content, so `tools/check/fold_inset.py` has to be pointed at `app/assets/`, not `assets/`.
- **A Stack whose children are all positioned sizes to nothing.** Under loose constraints it
  collapses, and everything inside it fills nothing — silently, with no error. It cost the fold its
  ink for a whole cycle, and it is the same rule behind a Stack clipping a shadow that is
  deliberately wider than its child. Any time something composed in a Stack is invisible, check its
  size and its `clipBehavior` before anything else.
- **A widget test cannot see the fold.** The frames decode asynchronously off the bundle, so a test
  draws an empty box and passes. Two of this session's most valuable tests read the composition out
  of the source instead, which is worth doing when the pixels are out of reach.
- **The far phone and a partial capture do not always agree.** A full `./capture.sh` has always
  worked; three `--only` runs against the far phone failed with the near phone connected, its event
  count rising, and its thread not growing. It is not the browser profile — that is emptied on every
  run, partial ones included. When a partial run stalls at `awaitArrival`, do a whole one.

## 4. What is left, in order of what it costs to close

Every number here is a critic's, from `evidence/critics/5/`. Check them before acting on them; two
of the six did not reproduce this cycle and the completeness pass says which.

### 1. ~~The paper is flattened between the library and the glass~~ — it is not (closed, cycle 6)
`surfaces.py`'s `patch_std` is the largest standard deviation among nine 200 px patches of the whole
file, and on a ruled stock every one of those squares contains three or four printed rules at a
55 px pitch. The 9.36-10.28 is a measurement of the ruling. The 1.22 is a median over ink-free 32 px
blocks. Measured the same way at both ends the library reads 1.09-1.49 and the screen 1.24 — they
agree. `BoxFit.cover` does not downscale either: the ruled pitch is 55 px in the asset and 70 on
screen, so the stock is magnified 1.27x. Nothing in `PaperPiece` is averaging anything away.

What was real underneath it, and is fixed: the packer made a second lossy pass over a render that
was already lossy WebP. It copies the bytes when nothing needs doing — 13.91 MB and the render's own
high-pass of 1.194, against 15.44 MB and 1.144 at quality 95.

What is still open: `blender/paper/stocks.py` renders paper as WebP at Blender's default quality 92,
so every number downstream is measured against an already-degraded ceiling. Rendering paper once,
losslessly, and encoding once in the packer would recover more than any quality knob downstream.

`surfaces.json` now reports `tooth` and `field_swing` beside `patch_std`, and says in the record
what `patch_std` is, so this particular confusion cannot be had a second time.

### 2. The light the shadows describe touches nothing else (material)
A note's interior swings 9 to 13 grey levels on 230 across its full width. The 'hold' cylinder on
01_pulse reads 148 on one side of its curve and 153 on the other while throwing a hard directional
shadow. The fold's flap darkens 17 per cent while foreshortening 90. The shadows are baked from
renders and the surfaces they fall on are not, so they read as attached to flat art.

### 3. Nothing pictures a state change reaching somebody who has not opened the app (emotional)
No notification, no lock screen, no home-screen widget, in any of the fifteen artifacts. The ambient
surfaces are recorded as sent in `logs/ambient.json` and never as received.

### 4. The rituals module appears in no artifact (anti-goal, coherence)
It is the one surface the mission itself pairs with the word streaks — the place engagement
machinery would hide, never photographed. 03_us shows three of the five modules its own report
lists, so the Us layout needs more than the row counts it got this cycle.

### 5. 17_setup_pwa.png is 27.3 per cent one exact RGB value (anti-goal)
1,225,541 pixels at zero variance, while every other still sits on wood measuring about 11.

### 6. The frame check is defeated by a one-level dither (evidence)
`frames.json` reports `repeated_frames: 0` while 32 per cent of 06's transitions are visually
identical and the clip is frozen for its last 416 ms. Bit equality is the wrong test; it wants a
perceptual floor.

### 7. Two records say things that are not so (evidence)
Both tailnet records give their direct path as **192.0.2.2**, which is RFC 5737 documentation
space. `reliability.json`'s search capability is an identity map with no hits in it. And
`logs/12_search.report.json` describes the thread behind the search sheet rather than the search.

### 8. The build's own structural claims (code)
A fifth module costs five shared files rather than one line: the registry, the type spec, two
renderer entries and the stock assignment. The passive half of the nervous system has no producer
outside the capture hook and the seed. A host-rejected event is re-pushed forever unmarked, because
the refusal path is unreachable over the wire.

### 9. DeskStamp is still not built (material, coherence)
About five hours on one core here. Start it at the beginning of a session, not the end.

### Not fixable here
09 and 16, as above. The tailnet run is recorded **pending**: no `TS_AUTHKEY` was in this
session's environment, `toolchain/ts/AUTHKEY_STATUS` says `pending`, and the brief says the
question may only be asked from the session in which the Tailscale phase began — which has
happened, so it may not be asked again.

## 5. How to run it

    ./bootstrap.sh                                    # pinned toolchain into ./toolchain
    tools/apt-prereqs.sh                              # and: apt install libevent-2.1-7t64 libwayland-server0
    ./run.sh --seed=year --transport=local
    ./capture.sh                                      # the whole set, about 90 minutes
    ./capture.sh --no-build --only=06_unfolding,08_state_propagating   # a list, against the builds on disk
    cd app && ../toolchain/flutter/bin/flutter test   # 96 tests

`KEEP_FRAMES=yes ./capture.sh` keeps `evidence/frames/` so a clip can be measured frame by frame
after the fact. `python3 tools/check/frames.py evidence/frames/<name> --fps 60` is the check.

**Scoring.** Write your own sheet to `evidence/critics/<cycle>/builder.json` under a `scores` key
*before* reading the critics, then `python3 tools/score.py --cycle <n>`.

**Running the critics.** The Workflow tool, six agents in parallel plus a completeness pass. The
script that ran cycle 3 is worth reusing; it passes each critic its rubric prompt and forbids the
git log, the docs, the task list and any other cycle's reports. Move `evidence/SCORE.json`,
`evidence/critics/<earlier>/` and this cycle's `builder.json` out of `evidence/` while they run.

## 6. Secrets, which are failure conditions

`TS_AUTHKEY`, a CA private key, or a pairing secret in any committed file fails the whole build.
The key is read from the environment and never written down; `toolchain/ts/AUTHKEY_STATUS` holds
only the word `pending` or `supplied`. With no key the tailscale run is recorded **pending** — not
passing, not failing. `ask=TS_AUTHKEY` may appear in the heartbeat only from the session in which
the Tailscale phase begins; that has happened, so it may not appear again.

The host binds its tailnet address or does not start. Spine content travels by no path other than
the Tailscale channel. A Web Push payload carries nothing beyond event kind and sender.

## 7. Outstanding for the user, not for you

Revoke the Tailscale auth key at `login.tailscale.com/admin/settings/keys`, and remove `lovetap-a`
and `lovetap-b` from the admin console — they were not registered ephemeral, so they linger.

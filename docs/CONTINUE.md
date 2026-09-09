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

**Cycle 7 is scored: 85/100, from 73, and four floors of five are met** — material 22/22 for the
first time (it was 15), emotional 18/17, coherence 13/13, anti-goal 9/9. Messenger is the only one
short: 23 of 30 against a floor of 26. Builder and critic agree to the point on every row but that
one.

The evidence set is **15 of 17**, the first time it has been whole apart from the two that need an
Android device: every clip passes its own frame check, and `tools/check/hairline.py` reads all ten
stills and finds zero bright one-row rules on the desk, where nine of ten carried them for five
cycles.

**Read `evidence/critics/7/completeness.json` first.** It found what six critics wrote around —
`app/web/push/sw.js` sending `silent: true` and a vibration pattern in the same call, which
Chromium refuses outright, so every arrival marked `interrupt` was dropped inside the push handler.
It also falsified one serious finding outright (the handwriting one) and cut five more down to
size, with its own numbers each time.

**Six of cycle 7's findings were fixed the same night**, each with a test that fails when the fix
is reverted:

1. **A piece draws its tear, it does not bake it.** `SlicedMasks.at` composed a nine-patch into a
   picture and called `toImageSync` on the build thread — 16.1 ms on the Dart VM, hundreds of
   milliseconds in CanvasKit, once per note as the thread scrolled. Drawn straight in with
   `drawImageNine` in `dstIn`: 1 frame of 148 over 400 ms against 52 of 189, build p95 26 ms
   against 807, and the raster fell too.
2. **A refusal is not a dead end.** Send it again — the mark comes off and the event is back in the
   outbox. An eighteenth reliability capability exercises the whole path over the wire.
3. **The push that could never be drawn**, above; and `notify.prefs` was never written until
   somebody opened Settings, so the registry's declared treatments and the quiet hours were in
   force on no phone.
4. **`awaitView` asks one question** (`__deskView`) instead of polling the whole report.
5. **The search mark is off the thread** — it covered thread text in 84 of 300 frames pinned over
   the list, and cost the hero a whole sheet in a strip of its own, so it sits on the composer.
6. **One clock and one day label** — a clip had three lengths in one evidence set, and Moments read
   `teo · ` with the separator drawn and nothing after it.

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

### Why a session stops, and how not to

Three causes, all of them measured in this session rather than guessed at. None of them is the
work running out.

1. **Ending a turn parks the session.** A reply is a full stop: nothing else happens until a hook,
   a notification or a person wakes it. Reporting progress and then waiting is the single largest
   source of dead time here — a capture that takes ninety minutes costs ninety minutes *plus*
   however long the session sits idle after the reply that announced it. Stay inside one turn:
   chain the tool calls, wait with a blocking `until` loop (`timeout: 600000` is the ceiling, and
   the harness backgrounds anything longer — just issue it again), and reply when there is a
   result, not when there is a wait.
2. **The container restarts and takes every background process with it.** `uptime` said 26 minutes
   in the middle of this session: the running capture, its far phone and a probe daemon all died
   at once, the log simply stopped mid-scene with no error, and `nohup` did not help. The disk
   survives, so nothing committed was lost and `/tmp` was still there. After any gap, check
   `uptime` and whether the process is still alive before believing a log that has stopped moving.
   Commit and push before anything long: a restart then costs minutes rather than work.
3. **A waiter outlives the thing it waits for, and silence looks like progress.** Five background
   `until grep -q "^EXIT" ...` loops were still spinning an hour after their runs had been killed,
   because the marker they were waiting for could never be written. A waiter must watch something
   that fails as well as something that succeeds, and when a run dies its waiter has to be stopped
   (`TaskStop`) rather than left to poll a file nobody is writing.

And one that is not about stopping but wastes as much: **do not rebuild or edit the tree while
critics are reading it.** The cycle-7 completeness pass caught `app/build/web` being rebuilt
between two reports and named it: the evidence moved under the review. Capture, write the builder
sheet, hide, review, show, score — and keep your hands off the tree between the second and the
fifth of those.

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

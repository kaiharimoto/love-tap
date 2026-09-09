# CONTINUE

The state handed to the next session. `docs/BRIEF.md` is the mission and wins over this file.
Branch: `claude/new-session-f95s8n`.

## 0. Where it stands

**Cycle 8 scored 83**, from 85 the cycle before, and the drop is the review getting better rather
than the build getting worse. Two floors of five are met (emotional 17/17, coherence 13/13).
Messenger is 24 against a floor of 26, material 21 against 22, the anti-goal 8 against 9.

The tenth capture is 15 of 17 artifacts and the first in which **every clip passes its own frame
check** — 06 at 310 frames, 07 at 421, 08 at 518, 11 at 300, 15 at 376, none held, no jump in the
light. Every check written beside the artifacts records which run wrote it, and all fifty-five of
this capture's are this capture's.

Three things to know before touching anything:

1. **The paper-shaped feeling objects have no surface.** Measured inside the packed renders and
   inside the 1200 px sources, 80 px windows of an object's own interior read a median local
   standard deviation of 0.89 (`obj_dog_ear`), 1.08 (`obj_bookmark`), 1.36 (`obj_torn_corner`),
   2.49 (`obj_ticket`), against 9.0-9.6 for the paper stocks measured the same way. The material
   critic found the same thing from the other end — countable facet steps of 14-25 grey levels,
   1.67 per cent of spectral power above 35 per cent of Nyquist against 23.65 for the sheet behind
   it — and their shadow is a uniform blur that is *lightest at the contact*. On the glass that is
   a pale card with a drop shadow under it, which is the brief's own words for a failure of the
   whole visual concept.
2. **The scroll is not fixed and the claim that it was has been withdrawn.** A commit said "1 of
   621 frames over 400 ms"; the capture measured 203 of 793, p95 897, against 189 of 793 at p95
   688 the run before. The cause is read from the code and not guessed: `Written` wraps its text in
   `Inked`, a `ShaderMask`, so every note's subtree needs a compositing layer, so its tear cannot
   be drawn straight into the canvas and is composed as an image keyed by `tear@WxH` — one tear per
   note out of a pool of 56, so the height bucket saves nothing. `inkPaint` already exists for
   this; what it needs is a cached shader and a cached Paint.
3. **Never quote a check you have not dated.** `evidence/logs/<clip>.frames.json` keeps its name
   between runs, so half way through a capture the previous run's verdict is sitting in the file
   under the file's own name and reads as fresh. That cost an hour. `MANIFEST.json` now stamps
   every check; read `from_this_run` before you believe a number.

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

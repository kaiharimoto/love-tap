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

## 1. Where the build is

Three review cycles have run. Cycle 3 scored **64 / 100**, up from 55.5 after cycle
2 and 40 after cycle 1, with no floor met: messenger 19/30 (floor 26) · material 13/25 (22) ·
emotional 15/20 (17) · coherence 10/15 (13) · anti-goal 7/10 (9). `evidence/SCORE.json` carries the
arithmetic — the rule is the *lower* of the critic's number and the builder's, per category, so a
category rises only when both see it rise. Fourteen of cycle 3's findings were fixed in the same
session and are **in the code and in none of the artifacts**; the next capture is what shows them,
and `TASK_STATE.md` lists them one by one.

`evidence/critics/3/` is your work list. Every finding carries the measurement that established
it, so each one can be checked and each one can be shown fixed. `TASK_STATE.md` has the table of
what cycle 2 said and what was done about each of its findings.

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
| 06_unfolding | 256 | 4.27 | a folded note arriving, opening, the ink coming up on the sheet |
| 07_feeling_landing | 314 | 5.23 | three feelings landing on the phone they reached |
| 08_state_propagating | 395 | 6.58 | a mood, a message and two feelings crossing between two phones |
| 11_chat_scroll | 300 | 5.00 | the thread thrown and coming to rest on its own physics |
| 15_authored_feeling | 304 | 5.07 | the vocabulary out, a feeling the couple made, sent and received |

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

## 4. What is left, in order of points on the table

### 1. 06 does not read as paper unfolding (material, 12 points below floor)
The frames are right — 240 of them, every one above the paper floor, worst 2.1 against 1.2 — and the
app plays them one per 16 ms step with the ink coming up on the sheet. The camera is the problem: a
flap rotating about its crease foreshortens to nothing seen from directly overhead, so a top-down
orthographic camera films a cream rectangle getting taller. Tilt the camera in
`blender/rig/common.py`'s fold rig (25–35° off the normal is enough to show a flap's underside), then
re-measure `FoldedNote.inset` in `app/lib/material/fold.dart` against the new framing, because the
sheet's resting face moves in the frame. Both are written down at the top of `blender/folds/fold.py`.
Budget one render (≈70 min at 240 frames) plus a capture of 06.

### 2. A third of repeated letters are twins (material)
The cascade advances one variant per letter, so with five variants two of the same letter four apart
land on the same outline: measured IoU 0.9954 on the hero crop, twin share 0.30 by
`tools/check/hand.py`. The lever is the variant count in `tools/handwriting/hands.json`; eight
variants put the share near twelve per cent. A face is about ninety minutes to build and the manifest
carries the other faces forward, so build one face at a time (`--faces TeoHand`) and check with
`tools/handwriting/check.py`. Written down in `tools/handwriting/build.py`.

### 3. A feeling's object is clipped by the paper it arrives on (emotional)
`app/lib/material/objects.dart` draws the image at an ink correction of up to 3.4 while the box stays
at `size`, so the tallest objects lose their tops on a note. The fix is a frame-aware size the callers
ask for — sizing the box to `size * scale` alone overflows the Pulse row by 102 px, which is recorded
in the file. Every call site is listed there.

### 4. DeskStamp is still not built (material, coherence)
126 of 155 glyphs in eleven hours, slowing as it goes. `app/pubspec.yaml` points DeskStamp at TeoHand
and says so in a comment. Resume with `tools/handwriting/build.py --faces DeskStamp` in the
background at the start of a session, not the end.

### 5. Four messenger capabilities have no picture (messenger, 7 points below floor)
Edit, attach, voice and video work in the app and appear in no artifact: the sixteen scene scripts in
`evidence/scenes/` have no step for any of them. The gap is in the capture plan, not the app. Reaction
and reply were closed the same way — `stageStates` now stages a real one of each — so extend that
handle rather than inventing a new surface.

### 6. No two-device frame, no Android artifact, every transport line `local`
09 and 16 as above. The tailnet run is pending for want of a key. This is the largest single block of
points left on the messenger row and none of it can be moved from this container.

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

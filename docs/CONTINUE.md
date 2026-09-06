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

Four review cycles have run. Cycle 4 scored **68 / 100**, up from 64, 55.5 and 40, with no floor
met: messenger 17/30 (floor 26) · material 16/25 (22) · emotional 16/20 (17) · coherence 11.5/15
(13) · anti-goal 7.5/10 (9). The rule is the *lower* of the critic's number and the builder's per
category, and in all five categories this cycle the critic's was lower.

**Read `evidence/critics/4/completeness.json` before you read anything else, including this file.**
It is the pass that checks the other six, and it is the most useful document in the build. Its
verdict is that all six critics measured only inside the artifact each was pointed at, and it proves
it: one torn edge repeated twelve times down the search results, the app's own tab strip carrying
the exact shape the anti-goal forbids on ten of eleven stills, feeling objects that do not change
under the dusk light while the paper beside them does. It would move anti-goal to 5.5, material to
13 and coherence to 10.5 — which is a regression, not the rise the total shows. Four of its findings
were fixed the same day and `TASK_STATE.md` lists them; the rest are the work list.

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
| 06_unfolding | 256 | 4.10 | a folded letter opening: the packet, the flap standing with its shadow across the third below it, the creases catching light on the settled sheet |
| 07_feeling_landing | 421 | 6.74 | four feelings landing on the phone they reached, across three surfaces, with the pattern annotated on the timeline |
| 08_state_propagating | 502 | 8.03 | a mood, a message, a place, an availability and four feelings crossing between two phones |
| 11_chat_scroll | 300 | 4.80 | the thread thrown and coming to rest on its own physics |
| 15_authored_feeling | 364 | 5.82 | the vocabulary gone through family by family, ending on the couple's own, then sent and received |

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

## 4. What is left, in order of what it costs to close

Everything in this list is measured in `evidence/critics/4/`. The numbers are theirs; go and check
them before you act on any of it.

### 1. The app's own chrome is the forbidden shape (anti-goal, material)
The SETTINGS tab slab has a top edge with a standard deviation of **0.00 px over 266 columns**, an
interior of **1.20 grey levels** against 19-27 for the note paper beside it, and a drop shadow. It is
on ten of eleven stills, and the Us glance card at 708x163 is the same. The tabs are already
`Slip(torn: false, stock: 'index')`, so the window is not sampling the stock at a density that
survives being eighty-nine points wide — measure that before changing anything. This is the single
biggest anti-goal finding and it is in the furniture, which means it is in nearly every artifact.

### 2. Nothing in the chat hero casts a contact shadow (material)
With the near-black tear ink excluded, the desk's median luminance is **95.7-102.7 in every
direction at every distance from 2 to 120 px** from the paper. The notes are cut-outs pasted on a
photograph. The baked shadow is rendered (`blender/paper/tear_relief.py`) and `relief.json` records
how it registers, so something between the render and the screen is losing it. Two critics and the
completeness pass agree on this one.

### 3. Thirty per cent of frames cost a second to build (messenger)
243 of 809 frames cost **938-1651 ms** (median 1134) while the other 566 cost a median of 14 ms, and
the heavy ones cluster. The log says these are draw costs rather than a refresh rate, so it is a
paint that is being redone rather than a frame that is being missed. It is the difference between a
thread that scrolls and one that stutters.

### 4. Three of the five modules are never drawn (coherence)
`03_us.report.json` lists all five with their event counts — dates 81, todos 199, calendar 6,
rituals 53, shelf 12 — and the still shows two. A fifth module that is a directory and a line in a
registry is the brief's own test of the architecture, and the artifact has to show it.

### 5. DeskStamp is still not built (material, coherence)
About five hours on one core here, so every tab, stamp, module label and margin note is set in Teo's
handwriting and `app/pubspec.yaml` says so. `app/lib/regions/settings/notifications.dart` also has
seventeen arms for eighteen types, so the fifth module's `passed_on` falls through to a label made
out of its own id. Start the build at the beginning of a session, not the end.

### 6. The haptic channel is never exercised (emotional)
`sensation.channel` reads `page` in all fifteen reports. The row asks for a feeling identifiable by
its pattern with the screen face down, and nothing short of a phone will show that.

### 7. The search still is not evidence of searching (messenger)
`12_search.report.json` records no search at all. And 17_setup_pwa.png — the only evidence for the
installable-PWA half of the mission, and the home of 42 of the 115 strings the voice lint reads —
was opened by no critic in this cycle.

### 8. The seeded photographs are renders (anti-goal)
The darkest few read as exactly that. `blender/photos/` already models the lens, the sensor and the
phone's own processing; it is the scenes that are thin.

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

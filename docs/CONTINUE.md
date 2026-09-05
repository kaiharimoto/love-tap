# love-tap — continue the build

Read `docs/BRIEF.md` in the repository first, all of it. It is the mission and it is
authoritative: the rubric, the five categories with their weights and floors, the four
anti-goals, the seventeen evidence artifacts at their exact filenames, the family floors, the
three commands, and the secret constraints. Everything below is state, not instruction — where
this document and the brief disagree, the brief wins.

**Repository** `kaiharimoto/love-tap` · **branch** `claude/new-session-vxz721` (develop, commit and
push only here) · **working directory** `/home/user/love-tap`

Every reply must end with the fenced ```mpstate block the brief specifies (keys: v, task, phase,
step, cycle, score, next, blocked, ask).

---

## Where the build actually is

Two full review cycles have run. Cycle 2 was six fresh-context critics plus a completeness pass,
each measuring rather than asserting; their reports are in `evidence/critics/2/*.json` and the
arithmetic is in `evidence/SCORE.json`.

| category | critic | builder | taken | floor | weight |
|---|---|---|---|---|---|
| messenger reliability | 20 | 19 | **19** | 26 | 30 |
| material truth | 16 | 15 | **15** | 22 | 25 |
| emotional transmission | 6 | 7 | **6** | 17 | 20 |
| coherence | 10.5 | 11 | **10.5** | 13 | 15 |
| anti goal | 5.5 | 5 | **5** | 9 | 10 |

**55.5 / 95. No floor met.** Cycle 1 was 40. Two more complete cycles are required by the brief
(four or more in total); cycles 3 and 4 have not run.

Read `evidence/critics/2/` before doing anything else — those reports are the work list, and every
finding in them carries the measurement that established it, so each one can be checked and each
one can be shown fixed.

## What is captured, and what is not

Fourteen of seventeen artifacts exist in `evidence/`. `evidence/MANIFEST.json` and
`evidence/frames.json` list what is missing and why.

- **09_two_devices.png, 16_setup_android.png** — no `/dev/kvm` in this container. Three routes to a
  second screen have been tried and measured, and the measurements are in `docs/PHONES.md`: the
  x86_64 emulator under QEMU instruction emulation (reached `adbd` after 113 minutes, never the
  framework), a Linux desktop build (no GTK), and a `flutter_tester` render (fonts load, no
  material — `docs/far_screen_probe.png` is the output and the reason). The `android-34` system
  images were deleted to free 8.2 GB after a capture died on `ENOSPC`; `./bootstrap.sh` puts them
  back. On a host with `/dev/kvm`, or an ARM64 host where `arm64-v8a` runs natively, do that first.
- **13_messenger_states.png** — stale, four runs old. `__deskStage()` throws **only in the web
  build**; it passes in a widget test against the full seeded year. The handle now returns the real
  error text and four frames of stack (`app/lib/capture/hooks.dart`), so the next capture will name
  it instead of reporting `Dart exception thrown from converted Future`.
- **08_state_propagating.mp4** — captured, over the real tailnet, 488 frames. But see the emotional
  transmission findings: what it shows is wrong even though it ran.

## The fix list, in order of points on the table

### emotional transmission · 6 → 17 is the largest single gap
1. **A feeling arriving renders as the word "hold" in blue script** in `08_state_propagating.mp4`.
   The row's first sentence is that a gesture on one device becomes a *sensation* on the other.
   Find why the arriving `feeling` event renders through a text path rather than
   `object_landing` in `app/lib/regions/chat/renderers.dart`.
2. **Only four named families are visible** (WARMTH, ACHE, SHELTER, MISCHIEF) where the floor is
   five. The registry has more; the corner shows four.
3. **No haptic evidence exists anywhere in `evidence/`.** Thirty-plus feelings are meant to be
   identifiable by pattern alone with the screen face down and nothing in the set lets anyone check
   it. Write the per-feeling pattern out as evidence.
4. **Sending a feeling changes nothing** — two `sendFeeling` steps in the `07` log, and the recent
   row holds the same five objects in the same order throughout.
5. Feeling names in the picker at ~1.9:1 contrast; the drawer is translucent over the live page.
6. No designed non-haptic substitute is visible on the PWA path, which is the whole evidence set.

### material truth · 15 → 22
7. **The unfolding clip has no fold in it** — 281 of 320 frames are a flat cream rectangle, edge
   std 0.32. The fold frames were re-rendered for a z-fight and their *paper* was never measured.
   **`tools/check/surfaces.py` reads `paper/`, `shell/` and `objects/` and not `folds/`** — add it,
   then re-render `blender/folds/fold.py` with the tooth and fibre the paper stocks carry.
8. The note cross-fades in *after* the unfold finishes rather than during its settle, so the clip
   ends on blank paper. `Settling` in `app/lib/material/motion.dart` is the mechanism.
9. Repeated glyphs render pixel-identical (IoU 0.998) — the fonts carry contextual alternates and
   the renderer is not asking for them.
10. Tab tiles and two settings surfaces are flat fills.

### messenger reliability · 19 → 26
11. **Moments renders five "still fetching the picture." rows and not one thumbnail** — a
    regression from the masonry rewrite in `app/lib/regions/moments/moments_region.dart`.
12. Typing indication has no evidence: absent from every artifact and from the sixteen capabilities
    in `evidence/reliability.json`.
13. Every still was taken on a single unpaired device stuck in `connecting`, so `sent`/`read` are
    seeded values rather than an observed round trip.
14. Search result order is neither ascending nor descending; a result carries no visible reason.
15. The media viewer does not cover its own chrome, and its caption appears twice.

### anti-goal · 5 → 9
16. **A five-of-five star rating on a remembered date** in `03_us.png` — the canonical review widget
    attached to a shared memory. It is in `app/lib/modules/dates/dates_module.dart` (`Stars`).
17. Flat notes in two clips (same root as 7).
18. The desk texture may tile horizontally with a 605 px period — measure it; the plank pitch is by
    construction and may be what was seen.
19. The drawn feelings read as the standard emoji set to a fresh eye (a sun with rays, a crescent).

### coherence · 10.5 → 13
20. The same class of row draws as torn paper in one region and a hard rectangle in another.
21. Nine of eighteen event types name nine renderer ids that all resolve to one function.

## How to run it

    ./bootstrap.sh                                   # pinned toolchain into ./toolchain
    ./run.sh --seed=year --transport=local           # or --transport=tailscale
    ./capture.sh                                     # the whole evidence set, ~45 min
    ./capture.sh --only=02_chat --no-build           # one scene against the builds on disk
    cd app && ../toolchain/flutter/bin/flutter test  # 92 tests, all passing

Checks worth knowing, all wired into `capture.sh`: `tools/check/surfaces.py` (no rendered surface
is a flat fill), `tools/check/manifest.py` (every file in `assets/` names its generator),
`tools/check/recipes.py`, `tools/lint/strings.py` (every displayed string against `docs/VOICE.md`),
`tools/check/frames.py` (a clip is not a still).

Scoring: write your own sheet to `evidence/critics/<cycle>/builder.json` under a `scores` key
*before* reading the critics, then `python3 tools/score.py --cycle <n>`. It takes the lower of
critic and builder per category and refuses arithmetic that breaks the rule.

Run the critics as a Workflow — six agents in parallel plus a completeness pass. The prompts are in
`evidence/critics/prompts/*.md` and `evidence/critics/BRIEFING.md` says what a critic is given.
They must stay fresh contexts: tell them explicitly not to read the git log, the task list,
`docs/BRIEF.md`, or a previous cycle's reports.

## Things that cost hours, so that they cost you none

- **Anything on the wall clock is invisible in the evidence.** Under capture the app's clock is
  driven a frame at a time and screenshots are taken between steps, so a quarter-second of wall
  clock passes between two frames of a clip. `AnimatedOpacity`, `TweenAnimationBuilder`, any
  `AnimationController` — either not started or already finished at every frame that gets grabbed.
  Use `Turning` / `Settling` in `app/lib/material/motion.dart`, which follow `DrivenClock` when it
  is driving. `app/test/nothing_moves_on_the_wall_clock_test.dart` holds the line.
- **A test that passes with the bug put back is a claim, not a test.** Two in this build did.
  Always re-break the thing and watch the test fail.
- **`PaintingContext.paintChild` can leave the context on a different canvas** — a `saveLayer`
  before it and a `restore` after it land on two different ones. That silently disabled every tear
  mask in the app for a whole capture and then threw `call_indirect to a signature that does not
  match`.
- **A stale render looks exactly like a design decision.** The desk was a flat brown field for the
  entire build because `assets/shell/desk.png` predated the wood being finished; the albedo map was
  always right. Re-render before assuming the generator is wrong.
- **Check the artifact's mtime before reading it.** More than once I read a stale PNG and drew a
  conclusion about a fix that had not been captured yet.
- **Disk.** A clip is 300 full-resolution frames and there are five. `capture.sh` now refuses to
  start under 6 GB free, because running out mid-run reports itself as "ffmpeg refused the frames"
  and four artifacts missing for reasons that have nothing to do with the app.
- **The tailnet nodes survive a container restart.** Their state is in `toolchain/ts/{a,b}/state`;
  restart `tailscaled` with the same flags `tools/tailscale/up.sh` uses and they come back on the
  same addresses with no new auth key. `capture.sh` now probes the proxy port rather than trusting
  the address files.
- **`pkill -f <pattern>` will match your own shell** if the pattern text appears anywhere in the
  same command line. It killed three of my shells. Split the literal, or match on `ps` output.
- **Never edit a running bash script** — bash reads it incrementally and the run corrupts.

## Secrets, which are failure conditions

`TS_AUTHKEY`, a CA private key, or a pairing secret in any committed file fails the whole build.
The key is read from the environment and never written down; `toolchain/ts/AUTHKEY_STATUS` records
only the word `pending` or `supplied`. With no key the tailscale run is recorded as **pending** —
not passing, not failing. `ask=TS_AUTHKEY` may appear in the heartbeat only from the session in
which the Tailscale phase begins, which has already happened, so it may not appear again.

The host binds its tailnet address or does not start; spine content travels by no path other than
the Tailscale channel; a Web Push payload carries nothing beyond event kind and sender.

## User-side, still outstanding

Revoke the Tailscale auth key at `login.tailscale.com/admin/settings/keys`, and remove `lovetap-a`
and `lovetap-b` from the admin console — they were not registered as ephemeral, so they linger.

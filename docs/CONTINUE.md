# love-tap — continue the build

**Read `docs/BRIEF.md` first, all of it.** It is the mission and it is authoritative: the rubric,
the five categories with their weights and floors, the four anti-goals, the seventeen evidence
artifacts at their exact filenames, the family floors, the three commands, and the secret
constraints. Everything in this file is *state*, not instruction — where the two disagree, the
brief wins.

**Repository** `kaiharimoto/love-tap` · **branch** `claude/new-session-f95s8n` (develop, commit and
push only here) · **working directory** `/home/user/love-tap` · working tree is clean and pushed.

Every reply must end with the fenced ```mpstate block the brief specifies (v, task, phase, step,
cycle, score, next, blocked, ask).

---

## 1. Where the build is

Two review cycles have run. Cycle 2 was six fresh-context critics plus a completeness pass, each
measuring rather than asserting. Their reports are `evidence/critics/2/*.json`; the arithmetic is
`evidence/SCORE.json`.

| category | critic | builder | taken | floor | weight |
|---|---|---|---|---|---|
| messenger reliability | 20 | 19 | **19** | 26 | 30 |
| material truth | 16 | 15 | **15** | 22 | 25 |
| emotional transmission | 6 | 7 | **6** | 17 | 20 |
| coherence | 10.5 | 11 | **10.5** | 13 | 15 |
| anti goal | 5.5 | 5 | **5** | 9 | 10 |

**55.5 / 95, no floor met.** Cycle 1 was 40. The brief requires four or more complete cycles;
cycles 3 and 4 have not run.

`evidence/critics/2/` is your work list. Every finding carries the measurement that established it,
so each one can be checked and each one can be shown fixed.

## 2. What was fixed after cycle 2 was scored

These are done, committed, and **not yet re-captured** — the artifacts in `evidence/` still show
the old behaviour. Re-capturing is the first thing worth doing.

- **The five-of-five star rating is gone from the data model**, not just the pixels. A `date_event`
  carries a `verdict` — words — and no longer a `rating`; the twenty-five ratings in the seeded
  year were rewritten into sentences a person would say; the action is `said`, not `rated`.
- **A feeling arriving is an object landing.** Three mechanisms: it was being wrapped in
  `FoldedNote` (resting face = fold frame 0000, a blank cream slab nothing ever opens), its name
  was set in the author's hand at 19pt — byte for byte the message-body call — and `size` meant the
  420×420 frame rather than the object, so a candle drew at 29pt beside a crane at 82pt.
  `tools/pack_assets.py` now measures every object's ink and writes `object_ink` into the index.
- **The desk was a tiled repeating texture** — a named failure condition. `transform_apply` acts on
  *selected* objects and the desk was active but not selected, so it returned `{'CANCELLED'}`, the
  scale stayed on, and the UVs divided ±0.5 by 0.42: the three-plank top was tiled 2.381× across
  itself, in every artifact, for the whole build. Fixed and re-rendered; correlation at the old
  462px period is now −0.009 by day and −0.201 at dusk, and what remains is the plank pitch at
  367px with the three boards differing by ~14 grey levels.
- **A pending check no longer destroys evidence of a run that happened.** This session's real
  tailnet cold start was overwritten by "the nodes were not up" because a daemon got reaped between
  the run and the next `flutter test`. Two causes, both fixed: the tests asked the filesystem
  whether a node existed rather than asking the daemon, and the local half of the reliability run
  rewrote the file whole, deleting a tailnet block that was not its to delete.

92 tests pass.

## 3. What is left, in order of points on the table

### emotional transmission · 6 → 17 · the largest single gap
1. **Only four named families are visible** (WARMTH, ACHE, SHELTER, MISCHIEF) where the floor is
   five. The registry has more; the corner shows four.
2. **No haptic evidence exists anywhere in `evidence/`.** Thirty-plus feelings are meant to be
   identifiable by pattern alone with the screen face down, and nothing in the set lets anyone
   check it. Write the per-feeling pattern out as evidence — duration, envelope, a strip.
3. **Sending a feeling changes nothing** — two `sendFeeling` steps in the `07` log and the recent
   row holds the same five objects in the same order throughout.
4. Feeling names in the picker measure ~1.9:1 contrast; the drawer is translucent over the live
   page rather than opaque.
5. No designed non-haptic substitute is visible on the PWA path, which is the whole evidence set.

### material truth · 15 → 22
6. **The unfolding clip has no fold in it** — 281 of 320 frames are a flat cream rectangle, edge
   std 0.32. **`tools/check/surfaces.py` reads `paper/`, `shell/` and `objects/` and not `folds/`**
   — 94 of the 240 fold frames are below the paper floor of 1.2. Add the family, then re-render
   `blender/folds/fold.py` with the tooth and fibre the paper stocks carry.
7. The note cross-fades in *after* the unfold finishes, so the clip ends on blank paper. `Settling`
   in `app/lib/material/motion.dart` is the mechanism; start it during the settle.
8. Repeated glyphs render pixel-identical (IoU 0.998). The fonts carry contextual alternates and
   `Hands` asks for `calt` — establish whether the TTFs actually contain the variants
   (`fontTools`, or read `tools/handwriting/`). This one was never diagnosed; the agent hit a
   usage limit.
9. Tab tiles and two settings surfaces are flat fills.

### messenger reliability · 19 → 26
10. **Moments renders five "still fetching the picture." rows and no thumbnail.** Diagnosed: the
    masonry rewrite replaced `GridView.builder` with a `SingleChildScrollView`, which has no lazy
    child model, so all 183 media tiles materialise at once — 129 concurrent IndexedDB reads during
    one build, and `Image.memory` with no `cacheWidth`, decoding a 1000×750 photo at full size for
    a 150pt chip. Put the viewport bound back: `_Gallery` already computes each tile's height, so
    it knows each tile's `top`; build only what intersects the viewport plus a cache extent.
11. **Typing indication has no evidence** — absent from every artifact and from the sixteen
    capabilities in `evidence/reliability.json`.
12. Every still was taken on a single unpaired device stuck in `connecting`, so `sent`/`read` are
    seeded values rather than an observed round trip.
13. **13_messenger_states is still missing.** `__deskStage()` throws *only in the web build*; it
    passes in a widget test against the full seeded year. The handle now returns the real error and
    four stack frames, so the next capture will name it.
14. Search result order is neither ascending nor descending; one result carries no visible reason.
15. The media viewer does not cover its own chrome, and its caption appears twice.

### anti-goal · 5 → 9
16. Flat notes in two clips — same root as 6.
17. The drawn feelings read as the standard emoji set to a fresh eye (a sun with rays for
    `forehead`, a crescent for `warm palm`).

### coherence · 10.5 → 13
18. The same class of row draws as torn paper in one region and a hard rectangle in another.
19. Nine of eighteen event types name nine renderer ids that all resolve to one function.

### Not fixable here
**09_two_devices.png and 16_setup_android.png.** No `/dev/kvm`. Three routes tried and measured in
`docs/PHONES.md`: the x86_64 emulator under QEMU instruction emulation (reached `adbd` after 113
minutes, never the framework), a Linux desktop build (no GTK), and a `flutter_tester` render (fonts
load, no material — `docs/far_screen_probe.png` is the output). The `android-34` system images were
deleted to free 8.2 GB after a capture died on `ENOSPC`; `./bootstrap.sh` puts them back. On a host
with `/dev/kvm`, or ARM64 where `arm64-v8a` runs natively, do that first and these two are cheap.

## 4. How to run it

    ./bootstrap.sh                                    # pinned toolchain into ./toolchain
    ./run.sh --seed=year --transport=local            # or --transport=tailscale
    ./capture.sh                                      # the whole set, ~45 min
    ./capture.sh --only=02_chat --no-build            # one scene against the builds on disk
    cd app && ../toolchain/flutter/bin/flutter test   # 92 tests

Checks, all wired into `capture.sh` before it takes a screenshot: `tools/check/surfaces.py` (no
rendered surface is a flat fill — **add `folds`**), `tools/check/manifest.py` (every file in
`assets/` names its generator), `tools/check/recipes.py`, `tools/lint/strings.py` (every displayed
string against `docs/VOICE.md`), `tools/check/frames.py` (a clip is not a still).

**Scoring.** Write your own sheet to `evidence/critics/<cycle>/builder.json` under a `scores` key
*before* reading the critics, then `python3 tools/score.py --cycle <n>`. It takes the lower of
critic and builder per category and refuses arithmetic that breaks the rule.

**Running the critics.** Use the Workflow tool: six agents in parallel plus a completeness pass
asking what the six missed. `evidence/critics/prompts/*.md` are the rubric rows and
`evidence/critics/BRIEFING.md` says what a critic is given. They must stay fresh contexts — tell
them explicitly not to read the git log, the task list, `docs/BRIEF.md`, or a previous cycle's
reports. Cycle 2 cost ~1.2M subagent tokens and 583 tool calls and was worth every one of them.

## 5. Things that cost hours here, so that they cost you none

- **Anything on the wall clock is invisible in the evidence.** Under capture the app's clock is
  driven a frame at a time and screenshots are taken between steps, so a quarter-second of wall
  clock passes between two frames of a clip: an implicit animation is either not started or already
  finished at every frame that gets grabbed. Use `Turning` / `Settling` in
  `app/lib/material/motion.dart`. `app/test/nothing_moves_on_the_wall_clock_test.dart` holds it.
- **A test that passes with the bug put back is a claim, not a test.** Two in this build did.
  Always re-break the thing and watch it fail.
- **The filesystem is not the daemon, and the address file is not the node.** That same stale-state
  trap bit three times: `capture.sh`, `coldstart_test.dart`, `reliability_test.dart`.
- **`PaintingContext.paintChild` can leave the context on a different canvas** — a `saveLayer`
  before it and a `restore` after it land on two different ones. That silently disabled every tear
  mask in the app for a whole capture, then threw `call_indirect to a signature that does not
  match`.
- **A stale render looks exactly like a design decision.** The desk was flat for the entire build
  because the plate on disk predated the wood being finished. Re-render before blaming a generator.
- **Check an artifact's mtime before reading it.** I twice drew a conclusion from a PNG that
  predated the fix I was checking.
- **Disk.** A clip is 300 full-resolution frames and there are five. `capture.sh` refuses to start
  under 6 GB free, because running out mid-run reports itself as "ffmpeg refused the frames" and
  four artifacts missing for reasons that have nothing to do with the app.
- **The tailnet nodes survive a container restart but not much else** — they get reaped. Their
  state is in `toolchain/ts/{a,b}/state`; restart `tailscaled` with the flags
  `tools/tailscale/up.sh` uses and they return on the same addresses with no new key.
- **`pkill -f <pattern>` will match your own shell** if the pattern appears anywhere in the same
  command line. It killed three of mine. Split the literal.
- **Never edit a running bash script** — bash reads it incrementally and the run corrupts.

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

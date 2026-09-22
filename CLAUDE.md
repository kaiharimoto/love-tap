# love-tap

Two people, one thread of paper. An Android app and an iOS-installable PWA from one Flutter
codebase, talking directly to each other over Tailscale. `README.md` is the shape of it.

This repository is built by an autonomous loop. If you are a firing of that loop,
`loop/WORKER_PROMPT.md` is your running order, `docs/LOOP.md` is the machine behind it, and
`loop/STATE.json` is where you are. If you are a person, everything below applies to you too.

## The owner's steer, which outranks everything below

2026-09-19, verbatim:

> "I made the mistake of asking for too many demo populated items, if that's what they're stuck on.
> Those aren't important because it's using it and the UI that matters more."

**Using it, and the UI, come first.** Populated demo media — the sixteen absent photographs, the
seeded year's videos and voice notes — is explicitly not important. Evidence plumbing that exists
only so the scoring harness can score itself is not important either; thirteen of the forty open
queue items at firing 20 were that. Fix a ruler only when you cannot see without it.

The accepted cost, stated plainly so no firing re-litigates it: deprioritising demo media **caps
`messenger_reliability`, the heaviest rubric row**. The score will stall while the app gets better
to use. That is the instruction working, not the loop failing. Do not re-promote a demo-content
item to lift a number.

Every open item in `loop/STATE.json` carries an `owner_priority` tag — `using-it`, `the-ui`,
`harness`, `deprioritised-demo-content` — and the queue is ranked by it. `loop/WORKER_PROMPT.md`
§3c is the long form.

## Read in this order

1. `docs/BRIEF.md` — **authoritative**. The mission, the rubric, the anti-goals, the evidence set,
   the coverage floors. Where anything disagrees with it, it wins — except the owner's steer
   above, which outranks it. It is 85 KB; read it whole in a stage that judges or plans, and skip
   it in a stage that is executing one named item.
2. `DIRECTION.md` — the design law, and its dated decisions log. `docs/COLOR.md` when it exists is
   the colour half of the same law and takes precedence on anything it covers.
3. `loop/STATE.json` — the cycle, the stage, the queue, what is blocked.
4. `loop/WORKER_PROMPT.md` — what one firing does, in order. Read this first if you are a firing.
5. `docs/LOOP.md` — the machine: the five stages, the degradation ladder, the state schema.
6. `TASK_STATE.md` and `docs/CONTINUE.md` — the prose handoff. `CONTINUE.md` §5 is a list of
   things that cost this build hours. Read it before you spend a day rediscovering one of them.

## The branch

Develop, commit and push **only** to `claude/app-improvement-autonomous-workflow-d6fwdu`.

Never push to `main`. Never open a pull request. Never merge. Never force-push, and never rewrite
history that has been pushed. Check the branch before every push, not once at the start.

## The things that are never done here

- **Never hand-edit anything in `evidence/`.** An artifact comes out of `./capture.sh` or it is
  recorded as missing with the reason. Retouching one is falsifying the only measurement this
  build has of itself.
- **Never score a category above its critic.** `tools/score.py` takes the lower of the two and
  refuses arithmetic that breaks the rule. Write your own sheet *before* you read theirs.
- **Never claim a fix without the measurement that shows it.** A test that passes with the bug put
  back is a claim, not a test — re-break it and watch it fail.
- **Never commit a secret.** `TS_AUTHKEY`, a CA private key or a pairing secret in any committed
  file is a stated failure condition for the whole build. The key is read from the environment and
  never written down.
- **Never skip, disable or delete a test to get green.**
- **Never `git fetch origin` bare** — it hangs in this container, where the repo is 552 MB of git
  objects and the bare form walks every ref. `git fetch origin <branch>` answers in seconds. A dry-run
  push rejected `non-fast-forward` means the checkout is behind, not that the credential is missing.
- **A blender generator writes `assets/MANIFEST.json` even when `--out` points elsewhere.** A throwaway
  comparison render leaves entries whose paths climb out of the repo; `git checkout -- assets/MANIFEST.json`
  after one.
- **Never trust the copy of this file you were handed in your opening context.** It is read from the
  commit the container checked out, which has been fifty commits behind the branch before. Re-read
  it from the tree after `loop/WORKER_PROMPT.md` §0's fast-forward, and check any "does not exist"
  with `ls`.
- **Never edit a running bash script** — bash reads it incrementally and the run corrupts.
- **Never `pkill -f <pattern>`** where the pattern appears in your own command line. It has killed
  three sessions here. Split the literal.

## The three commands, and what they cost

    ./bootstrap.sh                                 # the pinned toolchain into ./toolchain
    ./run.sh --seed=year --transport=local         # build, install, serve
    ./capture.sh                                   # the whole evidence set, ~45 min, needs 6 GB free

In a fresh container, **`bootstrap.sh` is not sufficient on its own**: Playwright's WebKit needs
system libraries it can check for and cannot install. Run `bash tools/apt-prereqs.sh` first or
there is no capture at all. `bootstrap.sh --profile=web` skips the Android SDK, the NDK and the
AVD, which are 2.1 GB and several minutes and buy nothing without `/dev/kvm`.

**And `bootstrap.sh` itself now fails partway, quietly, on a fresh container.** The pinned static
ffmpeg URL answers 200 with 7.3 KB of HTML from a JS interstitial, `tar` rejects it, and the script
is `set -e` — so it stops at ffmpeg and never reaches **tailscale or Playwright WebKit**, which is
no capture at all rather than a missing clip. Read `toolchain/.done/` after bootstrapping, not the
exit code: it must hold `playwright`. `docs/CONTINUE.md` §5 has the four lines that fix it.

Everything else worth knowing about running it is in `docs/CONTINUE.md` §4–§5.

## Known dead ends, so nobody spends a firing on them

- **`.github/workflows/build.yml` cannot pass on any branch.** Both jobs open with a guard
  requiring `tools/pack_pwa.py`, `tools/release_notes.py` and `tools/check/apk.py`; none of the
  three has ever been committed. Do not chase a red CI run there unless a queue item says to.
- **`tools/check/texture_budget.py` exists now**, and `DIRECTION.md`'s claim that it enforces the
  WebKit texture budget recorded in `TASK_STATE.md` is true as of cycle 3. It reads the budget from
  `TASK_STATE.md`, the window from `app/lib/material/fold.dart` and the frames from
  `app/assets/folds`. Two things worth knowing before trusting it: the 32 MB ceiling is a design
  budget rather than a device measurement, because no phone has been available to measure WebKit
  on; and the figures that stood in `TASK_STATE.md` for four cycles under the words "measured
  rather than guessed" described a sequence that is not in the repository.
- **A Routine cannot deliver a firing directly.** A session a Routine mints gets `sources: []`,
  and with no attached repository the egress proxy injects no push credential, so every `git push`
  returns 403. Two firings established this; the first lost seven minutes of work to it. The loop
  is delivered instead by a Routine that wakes **the session that created it**, and that session
  spawns the firing with `create_session`, which can attach a repository. A Routine bound to some
  *other* named session does not work either: the one that was tried never woke, because its
  container had been reclaimed and the wake did not re-provision it. `docs/LOOP.md` has the full
  table of what was tried. Do not try to "fix" a firing that cannot push by cloning the repo
  yourself; a clone is readable and unpushable, which is the trap.
- **`09_two_devices.png` and `16_setup_android.png` cannot be produced in this container.** No
  `/dev/kvm`; three routes were tried and measured, and `docs/PHONES.md` records all three. That
  is a hardware fact, not a loop defect. **15 of 17 is the ceiling here**, and firings 12 and 16
  have both reached it; the 14 this line used to claim was one out.

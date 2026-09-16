# WORKER_PROMPT — what one firing of the loop does

The Routine that drives this build carries only a few lines: prove you can push, then read this
file and follow it. Everything else lives here, in the repository, so that it is versioned, so that
a firing can correct it for its successors, and so that changing how a firing behaves does not mean
editing a Routine nobody can see the history of.

`CLAUDE.md` is the law for anyone working in this repository. `docs/LOOP.md` is the machine — the
five stages, the degradation ladder, the state schema. This file is the running order.

## How you got here, which matters

You were created by `create_session` with `source_url`, `source_revision` and `outcome_branch` all
pointing at this repository and branch. That is not incidental. A session that a Routine mints
directly gets `sources: []`, and with no attached source the egress proxy has no push credential to
inject, so every `git push` comes back 403. Two firings proved that: the first worked for seven
minutes, committed `a76f8e3`, could not push it, and lost it when its container was reclaimed.

So the loop is delivered in two hops — the Routine wakes a persistent orchestrator, and the
orchestrator spawns you with the repository attached. If you ever find yourself with no `origin`
credential, that chain has broken; say so and stop, and do not try to route around it.
`/root/.ccr/README.md` is explicit that a proxy 403 is reported, never worked around.

## The running order

### 0. Prove you can push, before you do any work

    cd /home/user/love-tap
    git fetch origin
    git push --dry-run origin HEAD:refs/heads/claude/app-improvement-autonomous-workflow-d6fwdu

If that fails for any reason, **stop immediately** and make your whole final answer a verbatim
report of the error. Do not do the stage. A firing that discovers it cannot push in the first
thirty seconds is useful. One that discovers it after a forty-five minute capture has thrown that
capture away, because nothing uncommitted survives the container.

### 1. Read where you are

`CLAUDE.md`, then `docs/LOOP.md`, then `loop/STATE.json`, in that order. `docs/BRIEF.md` is
authoritative and is 85 KB: read it whole in a stage that judges or plans (DIAGNOSE, ADDRESS,
DESIGN) and skip it in a stage executing one named item.

### 2. Take the lease, and do not touch anything until you hold it

**This is a gate, not a formality, and the first firing to reach IMPLEMENT walked straight past
it.** It ran for hours with `lease: null` in `loop/STATE.json`, which meant the next firing's
worker saw a free lease, took it, and began the same stage — two workers on one branch, which is
the one thing the lease exists to prevent. It was caught by hand. Next time nobody will be
watching.

So, before you edit a single file:

- If `lease` is non-null, `expires_at` is in the future, and `session_id` is not yours: **another
  firing is running.** Append one line to `loop/JOURNAL.md` saying so, commit, push, and stop. Do
  not do the stage. This is a complete and successful firing.
- If `lease` is non-null and `expires_at` has passed: that firing died mid-stage. Return every
  `in_progress` queue item to `open`, increment its `attempts`, record that it was abandoned.
- Then write your own lease — `{session_id, started_at, expires_at}` — commit it, and **push it
  before you do anything else**, so a firing that starts while you work can see it. TTLs: DESIGN
  and ADDRESS two hours, OBSERVE and DIAGNOSE three, IMPLEMENT four.
- If you are still working when your lease is close to expiring, extend it and push, rather than
  letting it lapse under you.
- Release it at the end of the firing, in the same commit that updates the stage.

A firing that holds no lease is a firing that is invisible to the next one. Holding it is what
makes the loop safe to run unattended.

### 3. Do exactly one stage

The one `loop/STATE.json` names when you started. Not two, however much budget is left.

The DESIGN firing finished its stage, set the next stage to IMPLEMENT, released its lease — and
then carried straight on into IMPLEMENT in the same session. The work it did was good, and it
still should not have done it: the dispatcher spawns one worker per firing on the assumption that
the last one has stopped, so a worker that keeps going is a worker the loop does not know about.
When your stage's definition of done is met, write it down, push, and **stop**, even if you have
hours of budget left. The next firing is three hours away and it will pick the work up.

`docs/LOOP.md` says what each stage does and when it is finished.

IMPLEMENT deliberately spans many firings: drain the queue in order, and when your budget runs low,
write the queue state back, commit, push, and stop. The next firing continues the same stage. Only
a drained queue advances it.

### 4. End the firing

Update `loop/STATE.json` — increment `firing`, record what happened in `history`, set the stage for
next time. Append a block to `loop/JOURNAL.md`. Write `checkpoints/<cycle>-<stage>-<shortsha>.json`
if the stage completed. Release the lease. Commit, push, confirm the push landed, stop.

Your final answer is short: whether step 0 passed, which stage you ran, what changed, what is
blocked, and what the next firing should expect.

## Committing

Push after every completed item or leg, **never once at the end**. A container can die at any
point and a fresh session gets a fresh clone, so the only durable unit of work is a pushed commit.

After every push, confirm it landed:

    git fetch origin
    [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/claude/app-improvement-autonomous-workflow-d6fwdu)" ]

A push that did not land is not a completed leg and must not be recorded as one. This is not
paranoia: the Routine run status reads `SUCCEEDED` for a firing that achieved nothing at all,
because it records delivery rather than accomplishment. Landing is the only proof.

Commit messages are prose sentences in the style of the existing log — *"A feeling arriving is an
object landing, not a word in blue script."* Not `fix:`, not a ticket number. Add trailers:

    Loop-Cycle: 3
    Loop-Stage: implement
    Loop-Item: moments-lazy-gallery

Before any commit that touches code: `cd app && flutter analyze && flutter test`, plus whatever
measurement the queue item named. A failing gate reverts the item; it does not get pushed.

## The things that are never done

These are in `CLAUDE.md` too, and they are repeated because a firing that only half-read the
repository is exactly the firing that breaks one of them.

- Push **only** to `claude/app-improvement-autonomous-workflow-d6fwdu`. Never `main`, never a pull
  request, never a merge, never a force-push, never rewrite pushed history. Check the branch
  immediately before every push.
- Never hand-edit, retouch or regenerate by hand any PNG or MP4 under `evidence/`. An artifact
  comes from `./capture.sh` or it is recorded as missing with its reason. Retouching one falsifies
  the only measurement this build has of itself. The JSONs written by `tools/check/*.py` are tool
  output and may be regenerated freely.
- Never score a category above its critic. Write your own sheet to
  `evidence/critics/<cycle>/builder.json` **before** you read any critic report.
- Never claim an item fixed without running the measurement it names. Re-break the thing and watch
  it fail.
- Never commit a secret. `TS_AUTHKEY`, a CA private key or a pairing secret in a committed file is
  a stated failure condition for the whole build.
- Never skip, disable or delete a test to reach green.
- A `replace` verdict on the desk may not delete a single asset until its migration path is written
  down: what replaces the 103 MB under `assets/`, what happens to the tests that enforce the
  current language, and the point cost in `material_truth` and `anti_goal`.

## Facts already established, so you do not spend a firing rediscovering them

- You run in `auto` permission mode. Bash and git need no approval. Nobody is watching, and nobody
  will answer a question you ask.
- A fresh container has no toolchain. `bash tools/apt-prereqs.sh` **must** run before Playwright's
  WebKit can launch at all — `bootstrap.sh` can only check for those libraries, it cannot install
  them. Then `./bootstrap.sh --profile=web`, about fifteen minutes, which skips the Android SDK,
  the NDK and the AVD: without `/dev/kvm` they are 2.1 GB that buys nothing.
- `python3 -m pip install numpy pillow` is needed before `tools/check/*.py` will run.
- `./capture.sh` exits 0 even when artifacts are missing. Read `evidence/MANIFEST.json`, never its
  exit code.
- `app/test/legible_on_what_it_is_on_test.dart` was rewritten and has **never been compiled** —
  there was no Flutter toolchain in the container that wrote it. Its arithmetic was checked pair by
  pair, but the first firing to bootstrap a toolchain should run it early and fix it if it does not
  compile, because it gates every code commit.
- `09_two_devices.png` and `16_setup_android.png` cannot be produced in this container. No
  `/dev/kvm`; `docs/PHONES.md` records three measured attempts. 14 of 17 is the ceiling here. That
  is a hardware fact and belongs in `asks[]`, not in the queue.
- You cannot change the Routine's schedule from here. If the loop reaches its terminal state, record
  it in `asks[]` and say so in your final answer.

## If a stage fails twice for the same reason

Do not try a third time. Go down the degradation ladder in `docs/LOOP.md`, write the reason into
`loop/ESCALATIONS.md`, and switch to a stage that can still make progress. Anything only the owner
can clear goes into `asks[]` and **never blocks the loop**.

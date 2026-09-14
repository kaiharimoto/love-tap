# CONTINUE

The state handed to the next session. `docs/BRIEF.md` is the mission and wins over this file.
Branch: `claude/new-session-f95s8n`.

## The goal changed: a build in their hands

The owner's instruction, mid-session: *"I'd say paper texture is good enough. Let's focus on
everything else and finish this so I can test it and give feedback."* So the brief's 95-with-every-
floor exit condition is not what the work is aimed at any more. What is aimed at is two phones with
this on them. Dropped on that instruction, and not to be picked back up without being asked:
ruled-line alignment, the three untextured feeling objects, the contact-shadow overshoot, any
further tear-library work, and 09/16 as a scoring concern.

What that turned up, in the order it was found:

**The scroll's real cost, fixed and measured.** `tearFor` stepped through all forty-seven writable
tears; each note decodes three images (silhouette, lit edge, contact shadow) against a forty-eight
entry `MaskCache`, so a fling walked a hundred and forty-one images through a cache of forty-eight
and every note that came into view evicted one that was about to arrive.

    pool 47, cache 48   886 frames  p50 9 ms  p95 781 ms  196 over 400 ms  396 masks dropped
    whole pool cached   630 frames  p50 4 ms  p95  31 ms    1 over 400 ms    0 masks dropped

Holding all of them costs about 334 MB of decoded alpha (1024 x 578 x 4 a mask), which is not a
trade to make on a phone. `kTearsInPlay = 16` is sixteen tears, forty-eight images, the cache
exactly; the brief's rule is about tears visible *at once* and the coprime stride puts a repeat
sixteen notes away, off the bottom of any phone.

**The iPhone had nothing to install.** This is the one that mattered. `docs/PHONES.md` step 4 says
to open the host's address in Safari and add the page to the home screen; `main.dart` never passed
a bundle to its own server, so `_serveStatic` answered 404 to every GET and the whole client half
of the product had no way to exist. Nothing failed anywhere — the setup list went on ticking the
step. Now `tools/pack_pwa.py` packs the web build (minus the material library, which the phone
already holds) into Android's own assets, `lovetap/pwa` reads it back off the platform thread,
`pwa_assets.dart` joins the two asset layouts, and `tools/check/apk.py` fails a build that does not
carry it. The pairing field defaults to the page's own origin instead of a loopback address that
could never be right on a phone.

**The 401 was my own misreading**, not a defect — see the strikethrough in section 4.

**The APK that exists.** `evidence/logs/apk.json`: 101.8 MB, arm64 only, `CN=love-tap` rather than
`CN=Android Debug`, carrying `assets/pwa/index.html`, canvaskit and `push/sw.js`. Built from
`app/assets` packed **without** the seed. The keystore that signed it was handed to the owner and
is not in this repository and never was; a later build signed with a different key cannot replace
it on the phone without uninstalling, which takes the log, so that file is the thing to ask them
for rather than to make again.

**The largest thing still missing: the host only serves while the app is open.** There is no
foreground service. The Dart isolate that holds the log, the HTTP server and the certificate is the
Activity's, so the Android phone answers the iPhone while somebody has it open and not while it is
in a pocket. Nothing is lost — both phones keep what they wrote and the cursor catches up — but it
is not live unless both are awake, which is not what "a complete messenger" means. Written down in
`docs/PHONES.md` under *While the app is open, and not after*. Build it before anyone relies on a
message arriving while their phone is face down.

## Release readiness, which is now part of the goal

The goal was extended mid-session: past the brief's 95 with every floor met, to *ready to release
and test on real devices*. What that turned up, and what is left.

**Three things the Android project still carried from Flutter's template**, all fixed and all
covered by `app/test/nothing_leaves_the_phone_test.dart`:

- The release build was signed with the **debug key**, with the template's TODO above it. It reads
  `android/key.properties` now — gitignored with every `.jks` and `.keystore`, no defaults — and a
  build without that file signs with debug and *says so at build time*. A debug-signed APK installs
  and is not a release: a real key cannot replace it without uninstalling, which takes the log.
- The log was being **backed up to the owner's Google account**, which is Android's default. Off in
  all three places (`allowBackup`, `@xml/nothing_leaves`, `fullBackupContent`), and the extraction
  rules exclude the phone-to-phone transfer as well as the cloud — a transfer would put a working
  copy of the log and the pairing key on a handset nobody paired.
- **Cleartext was allowed**, on an app that serves over TLS to a tailnet address and nowhere else.

**`docs/PHONES.md` gained the half that was missing**: making the signing key, building the APK,
getting it onto the handset, how the iPhone adds the web app from the Android phone's own address,
what Safari's certificate warning is and why accepting it once is right, and what the in-app
checklist is for.

**What is verified and what is not.** The PWA's install path is complete and recorded in
`evidence/logs/pwa.json` — manifest with `display: standalone`, four icons, apple-touch-icon,
service worker registered, and the three Apple meta tags in the shell. The setup checklist observes
facts off the object graph and stores nothing, so a tick cannot survive the thing it watched going
away.

**The release path has now been exercised rather than described.** A throwaway RSA key was
generated into /tmp, used to sign an arm64 APK, and the key, the keystore and `key.properties` were
destroyed straight after; `tools/check/apk.py` reads the signer, the ABIs and the asset weight out
of whatever APK is on disk and fails on `CN=Android Debug`. Default build: 145 MB across three
ABIs. `--split-per-abi --target-platform android-arm64`: 106 MB, of which 84 is the material
library. Both numbers are in `evidence/logs/apk.json` with the distinguished name that says the key
was a throwaway.

**And the host actually serves over TLS**, which it did not before and which the checklist claimed
it did. `HostBind` had carried a `securityContext` since the protocol was written and nothing ever
passed one; the setup step called "trust the certificate the other phone holds" ticked on
`state == connected`, which a connection with no certificate in it satisfies perfectly. The phone
makes a 2048-bit key at first start, signs itself a certificate for the tailnet address it is
actually serving on, and keeps both in the app's own storage — which the manifest already excludes
from the cloud backup and the phone-to-phone transfer. The client pins the certificate it saw on
the wire during pairing, because two people in one room saying six words out loud is the one moment
trust-on-first-use is honest. One small listener stays in the clear on the port above, serving the
setup page and the configuration profile and 404ing everything else: behind the certificate, the
page that exists to get the certificate trusted would itself be untrusted, and teaching somebody to
click through that warning on their own phone is worse than serving a public key in the open.

Two things turned on that and neither was cosmetic. A page served over http at a 100.64/10 address
is not a secure context, so Safari gives the iPhone no `navigator.serviceWorker` at all and the push
ambient surface cannot exist; and a checklist that can tick for a thing that did not happen is worse
than one step short.

**What is still not verified, and cannot be here:** no artifact shows an Android or an iOS device.
09 and 16 need a handset, `docs/PHONES.md` measures the three routes tried, and the reception scene
is a Chromium banner on a Linux virtual display, which its own log says.

## 0. Where it stands

**Cycle 13 scored 75, up from 74, with no floor met**: messenger 21/30 (floor 26), material 18/25
(22), emotional 16/20 (17), coherence 12/15 (13), anti-goal 8/10 (9), code 13/15 (13, met, folded
into coherence). Eight reports, in `evidence/critics/13/`, including the builder's own sheet, which
scored three rows lower than the critics did and claimed 84.

**One point, for a cycle that closed both of the last one's blocking messenger findings.** They are
closed on the artifacts, not argued: the message that crossed the disconnect twice arrives once
(`said_again` null, 8,078 → 8,080 rows for two lines, against +4 for the same two), and the four
rows that painted nothing paint (118 image rows under 12 per cent paper against 1,503; all seven
rows at 44 to 58 per cent of their boxes against 0.000). The whole tear library was regenerated and
reads 4.50 px rms median on the edges the generator actually tore, six of fifty-six under 2, thirty
inside the band a critic was content with. The contact shadow went from absent — 3.6, 0.05, −0.17
and −1.64 grey levels against a floor of 6 — to 15.0 to 24.6 on all ten stills.

The score barely moved because the critics moved. What they measured this time was the scroll's
paper cost, the writing against the printed rules at three hundred per cent, and a feeling object I
put on screen myself — none of which anybody had measured before, and all of which are harder than
what came off the list.

**Three of the six blocking findings are this cycle's own doing**, which is the thing to carry
forward rather than the number:

- *The scroll costs paper.* 196 of 886 fling frames over 400 ms of the app's **own** build time,
  p95 781, max 1,087. A frame drawing two paper pieces costs a median 654 ms against 3 ms for one
  drawing none — correlation 0.788 with `pieces_drawn`, −0.122 with `rows_built`, so it is the paper
  pipeline and not the container's missing GPU. The set's own control measured the identical fling
  at p95 34 ms. This cycle took `SlicedMasks.fitFor`'s room to stretch in from four fifths to a
  half, which makes the shrink factor vary more from piece to piece, and a nine-patch is composed
  into one image per distinct size. **That is a hypothesis with a number attached, not a diagnosis:
  measure the composition cache's hit rate before changing anything.**
- *`overwhelmed` is a flat-shaded low-poly mesh*, 33,389 pure-white pixels at zero local variance in
  149 of 07's 392 frames. The twelfth cycle had already named three feeling objects as untextured
  forms; this cycle re-rendered none of them and then filmed one, as the seventh take it added.
- *The writing does not sit on the ruled lines.* Measured, designed, deferred — and the deferral
  cost the material row its floor, which is the right outcome.

**Four checks were found measuring the wrong thing this cycle, and the fourth was mine.**
`torn.py` reported the sheets' own guillotined edges as the library's roughness; the Dart copy of
`holes.py`'s walk never got its fringe fix; the seam gate was the old library's roughness rather
than a fact about seams; and `lines.py` found every other printed rule and called the gap a pitch —
161.0 px where the rules are 80.5 apart, which is the number the material critic's blocking finding
rested on. All four are fixed. Against the corrected grid the hero reads **0.491 of a pitch off**,
where 0.5 is exactly between two rules: worse than the file used to claim, not better.

**Two claims of mine the completeness pass overturned.** It reversed a correction I had accepted
from the material critic — the hero's written-line pitch is 80.3 px against an 80.7 px rule pitch,
one line per rule, so the fault is a phase offset after all and my first reading was right. And a
sentence in eleven scene files and in the briefing said the hero holds eight notes where this
capture's own report says five; all twelve now say five and name the shortfall as a shortfall.

### A review has to be of something that is not moving

Cycle 11's completeness pass caught this session rewriting twelve paths while that review still
stood. Cycle 12 was taken against a frozen tree: the builder's sheet was written first, the six
critics and the completeness pass ran with nothing else touching the repository, and each report was
committed as it landed.

## 3. Cycle 12, which is what the fifteenth capture answered

Eleven changes, and the two largest are corrections to things an earlier cycle had already called
fixed.

**The contact shadow, twice.** The eleventh capture is the first to run holes.py's contact-shadow
term, and eight of the ten stills failed it. Two separate faults, and the first is the instrument's.

*The check was measuring the paper.* It walks down each column, finds where a run of paper ends,
and compares the desk four to fourteen pixels below it with forty-five to sixty-five. A torn edge
in this build is about a centimetre of loose strands at phone scale, so a column stops reading as
paper at the first gap between two fibres and stays in the fringe for a long way after that — and
on any sheet the first few pixels past that point are still the antialiased edge, which is brighter
than the desk and cancels whatever is under it. The near band starts where the fringe ends now:
walk down until the column comes within six levels of what the desk reads far below. On the
eleventh capture's own stills that takes eight failures to one — 01_pulse −0.17 → 7.25, 02_chat
2.64 → 6.14, 12_search 0.05 → 7.63, 04_moments −1.64 → 4.68, which is the one still short. The
correction is conservative by construction: the band it moves to is further from the paper, so it
can only lose shadow.

*And the shadow was the wrong render.* `<tear>_shadow` came out of Blender beside the mask, and
measured over all 56 packed tears its alpha is 0.095 at the paper's own edge and gone within two
per cent of the piece: in the render the sheet lies nearly flat and its shadow is genuinely
underneath it, where opaque paper covers it. Framing it by its frame showed nothing; mapping it by
its paper so the tail fell outside the sheet showed a wide faint wash — the desk forty-five to
sixty-five pixels below a sheet went from 88.5 to 78, the reference band itself going into shadow.
`tools/bake_tear_shadows.py` makes it from the mask instead — the silhouette that actually casts
it — with `_CutShadow`'s two passes and its own numbers, nine-sliced by the tear's own bands so the
offset and the blur keep the size they were baked at however tall the sheet turns out to be. Baked
rather than painted because two blurred layers per piece and sixty pieces in a scroll's window is a
hundred and twenty blurred layers a frame. `pack_assets.py` runs it, so the app's assets carry it.
`a_sheet_darkens_the_desk_under_it_test` measures a piece drawn over the real wood and needs no
capture to answer.

**A hold was a gesture nothing could see happening.** Forty byte-identical frames in a row in
15_authored_feeling, the whole of the run where the scene holds `pigeon`. The charge does grow the
object — 0.952 to 1.12 of scale over 1.8 seconds — which on a 92 point tile is 0.05 of a device
pixel a frame: real and invisible. And nothing asked for a frame at all on a phone, because `_curl`
has finished by the time a finger is resting and an AnimatedBuilder on a finished controller never
rebuilds; the earlier fix asked the *driven* clock for a repaint, which is the clock nobody's phone
runs on. A held tile comes off the sheet now, with its shadow spreading underneath — the landing's
vocabulary run backwards, 1.2 device pixels a frame — and a ticker drives it on both clocks.

**The arriving feeling was drawn three times the size it was placed at.** `FeelingObject` takes the
size of the *thing* and needs a box of `size * ink`, and ink runs to 3.4 for something that sits
small in its own render — so at full throw the landing asked for a 190 point object and drew 646
points of it, on a phone 360 points wide, out through a Positioned that was 190. That is the
unlabelled slab a coherence critic measured covering Pulse's partner-state card for 106 frames. It
also landed at 0.52 of the height, which is the middle of whatever the region has on the glass, and
lay there for the whole length of the pattern. It lands low on the band of desk every region leaves
above the tab strip now, and is put away as soon as it has stopped bouncing; the pattern plays on
with it filed.

**Every still was shot at a width no phone has.** 480 by 1040 of CSS at three times scale — the
1440 by 3120 the brief asks for, laid out 120 points wider than every clip and wider than either
phone. 360 by 780 at four times scale now: same pixels, same minimum, a real phone. Every region is
drawn at 360 and at 390 in `every_screen_builds_test`, which found the first thing immediately —
the notification preferences overflow a 360 point phone by 78 and 84 points.

**Four claims the set made in a log and showed nowhere.** A reconnect (08 cuts the link, the far
phone writes two things, the link comes back, and both arrive in order); a note taken back (the far
phone withdraws its last message, so 13 can frame a row really taken away rather than one marked
withdrawn by hand); the pocket (the phone is picked up at the end of the reception scene, which is
the only way `received()` can be read at all); and partner state on the viewer, which was the one
screen in the set with no strip of any kind.

**And the typing frame expired on a `Timer`** while the app ran on a driven clock, so 13 showed
`noor writing…` on the glass over a record, claiming to be read at the shutter, that said she was
not. Both were true, four wall-clock seconds apart.

**The release path was exercised again**, on the build that serves over TLS rather than the one
from before it: 101.2 MB for arm64, signed with a throwaway key generated into /tmp and destroyed
with the key.properties that pointed at it.

### And six more the twelfth capture found by failing

It ran for three hours, the machine did not last that long, and a self-matching `pgrep` in the
waiting loop meant nobody noticed for nine hours. Both are fixed — `capture.sh` takes `--stamp=` and
`--scenes-only` so a run splits into passes of half an hour that each survive, and waits key off a
sentinel the job writes rather than off a process name. What the capture itself said:

- **The stills at a phone's width broke the hero.** The brief asks for at least eight notes visible
  in 02_chat.png with no tear id repeated; a 360 point thread has a 501 point viewport and holds
  four. Back at 480 it holds eight, eight distinct tears. The 360 pass is what found the truncating
  module rows and five row costs measured at a width nobody has, and those fixes stay.
- **The shorter landing dwell emptied the stage**: 154 held frames in 07, first at frame 66 of a
  150-frame run. Reverted; where it lands is what answers the occlusion.
- **The hold's ticker is not what turns under the harness.** 129 held frames in 15, longest run 42,
  within two frames of the capture before. The driven clock's own tick is back beside the ticker.
- **The reconnect was shot in Settings**, where the link state is one word changing on a still page:
  437 held frames in 08. It is in the thread now — a note that will not go, the near phone reading
  back while it waits, and both of the far phone's notes landing in order when the link returns.
- **The paper pool was a count of ten and Moments needs nineteen**, so a piece drew the flat colour
  under it while the stock it asked for decoded again. A 320 MB byte budget now; the framework's own
  image cache was measured at 43 MB of its 384 MB ceiling, so the paper is the thing worth bounding.
- **An anchor that cannot be satisfied moved nothing and said nothing.** 13 asked for a stretch
  holding an edited row, a withdrawn one and one still queued; no such stretch is in the year, so
  the thread stayed where it was and the record wrote `anchor: null`. It says what it could not
  satisfy now, and the scene asks for the one mark no artifact has ever shown.
- **An empty pocket was three facts wearing one face.** `received()` returned `const []` for a
  missing registration and for any throw. The record says which empty it is now.

## 4. What is left, in order of what it costs to close

The six blocking findings of the thirteenth review, each with its measurement. `evidence/critics/13/`
has them in full; `completeness.json` says which replicate and to what figure.

### 1. The scroll costs paper (messenger, blocking)
196 of 886 fling frames over 400 ms of app build time. Correlation 0.788 with `pieces_drawn`,
−0.122 with `rows_built`; control at p95 34 ms in `evidence/experiments/what_the_alternates_cost`.
**Measure the nine-patch composition cache first** — `SlicedMasks.paintNine` composes the slice into
one image at the size the piece turns out to be, and `fitFor`'s room went 0.8 → 0.5 this cycle, so
distinct sizes multiplied. If that is it, key the cache on the quantised size rather than the exact
one.

### 2. The writing does not sit on the ruled lines (material, blocking)
0.491 of a pitch off on the hero against the corrected grid. The design is written into
`evidence/logs/lines.json` and changes no layout: measure rule phase and pitch per stock at pack
time into INDEX.json, read the piece's first baseline in `_WithinTear` with `getDistanceToBaseline`
during layout, publish it to `_StockPainter`, and snap the seeded patch offset to the multiple of
the pitch that puts a printed rule under that baseline. The rule *detection* is also weak — eight of
seventeen rules found on the hero, six of thirty-eight on the first run — and worth strengthening so
the phase can be trusted per piece.

### 3. Three feeling objects are untextured (anti-goal, blocking)
`obj_crumple_ball` (overwhelmed), and the `hold` and `nyeh` objects. Re-render with the paper
material the rest of the library uses. Two checks let it through and both need fixing with it:
`surfaces.json` sets no tooth floor for the `objects` family at all — the one family the emotional
layer is made of — and `flat.json` reads only the ten stills and never a clip frame.

### 4. Nothing shows a pattern reaching a finger or an ear (emotional, blocking)
All fourteen motor asks answer "no motor in a browser". The substitute is the page visibly moving,
which a face-down phone cannot deliver, and the sound is in the clips only because the harness mixed
it over silence. Needs a device, or a statement in the set that this container cannot show it.

### 5. No artifact behind the platform-parity clause (coherence, blocking)
All fifteen present artifacts are the same headless WebKit page. One screenshot of any region on the
Android build lifts it; this machine cannot make one.

### 6. The persistence guard has three open doors (code, serious)
Each walked through with all five tests green: `import'package:sqlite3/sqlite3.dart';` with no space
after the keyword (the regex is anchored on `\s`); a second event log on
`File.fromUri(...).open(FileMode.append)` and `RandomAccessFile.writeString`, which neither the
constructor pattern nor the six enumerated write methods see; and any driver import under
`app/tool/`, which no loop in the file visits — though `host_daemon.dart` already reaches a store
from outside the spine.

### Also carried, measured and unfixed

- **~~A 401 leaves the link reading `connected`.~~ Wrong — I misread the field.** I recorded this
  as a blocking-adjacent fault in the cycle-13 builder's sheet and here, from
  `rounds: 212, pulled: 0, faults: 1` in `11_chat_scroll.report.json`. `_pulled` counts *events
  pulled down* (`_pulled += res.events.length`), not successful rounds: a client already at the
  head of the log pulls nothing and that is correct. One request of 212 was refused, which is below
  the three-in-a-row `http_transport.dart` requires before it says "the other phone does not know
  this pairing" in words — so the app behaved exactly as designed and recovered. The one 401 is a
  stale pairing carried by the browser profile that now persists across scenes; it is capture
  hygiene, not an app fault. The builder's sheet for cycle 13 is left as written, because it is the
  record of what was claimed before the reports were read; this is the correction.

- **The contact shadow overshot.** 15.0 to 24.6 grey levels under a sheet against a floor of 6, and
  `holes.py` counts six of ten stills over its 200-pixel allowance of pixels beside the paper darker
  than ink — 895 in Us, 643 in Pulse, darkest 22 to 28 against ink at 30. The lever is the bake's
  own opacity in `tools/bake_tear_shadows.py`, tuned when a tear could take four fifths of a piece.
- **`scroll_cost_test.dart:110` is a wall-clock microbenchmark** with a fixed 20,000 µs ceiling that
  went red on one full-suite run in four — and a red suite aborts the whole capture. The same class
  of fault as the hold test fixed this cycle; one was found and the looking stopped.
- **`sticky_blue_02` arrives late in four of ten stills**, costing two sheets each time. Ten of
  eighteen reports carry a non-empty `sheets_on_the_glass_with_no_paper_on_them`.
- **`docs/EVENT_TYPES.md` claims** `spine_replay_golden_test.dart` replays the seeded year against a
  golden; it replays fifteen hand-written events against none.
- **Nobody looked at**: `holes.json` ending `ok: false`, `logs/manifest.json` reporting two assets
  missing that are on disk, `pwa.json` recording `display_mode_standalone: false`.

### Hold the old reports outside the repository next time
`.review-held/` inside the working tree was reachable by the code critic's history-wide grep, which
printed lines out of an earlier `code.json` before it scoped the path away. It disclosed this and no
finding rests on it. Put them somewhere a search cannot reach.

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

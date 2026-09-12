# CONTINUE

The state handed to the next session. `docs/BRIEF.md` is the mission and wins over this file.
Branch: `claude/new-session-f95s8n`.

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

**Cycle 11 scored 80, with no floor met**: messenger 22/30 (floor 26), material 21/25 (22),
emotional 16/20 (17), coherence 13/15 (13, met), anti-goal 9/10 (9, met), code 13/15 (13, met).
Seven reports, in `evidence/critics/11/`. Three of the five rows that carry the score are short,
and two of them by one point.

**Every blocking finding is fixed in the tree and none of them is in an artifact yet.** The
thirteenth capture is what the reports are of and the fixes landed after it:

- *A message-shaped hole in the thread.* The one note the far phone wrote while the link was down
  arrives on reconnect, takes its 72 logical pixels, and paints bare desk for the last 46 frames of
  `08_state_propagating` — max luma 184 over the whole band against 4.7 per cent above 150 on the
  text line 50 px above. A piece kept its room and painted nothing until its tear was out of the
  cache, on the reasoning that the next frame would have it. It has three shapes now: torn,
  nothing for eighty milliseconds, then **cut** — a guillotined sheet, which is what the app draws
  for every card that never had a tear. Paper that is cut is still paper.
- *A hole in the desk.* 113,175 connected pixels under luma 30 beside one sheet in `01_pulse`: the
  contact shadow's displacement was baked into its canvas, so the nine-patch stretched its solid
  core across a piece's interior. The bake is centred and the lift displaces it at draw time.
- *Ninety-two held frames in the reconnect clip.* Both halves were driven between takes, so what
  was filmed was the aftermath twice over. A scene can drive a handle at a named frame now, and
  write into the composer a character at a time: the take is somebody writing into a dead link,
  then the send, then the pull, with both of the far phone's notes landing inside the shot.
- *A flat beige triangle where the folded corner is.* 0.26 grey levels of texture against 1.162 for
  the paper tab beside it, and byte-identical between the day still and the dusk one over 4,316
  pixels while the desk moved by 25.7. It is a window onto a real sheet at the sheet's own density
  now, in whichever light the desk is in: measured at widget scale, 2.44 against a flat one's 0.25,
  and 70 grey levels between day and dusk.

### A review has to be of something that is not moving

The completeness pass caught this session doing what it should not: **twelve paths were rewritten
between 19:58 and 20:07 while the review still stood**, the earliest of them nine minutes after the
last critic filed. One of the code row's three findings — `_ReplyStrip` handing a reader a raw
registry id — can no longer be checked against the tree it was written about; it was repaired, not
refuted, and a reader cannot tell those apart from the repository alone.

The reports for cycle 11 are therefore the record, and this file says what changed after them. For
cycle 12: **write the builder sheet, run the capture, and do not touch the tree again until the
seventh report is in.**

**Cycle 10's fixes are in and its capture has not run.** What follows is what changed and, more
importantly, how it was found, because two of the three biggest fixes this cycle corrected a
diagnosis an earlier cycle had been confident about.

### The scroll: two diagnoses disproved by the instruments built to test them

Three cycles blamed the tear mask being baked per note. A counter put on `SlicedMasks.composed`
read **twelve masks across a fling through 8,075 rows in seven throws** — the baking was gone and
the spikes were not the baking. The next hypothesis, named so it could be killed cleanly, was the
hand fonts' contextual alternates shaping a paragraph per new note;
`the_hands_are_not_what_the_scroll_costs_test` shapes a note of handwriting in **0.074 ms**, three
orders of magnitude short.

What it was, found by shooting the same scene twice against the same build. Alone: 135 rows built
over 300 driven frames, build p50 3 ms and p95 26. In a run where the far phone was up and
syncing, which is how the capture actually runs: **5,028 rows over the same 300 frames**, p95
1,562, 269 frames over 400 ms. `Note.build` opened with `AppScope.of(context)`, which registers a
dependency on an InheritedNotifier, and the spine notifies on every sync round — so every note on
the glass was a listener of every round the other phone answered, and the framework dirtied each
row's own element. Caching the row widget did nothing, because the rebuild was not coming from
above. `AppScope.meOf` reads the one thing a row needs — whose phone this is, a constant for the
life of the app — without subscribing. Twenty frames with a message landing on every one: **595
row builds became 16**.

### The material: three measurements that turned out to be one fault

The tooth spread thin on a wide sheet (2.52 grey levels at the stock's own density, 1.26 on the
large Settings sheet). The same ruled stock at rule pitches from **61.5 to 178.5 device pixels**
across ten stills, a ratio of 2.9. Writing that cannot sit on the lines, 0.33 of a pitch off,
where writing with no relation to the rules would be 0.25.

Every stock is printed at 8.57 pixels to the millimetre and every piece drew its stock at whatever
scale that piece happened to be. **The app did not know how big a millimetre was.** A piece takes
a window of its stock at the stock's own density now, positioned by the seeded patch offset and
clamped so the window lands on paper and on the part of the sheet that is ruled; a piece with more
glass than there is paper falls back to covering, and `paper_at_its_own_size` against
`paper_stretched_to_fit` in the capture record says how many of each were on the glass. The paper
stocks were re-rendered at 1574x2200 so a full-width piece fits inside one.

### And the rest of cycle 10

- The fold **bends** instead of hinging: a 2.2 mm radius band and a flap that keeps turning over
  its own length. The crease measurement the completeness pass used goes from **-0.37 to +1.60 and
  +1.52** grey levels. A taller ridge was tried, measured worse (0.88, 0.62), and put back.
- `common.torn_edge` replaces four two-sine "torn" edges. Self-correlation past the central lobe:
  **0.80 to 0.16-0.34**, with the shape it replaced measured in the same report as a control.
- The hash under every cut card was **a sawtooth** — the low sixteen bits of a linear function of
  the index. Every octave of every outline was built out of a ramp.
- **DeskStamp had no counters.** The tabs read `T● D●` and `M●MENTS` in eight captures. A hole
  turned positive and re-unioned is a disc.
- The last literal fill in lib, the search highlighter, became a pen.
- Nine records that did not exist: what the launch was made of, every ask the app made of a motor
  and what answered, which of five checks a 401 failed, the words the other phone refused in, a
  delivered reply with its parent, the tear library's own straightness, whether the writing is on
  the lines, and what each ambient surface may say.

### And what the twelfth capture was waiting on

Six more, all found by reading cycle 9's own reports back against the code rather than by looking
at a picture.

- **A hole in the desk beside every sheet.** A coherence critic measured 758 pixels under luma 30
  at one chip's right edge in 12_search, minimum 4.3, against a desk reading 84-103 either side of
  it. Two faults in one: the paper's tear is nine-sliced so its fibres keep their rendered size,
  and the baked contact shadow under it was stretched with `BoxFit.fill`, so on a piece far from
  the render's proportions the two no longer coincided — and what came out from under the paper is
  black at alpha 255 over a third of every one of those assets, because that third is meant to be
  occluded. Nine-sliced and tinted to `Shadow.warm` now. `tools/check/holes.py` measures the ring
  from three to twelve pixels outside every sheet and gates on it: **nine of the seventeen stills
  had one**, worst 11,346 pixels in 17_setup_pwa.
- **The long poll may be asked for twice.** `401 GET /v1/events?after=14075&wait=20` in two of
  fifteen scene logs, both of them the long clips, with the client's own sync recording `faults:
  0` in the same file. A browser retries an idempotent GET when the connection closes before the
  first response byte, with the header already on the wire; the nonce cache refused the second
  one. The nonce is spent on writes now — a replayed read re-reads events the caller already
  holds — and every refusal names the device it refused and the pairing it held.
- **The first ten seconds are not blank.** `runApp` is not called until the log is open, and on a
  first launch that is 8.9-10.0 seconds in five scene logs. For all of it the page was a flat
  `#4C3E32` rectangle, which is why no artifact showed what is on the screen during it: nothing
  was. The page puts the desk out itself now, with one line on a piece of the real stock in the
  real hand and the month count Dart reports as it reads, and takes it away on the frame that
  replaces it.
- **A way back to now, and the day at the top of the glass.** One hard fling covers 1.2 to 3.1 per
  cent of an 8,075-row thread and there was no scrollbar, no date rail and no way back. Two slips
  now: the day the top row belongs to, and a torn tab saying `back to now` with how far up in the
  units somebody says out loud. Both read from the list's own item positions through a
  `ValueNotifier` with an `==` that compares what would be *written*, so a fling rebuilds two small
  widgets and not eight thousand rows.
- **A reply that has landed.** Every capture carried `replying_to` — the composer's pending target
  — and no artifact ever showed a delivered reply tied to its parent. 13 stages one through the
  composer now, and four answers in the seed that genuinely reach back past what came between them
  were tied (`k:` keys, 2026-08 and 2026-09), because the last four months of the authored year
  had no reply in them and every scene opens at the end of it.
- **The video advancing.** 14 is a still and the set holds exactly seventeen artifacts, so the
  scene grabs 48 of its own frames and they are folded into `crops/14_media_viewer_strip.png` and
  the frame record — not an eighteenth artifact.

### And two the capture itself found, fourteen minutes in

The twelfth capture was stopped after five stills because its first artifact carried two faults
worth more than the fourteen minutes.

- **A black quadrilateral behind every feeling object.** The same fault as the paper's contact
  shadows, in the object path, and the same fix. Those renders are RGB 0,0,0 through their alpha
  with an opaque core nearly the object's own silhouette — `obj_dog_ear_shadow` is 17.4 per cent
  alpha above 240 against the object's 18.7 — so wherever the packed offset puts the core beside
  the thing instead of under it, black lands on the desk. On 01_pulse's object row it reads as a
  hole cut in the wood behind a torn card.
- **A drawn feeling was six translucent rectangles.** Every stroke composited separately at under
  full alpha, so a crossing carried two and came out 46 grey levels darker than the ink; and the
  wobble was one offset per named point, so `obj_window` — six strokes of two points each — drew
  dead straight and uniform. The whole mark goes into one layer now, and a stroke is walked at
  about a pen's width a step with two slow terms and the ends pinned. Four built-ins are drawn
  marks rather than rendered props (`obj_window`, `obj_chair`, `obj_scribble`, `obj_thumbprint`)
  and every critic so far has assumed all thirty-four were props.

**The paper half of the shadow fix is confirmed on the artifacts that run did take.** Pixels darker
than ink in the ring beside a sheet: 02_chat 4,070 → 0, 03_us 3,896 → 0, 12_search 10,995 → 0,
04_moments 2,071 → 0, and the darkest pixel beside a sheet from 5.3–17.3 up to 34.7–48.3.
`paper_at_its_own_size` reads 222 against 3 stretched.

### And two the twelfth capture found in its own clips

- **The folded note's landing does not move under the driven clock.** Scene 06 grabs sixteen frames
  of the note that has just arrived before opening it, and on the frames that capture wrote all
  sixteen are *byte-identical* — mean absolute change 0.0000 between each pair, then 6.68 on the
  frame the unfold starts. The landing is real code (`FoldedNote` wraps its sheet in
  `Settling(duration: Motion.land, curve: Motion.drop)` when `arriving`), the curve moves 2.77
  pixels on its first frame and 17.5 over sixteen, and `awaitArrival` does not step the clock — so
  a frame of it should differ from the one before by more than two grey levels and none of them
  does. Something between `Settling` subscribing to `DrivenClock.ticks` and the note being rebuilt
  is not connected. The scene's pre-roll is one frame now, so the clip has no hole in the front of
  it, and this is written down rather than papered over.
- **Two corners fight over the capture handles.** `FeelingCorner` registered `openCorner`,
  `showFamily`, `holdOver` and `letGo` in `initState` and cleared them unconditionally in
  `dispose`. When the region changes, Flutter builds the new corner before it disposes the old one,
  so the new registration was torn down behind it and the next `__deskOpenCorner` answered `no
  shell`. That is what stopped 15_authored_feeling at its second `goTo`, sixty-six minutes into a
  capture. Whoever mounted last owns them now.

One thing was found on the way and not chased: **a second `AppScope` built inside a second
`testWidgets` in one file never returns.** Reduced to a scratch test that builds one, pumps it,
and does it again — the first case passes in under a second and the second never reaches its first
statement. Every widget test in this build that needs a scope makes it in `setUpAll`, so nothing
had ever asked for two. It is written down in the head of
`app/test/a_year_says_where_you_are_test.dart`.

### Two things measured and deliberately not fixed

Both are in the evidence so the next cycle starts from a number rather than an impression.

1. **Half the tear library is too straight.** Fifty-six masks: min 1.15 px rms, median 2.00,
   28 under 2.0 (`logs/torn.json`). The cause is in `tools/tears/tear.py` — the fracture's Hurst
   exponent runs to 1.15, and 1.15 is a clean pull. The fix is fifty-six masks and their relief
   and their shadows.
2. **The writing is not on the rules**, 0.33 of a pitch off (`logs/lines.json`). Fixing it means
   laying text out against the paper it is drawn on — the pitch, and the phase of the first rule
   under the seeded patch offset — which is a change to every note in the app.

## 3. Cycle 11, which is what the thirteenth capture is of

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

Half of this is now measured rather than asserted, and it is the shadow's half: a torn sheet's
contact shadow is cut from its own tear and displaced by `shadowOffsetFor`, which is the one rig's
direction, so paper and its shadow agree about where the light is. What still does not agree is the
*surface* — the stock renders carry tooth and fibre but no shading field, so a sheet is evenly lit
wherever it is put and only its edge knows which way the window is.

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

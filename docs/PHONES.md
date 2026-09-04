# The two phones

What has to be true on each of them, in the order it has to become true. This is the same list the
app shows on its own first screen; it is written down here as well so it can be followed without
the app running.

## The two roles

One phone is the **host**: the Android one. It holds the log, hands out the sequence numbers, and
serves the other phone over the tailnet. Being the host is not being in charge of anything — either
person can write anything at any time and their own phone keeps it whether or not the other one is
reachable — it only decides which of the two assigns the order.

The other is the **client**: the iPhone, running the installable web app. It keeps its own copy of
everything, writes into it while offline, and pushes what it wrote when the host comes back.

## The list

1. **Both phones on the same tailnet, and nothing else on it.**
   Install Tailscale on each and sign both into the same account. The conversation is only ever
   served to a tailnet address, so until this is true there is nothing to connect to. Turn subnet
   routes and DNS acceptance off on both: neither phone needs anything from the tailnet except the
   other phone.

2. **The Android app installed, and its tailnet address noted.**
   The Tailscale app shows it: four numbers beginning with 100. That address is what the iPhone
   will look for, and it is the only address the Android phone will serve on. With Tailscale down
   the app says so and does not start serving on anything else — there is no fallback in the code
   and `app/test/tailnet_test.dart` is there to keep it that way.

3. **The web app added to the iPhone's home screen.**
   Open the host's address in Safari, share, add to home screen. It will not hold on to anything
   until it is opened from the home screen rather than from a tab — an iOS rule, not ours, and the
   setup list waits for it rather than pretending.

4. **The profile trusted.**
   The host serves over HTTPS with a certificate it made itself. Open its address in Safari, take
   the profile, then trust it under Settings → General → About → Certificate Trust Settings. This
   is the fiddliest step and there is no way round it: the alternative is a certificate authority
   that has heard of your phones, and none has.

5. **The six words, read out loud.**
   The host shows six words. Say them in the same room; type them into the iPhone. They are good
   once. What they do is derive a key on both phones (HKDF-SHA256 over the words and both device
   ids); every request either phone makes afterwards is signed with it, and one that is not is
   refused. Being on the same tailnet is *not* what authenticates the two phones to each other —
   it is only the reason nobody else can watch them talk.

6. **Notifications, if you want them.**
   The Android phone vibrates the pattern a feeling carries. The iPhone cannot — Safari has no
   vibration API — so the same pattern moves the paper under your thumb instead, and a web push
   arrives carrying only what kind of thing it is and who sent it. Never the content: the content
   only ever travels over the tailnet.

## What is deliberately not here

- No account, no server, no directory, nothing to sign up for. The only thing either phone talks
  to is the other phone.
- No cloud backup. What is on the two phones is what there is. Settings writes the whole log out
  to a file, and that is the backup.
- No third device. The pairing is between two device ids and there is nowhere to put a third.

## Running the two test nodes

In development there is no pair of phones, so `tools/tailscale/up.sh` brings up two userspace
`tailscaled` daemons — one per role — each with its own state directory, and prints the address
each is on. It needs a Tailscale auth key in the environment:

    TS_AUTHKEY=tskey-auth-… bash tools/tailscale/up.sh
    ./run.sh --transport=tailscale

The key is read from the environment and never written to disk; `toolchain/ts/a/` and `b/` are
ignored by git, and `toolchain/ts/AUTHKEY_STATUS` records only whether a key has ever been
supplied — the word `pending` or the word `supplied`, nothing else.

Without a key the tailscale run is recorded in `evidence/reliability.json` as **pending**: not as
passing, and not as failing, because the thing it would have checked has not been checked. Every
other reliability check runs over the local transport and is unaffected — the two transports share
one protocol, one pairing and one sync engine, and differ only in which address the host binds.

## Why there is no Android screenshot in the evidence

`09_two_devices.png` and `16_setup_android.png` are the two artifacts that need the Android phone,
and neither of them exists. This is what was actually tried, so that it reads as a measurement
rather than as an excuse.

The AVD is `lovetap`, an `aosp_atd` x86_64 image on android-34 at 1440×3120 — the artifact's own
resolution. This container has no `/dev/kvm`, so an x86_64 guest cannot be virtualised and QEMU
falls back to emulating the instruction set. The emulator was started headless with
`-accel off -gpu swiftshader_indirect`, and it did start: it reached `init.svc.bootanim: stopped`
and `adb devices` showed `emulator-5554  device` after a hundred and thirteen minutes on one core.

That is where it stopped. `sys.boot_completed` and `dev.bootcomplete` were both still empty, and
`pm list packages` answered `cmd: Can't find service: package` — the framework had not come up, so
there was nothing to install an APK into. It was left running while the paper library rendered and
had made no further progress; it was then stopped, because it was holding a core the hundred and
fifteen photographs needed more.

There is no GTK in the container either, so a Linux desktop build cannot stand in for a second
screen, and the brief requires 09 to be one display carrying an AVD window beside a Playwright
window. Neither artifact was faked from the PWA, and `capture.sh` records both as missing with
this reason rather than substituting anything.

What would produce them: a host with `/dev/kvm`, or an ARM64 host where the `arm64-v8a` image runs
natively. Everything else in the capture — the PWA, the tailnet transport, the seeded year — runs
here unchanged.

### And the third thing that was tried: Flutter's own engine as the second screen

If the emulator will not boot, the far phone still exists — `app/tool/host_daemon.dart` is a real
spine in the real host role, and `08_state_propagating` is a recording of a gesture on one device
becoming a sensation on it. What it has never had is a surface. `flutter_tester` has one:
`RenderRepaintBoundary.toImage` writes a real PNG out of the same framework that draws the app on
a phone, with no browser anywhere in it. That is arguably a *more* faithful second device than an
emulator screenshot, so it was worth half an hour to find out.

`docs/far_screen_probe.png` is what came back, and it is why 09 stays missing.

The handwriting is right — both hands load through `FontLoader` and render with their variants —
and the layout is the app's own. Everything made of paper is gone. Each note is a flat fill in
`0xFFF1ECDF`: the colour `PaperPiece` paints *underneath* the stock render so that a sheet whose
image has not arrived is still a sheet. The stock is missing, the tear mask is missing, the edge
light is missing, the contact shadow is missing, and the desk behind them is missing too.

The cause is not the assets. `flutter test` does bundle them, into `build/unit_test_assets`. It is
that `testWidgets` runs in a fake-async zone where a real `Future` never completes, so
`instantiateImageCodec` — every `Image.asset`, and every mask through `MaskCache` — is still
pending when the frame is drawn. `tester.runAsync` escapes the zone, but a screen holds dozens of
those decodes across four layers per note, and a render that resolves some of them and not others
is worse evidence than none: a screen of flat beige rounded rectangles is a photograph of the one
anti-goal the brief calls a failure of the entire visual concept.

So the probe was deleted rather than kept as a half-working capture path, and its output is left in
`docs/` as the reason. Three ways to a second screen have now been tried and measured: the x86_64
emulator under instruction emulation (booted `adbd`, never the framework), a Linux desktop build
(no GTK in the container), and the engine in a test harness (no material). None of them was faked
from the PWA.

### The eight gigabytes that could not boot

The `android-34` system images are no longer in `toolchain/`. Three ways to a second screen have
been tried and measured above, and the emulator's is the one that took a hundred and thirteen
minutes to reach `adbd` and never reached the framework. What the images were still doing was
occupying 8.2 GB of a container with 2.8 GB of writable space left — and that ran out mid-capture,
which is how a whole evidence run came back with `ENOSPC: no space left on device` against every
clip and four artifacts recorded missing for a reason that had nothing to do with the app.

`./bootstrap.sh` puts them back. On a host with `/dev/kvm`, or an ARM64 host where the `arm64-v8a`
image runs natively, that is the first thing to do; `capture.sh` already checks `adb shell true`
and records 09 and 16 with their reason when it fails.

# builds

**Download:** [love-tap-arm64.apk](https://github.com/kaiharimoto/love-tap/raw/claude/app-improvement-autonomous-workflow-d6fwdu/builds/love-tap-arm64.apk)

    sha256  aa8940f6f0a66365b33afa10c7a4624f7af8c58fa6cc9163b0726f2288f36137
    size    85,101,754 bytes (81.2 MiB), arm64-v8a only

Built 2026-09-24 from `e2d0becb`, the tip after loop firing 62, which is where the loop was
stopped. The gate on that commit: `flutter analyze` no issues, `flutter test` 294 passed.

    flutter build apk --release --split-per-abi --target-platform android-arm64 \
      --dart-define=SEED= --dart-define=TRANSPORT=tailscale --dart-define=PROFILE=default \
      --dart-define=ROLE=host --dart-define=PERSON=noor

## What it is

- **Empty log.** No seeded year is compiled in. The seeded build is 100.2 MiB for arm64 alone,
  just over GitHub's 100 MiB file limit, so it is not here.
- **Signed with the Android debug key** (`CN=Android Debug`). The key that signed v0.1.0 and
  v0.1.1 on the `builds` branch is not in this repository, so this build cannot install over them:
  **uninstall the old one first, and uninstalling deletes its log.**
- **One phone.** It installs and runs on its own: write, pull the corner for a feeling, Moments,
  Us, Search, Settings. With Tailscale off, the setup list says so and nothing is served.

## What it cannot do yet

**Pair with the iPhone.** The two-phone path — the web app packed into the APK and served to
Safari, the self-made HTTPS certificate and its profile, the release-signing config, the launcher
icon — was built on `claude/new-session-f95s8n` (the v0.1.x line) and was never merged into this
branch. The two branches have diverged by roughly 500 commits each. Until that is ported, this
build's host has no page to hand the iPhone.

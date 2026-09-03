#!/usr/bin/env bash
# bootstrap.sh — install the pinned toolchain into ./toolchain with no sudo and no prompts.
#
#   git clone <repo> && cd love-tap && ./bootstrap.sh
#
# Installs: Flutter (pinned), Android cmdline-tools + platform + build-tools + emulator +
# one AVD ("lovetap", 1440x3120), Blender (pinned, headless CPU), ffmpeg (static),
# tailscaled + tailscale (pinned, userspace mode, two state directories), Playwright WebKit.
#
# Every stage is idempotent: a marker under toolchain/.done/ skips it on re-run.
# Prerequisites that this script cannot install itself are checked first and named.
# TS_AUTHKEY is never written to disk; its absence is recorded as "pending".
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TC="$ROOT/toolchain"
DONE="$TC/.done"
DL="$TC/downloads"
LOG="$TC/bootstrap.log"

# ---- pinned versions (change here, nowhere else) -------------------------------------------
FLUTTER_VERSION="3.47.2"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
CMDLINE_TOOLS_ID="16111833"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_ID}_latest.zip"
ANDROID_PLATFORM="${ANDROID_PLATFORM:-platforms;android-36}"
ANDROID_BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-build-tools;36.0.0}"
ANDROID_SYSIMG="${ANDROID_SYSIMG:-system-images;android-34;aosp_atd;x86_64}"
AVD_NAME="lovetap"
BLENDER_VERSION="4.5.13"
BLENDER_URL="https://download.blender.org/release/Blender4.5/blender-${BLENDER_VERSION}-linux-x64.tar.xz"
FFMPEG_URL="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz"
TAILSCALE_VERSION="1.102.3"
TAILSCALE_URL="https://pkgs.tailscale.com/stable/tailscale_${TAILSCALE_VERSION}_amd64.tgz"
PLAYWRIGHT_VERSION="1.62.1"

mkdir -p "$TC" "$DONE" "$DL"
exec > >(tee -a "$LOG") 2>&1
echo "== bootstrap $(date -u +%FT%TZ) =="

say()  { printf '\n-- %s\n' "$*"; }
die()  { printf '\nbootstrap stopped: %s\n' "$*" >&2; exit 2; }
done_() { [ -f "$DONE/$1" ]; }
mark() { touch "$DONE/$1"; }

# ---- prerequisites the script cannot install (named, not guessed) --------------------------
missing=()
for tool in curl tar xz unzip git python3 node npm java Xvfb; do
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
if [ ${#missing[@]} -gt 0 ]; then
  die "missing prerequisite(s): ${missing[*]}  (install them with your package manager, then re-run)"
fi
JAVA_MAJOR="$(java -version 2>&1 | awk -F'"' '/version/ {print $2}' | cut -d. -f1)"
[ "${JAVA_MAJOR:-0}" -ge 17 ] || die "java 17 or newer is required (found ${JAVA_MAJOR:-none})"
python3 -c 'import sys; assert sys.version_info >= (3,10)' 2>/dev/null || die "python3 3.10 or newer is required"
if [ -z "${JAVA_HOME:-}" ]; then
  JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
fi
export JAVA_HOME

fetch() { # fetch <url> <dest>
  local url="$1" dest="$2"
  if [ -s "$dest" ]; then echo "have $(basename "$dest")"; return; fi
  echo "fetch $url"
  curl -fL --retry 5 --retry-delay 3 --connect-timeout 30 -o "$dest.part" "$url"
  mv "$dest.part" "$dest"
}

# ---- Flutter -----------------------------------------------------------------------------
if ! done_ flutter; then
  say "Flutter $FLUTTER_VERSION"
  fetch "$FLUTTER_URL" "$DL/flutter_${FLUTTER_VERSION}.tar.xz"
  rm -rf "$TC/flutter"
  tar -xJf "$DL/flutter_${FLUTTER_VERSION}.tar.xz" -C "$TC"
  git config --global --add safe.directory "$TC/flutter" || true
  mark flutter
fi
export FLUTTER_ROOT="$TC/flutter"
export PUB_CACHE="$TC/pub-cache"
export PATH="$FLUTTER_ROOT/bin:$FLUTTER_ROOT/bin/cache/dart-sdk/bin:$PATH"

# ---- Android cmdline-tools + SDK ---------------------------------------------------------
export ANDROID_HOME="$TC/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="$TC/android-user"
export ANDROID_AVD_HOME="$ANDROID_USER_HOME/avd"
mkdir -p "$ANDROID_HOME" "$ANDROID_AVD_HOME"
if ! done_ cmdline-tools; then
  say "Android cmdline-tools $CMDLINE_TOOLS_ID"
  fetch "$CMDLINE_TOOLS_URL" "$DL/cmdline-tools-${CMDLINE_TOOLS_ID}.zip"
  rm -rf "$ANDROID_HOME/cmdline-tools"
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  unzip -q "$DL/cmdline-tools-${CMDLINE_TOOLS_ID}.zip" -d "$ANDROID_HOME/cmdline-tools"
  mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  mark cmdline-tools
fi
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
if ! done_ android-sdk; then
  say "Android SDK packages"
  yes | "$SDKMANAGER" --sdk_root="$ANDROID_HOME" --licenses >/dev/null || true
  "$SDKMANAGER" --sdk_root="$ANDROID_HOME" --install \
    "platform-tools" "$ANDROID_PLATFORM" "$ANDROID_BUILD_TOOLS" "emulator" "$ANDROID_SYSIMG"
  mark android-sdk
fi
if ! done_ avd; then
  say "AVD $AVD_NAME (1440x3120, software GPU)"
  echo no | "$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" create avd --force \
    -n "$AVD_NAME" -k "$ANDROID_SYSIMG" -d "pixel_7_pro" >/dev/null
  cfg="$ANDROID_AVD_HOME/$AVD_NAME.avd/config.ini"
  # Deterministic, headless-friendly device: 1440x3120 @ 560dpi, software rendering.
  python3 - "$cfg" <<'PY'
import sys, re
p = sys.argv[1]
want = {
  "hw.lcd.width": "1440", "hw.lcd.height": "3120", "hw.lcd.density": "560",
  "hw.gpu.enabled": "yes", "hw.gpu.mode": "swiftshader_indirect",
  "hw.ramSize": "3072", "vm.heapSize": "512", "disk.dataPartition.size": "4096M",
  "hw.keyboard": "yes", "hw.audioInput": "no", "hw.audioOutput": "yes",
  "hw.camera.back": "emulated", "hw.camera.front": "emulated",
  "skin.name": "1440x3120", "skin.path": "_no_skin", "showDeviceFrame": "no",
  "hw.sensors.orientation": "yes", "hw.accelerometer": "yes", "hw.gyroscope": "yes",
  "hw.battery": "yes", "hw.gps": "yes", "hw.mainKeys": "no",
  "fastboot.forceColdBoot": "no", "fastboot.forceFastBoot": "yes",
}
lines = open(p).read().splitlines()
seen = set()
out = []
for ln in lines:
    k = ln.split("=")[0].strip()
    if k in want:
        out.append(f"{k}={want[k]}"); seen.add(k)
    else:
        out.append(ln)
for k, v in want.items():
    if k not in seen: out.append(f"{k}={v}")
open(p, "w").write("\n".join(out) + "\n")
PY
  mark avd
fi

# ---- Flutter configuration ---------------------------------------------------------------
if ! done_ flutter-config; then
  say "Flutter configuration"
  flutter config --no-analytics --enable-web --enable-android --android-sdk "$ANDROID_HOME" >/dev/null
  flutter precache --web --android
  yes | flutter doctor --android-licenses >/dev/null 2>&1 || true
  flutter doctor -v > "$TC/doctor.txt" || true
  mark flutter-config
fi

# ---- Blender -----------------------------------------------------------------------------
if ! done_ blender; then
  say "Blender $BLENDER_VERSION"
  fetch "$BLENDER_URL" "$DL/blender-${BLENDER_VERSION}.tar.xz"
  rm -rf "$TC/blender"
  mkdir -p "$TC/blender"
  tar -xJf "$DL/blender-${BLENDER_VERSION}.tar.xz" -C "$TC/blender" --strip-components=1
  mark blender
fi
export PATH="$TC/blender:$PATH"

# ---- ffmpeg ------------------------------------------------------------------------------
if ! done_ ffmpeg; then
  say "ffmpeg (static)"
  fetch "$FFMPEG_URL" "$DL/ffmpeg-release-amd64-static.tar.xz"
  rm -rf "$TC/ffmpeg"
  mkdir -p "$TC/ffmpeg"
  tar -xJf "$DL/ffmpeg-release-amd64-static.tar.xz" -C "$TC/ffmpeg" --strip-components=1
  mark ffmpeg
fi
export PATH="$TC/ffmpeg:$PATH"

# ---- tailscaled (userspace, two nodes) ---------------------------------------------------
if ! done_ tailscale; then
  say "tailscale $TAILSCALE_VERSION"
  fetch "$TAILSCALE_URL" "$DL/tailscale_${TAILSCALE_VERSION}_amd64.tgz"
  rm -rf "$TC/ts/bin"
  mkdir -p "$TC/ts/bin" "$TC/ts/a" "$TC/ts/b"
  tar -xzf "$DL/tailscale_${TAILSCALE_VERSION}_amd64.tgz" -C "$TC/ts/bin" --strip-components=1
  chmod 700 "$TC/ts/a" "$TC/ts/b"
  mark tailscale
fi
export PATH="$TC/ts/bin:$PATH"
if [ -n "${TS_AUTHKEY:-}" ]; then
  echo "present" > "$TC/ts/AUTHKEY_STATUS"
else
  echo "pending" > "$TC/ts/AUTHKEY_STATUS"
  echo "TS_AUTHKEY not set: recorded as pending (needed only for run.sh --transport=tailscale)"
fi

# ---- Playwright WebKit (the iOS stand-in) ------------------------------------------------
export PLAYWRIGHT_BROWSERS_PATH="$TC/pw-browsers"
unset PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD
if ! done_ playwright; then
  say "Playwright $PLAYWRIGHT_VERSION + WebKit"
  mkdir -p "$TC/pw"
  ( cd "$TC/pw" && npm init -y >/dev/null 2>&1 && npm install --no-audit --no-fund --silent "playwright@${PLAYWRIGHT_VERSION}" )
  ( cd "$TC/pw" && npx playwright install webkit chromium )
  mark playwright
fi
# WebKit's shared-library needs are checked, not installed (that needs a package manager).
if ! ( cd "$TC/pw" && npx playwright install --dry-run webkit >/dev/null 2>&1 ); then :; fi
WEBKIT_MISSING="$(cd "$TC/pw" && node -e '
const {webkit}=require("playwright");
webkit.launch({headless:true}).then(b=>b.close()).then(()=>process.exit(0)).catch(e=>{console.log(String(e.message||e).split("\n").filter(l=>/lib|Missing|dependencies/i.test(l)).slice(0,12).join("\n"));process.exit(1)})' 2>/dev/null || true)"
if [ -n "$WEBKIT_MISSING" ]; then
  echo "WebKit cannot launch yet; the missing shared libraries are:"
  echo "$WEBKIT_MISSING"
  echo "(install them with your package manager; on Ubuntu 24.04: tools/apt-prereqs.sh)"
fi

# ---- environment file --------------------------------------------------------------------
cat > "$TC/env.sh" <<EOF
# source this file: . ./toolchain/env.sh
export ROOT="$ROOT"
export TC="$TC"
export JAVA_HOME="$JAVA_HOME"
export FLUTTER_ROOT="$TC/flutter"
export PUB_CACHE="$TC/pub-cache"
export ANDROID_HOME="$TC/android-sdk"
export ANDROID_SDK_ROOT="$TC/android-sdk"
export ANDROID_USER_HOME="$TC/android-user"
export ANDROID_AVD_HOME="$TC/android-user/avd"
export PLAYWRIGHT_BROWSERS_PATH="$TC/pw-browsers"
export AVD_NAME="$AVD_NAME"
export PATH="$TC/flutter/bin:$TC/flutter/bin/cache/dart-sdk/bin:$TC/android-sdk/cmdline-tools/latest/bin:$TC/android-sdk/platform-tools:$TC/android-sdk/emulator:$TC/blender:$TC/ffmpeg:$TC/ts/bin:\$PATH"
EOF

say "versions"
{
  echo "flutter: $(flutter --version 2>/dev/null | head -1)"
  echo "dart:    $(dart --version 2>&1 | head -1)"
  echo "blender: $(blender --version 2>/dev/null | head -1)"
  echo "ffmpeg:  $(ffmpeg -version 2>/dev/null | head -1)"
  echo "tailscale: $(tailscale version 2>/dev/null | head -1)"
  echo "adb:     $(adb version 2>/dev/null | head -1)"
  echo "avd:     $(ls "$ANDROID_AVD_HOME" 2>/dev/null | tr '\n' ' ')"
  echo "TS_AUTHKEY: $(cat "$TC/ts/AUTHKEY_STATUS")"
} | tee "$TC/VERSIONS.txt"
echo "== bootstrap complete $(date -u +%FT%TZ) =="

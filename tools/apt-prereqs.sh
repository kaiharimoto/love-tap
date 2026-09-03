#!/usr/bin/env bash
# System packages bootstrap.sh checks for but cannot install itself (Ubuntu 24.04).
# Run with privileges: sudo tools/apt-prereqs.sh   (in the build container we are already root)
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  curl xz-utils unzip zip file git python3 python3-pip openjdk-21-jdk-headless \
  xvfb x11-apps x11-utils xdotool imagemagick \
  libgl1 libegl1 libgles2 libvulkan1 libglu1-mesa libxcursor1 libxdamage1 libxrandr2 \
  libxcomposite1 libxi6 libxtst6 libpulse0 libxss1 libxkbfile1 libnss3 libxrender1 libxfixes3 \
  libxinerama1 libsm6 libice6 libxxf86vm1 libxkbcommon0 libdbus-1-3 libfontconfig1 libfreetype6 \
  libopenal1 libsndfile1 libjpeg-turbo8 libtiff6 libwebp7 libopenjp2-7 \
  libwoff1 libharfbuzz-icu0 libgstreamer-plugins-bad1.0-0 libgstreamer-gl1.0-0 libenchant-2-2 \
  libsecret-1-0 libhyphen0 libmanette-0.2-0 libx264-164 libflite1 libgstreamer-plugins-base1.0-0 \
  libgstreamer1.0-0 libevdev2 libgudev-1.0-0 libgtk-4-1 libgraphene-1.0-0 libatomic1 \
  gstreamer1.0-libav gstreamer1.0-plugins-good gstreamer1.0-plugins-bad libavif16 liblcms2-2
pip3 install --quiet --disable-pip-version-check numpy pillow fonttools scipy scikit-image opencv-python-headless

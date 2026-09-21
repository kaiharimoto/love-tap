#!/usr/bin/env bash
# Run the cross-platform tests on the rig where the defects they are about are visible.
#
# WHY THIS EXISTS. `flutter test` runs on the Dart VM, where an `int` is a 64-bit integer. The PWA
# runs on dart2js/DDC, where an `int` is an IEEE-754 double and `&`, `|`, `<<` and `>>` are 32-bit
# operations. Every defect in which the two phones disagree about what to draw lives in that gap,
# and the VM suite cannot see any of it.
#
# Two have been found and both were found the expensive way:
#
#   * `hashOf` multiplied past 2^53 and rounded, so a note was torn from a different stock in the
#     browser than on the phone. Found by reading pixels across three review cycles.
#   * `UlidFactory.next` peeled a 48-bit millisecond time with `& 31` and `>>= 5`, so the PWA
#     minted a different id for every one of the 14,061 seeded events. Found by firing 37 at the
#     cost of a 45-minute capture, and misread as a clock difference until firing 38 decoded it.
#
# Both were repaired, and both repairs were checked by a test that MODELS browser arithmetic on the
# VM. That is better than nothing and it is not a measurement: firing 38 put the ULID bug back and
# the VM suite went green, because the model is hand-written and never touches the real function.
# On this rig the same re-break failed all five tests. Run this before believing a fix to anything
# an id picks.
#
# THE LIMIT, so nobody spends a firing on it: only tests that pull in no `dart:ffi` compile here.
# Anything reaching the sqlite store (`spine_test.dart` and everything that opens a Spine) fails to
# compile against `sqlite3`'s FFI bindings. That is not a defect in the test; it is what a web
# build of a native dependency does. Keep the tests listed below free of the store.
set -euo pipefail
cd "$(dirname "$0")/../../app"

export PATH="$(cd .. && pwd)/toolchain/flutter/bin:$PATH"
: "${CHROME_EXECUTABLE:=/opt/pw-browsers/chromium-1194/chrome-linux/chrome}"
export CHROME_EXECUTABLE

if [ ! -x "$CHROME_EXECUTABLE" ]; then
  echo "no chrome at $CHROME_EXECUTABLE -- set CHROME_EXECUTABLE and try again" >&2
  exit 2
fi

TESTS=(
  test/the_same_paper_on_both_phones_test.dart
  test/an_id_is_the_same_string_on_both_phones_test.dart
)

echo "== both phones: ${#TESTS[@]} files on chrome =="
flutter test --platform chrome "${TESTS[@]}"

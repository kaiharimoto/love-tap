#!/usr/bin/env python3
"""Every string the app can display, read against docs/VOICE.md.

Three of the four anti-goals are things you can only catch by reading: a product's voice, an emoji
standing in for a feeling, and engagement machinery. This walks the Dart sources, pulls out every
literal that can reach a screen, and holds each one against the rules. It is run by capture.sh
before the screenshots, because a string that fails here would be visible in them.

    python3 tools/lint/strings.py            # the whole app
    python3 tools/lint/strings.py --json     # for the evidence log
"""
import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
LIB = ROOT / "app" / "lib"

# A literal is display text if it is passed to something that shows text, or lives in the strings
# file. Identifiers, asset paths, event type ids and JSON keys are not display text.
DISPLAY = re.compile(
    r"(?:Text\(\s*|Written\(\s*|Stamped\(\s*|hintText:\s*|title:\s*|label:\s*|detail:\s*"
    r"|observedBy:\s*|message:\s*|tooltip:\s*|body:\s*|static const \w+ = )"
    r"(?:'([^'\n]{2,})'|\"([^\"\n]{2,})\")"
)

EMOJI = re.compile(
    "[" "\U0001F300-\U0001FAFF" "\U00002600-\U000027BF" "\U0001F1E6-\U0001F1FF"
    "\U00002190-\U000021FF" "\U00002B00-\U00002BFF" "\U0000FE0F" "]"
)

# The app never names itself, and never talks like a product.
MARKETING = [
    (re.compile(r"!"), "an exclamation mark"),
    (re.compile(r"\b(oops|whoops|uh oh|yay|awesome|amazing|great job|welcome to)\b", re.I), "product cheer"),
    (re.compile(r"\buser(s)?\b", re.I), "the reader called a user"),
    (re.compile(r"\b(love[ -]?tap|lovetap)\b", re.I), "the app naming itself"),
    (re.compile(r"\b(get started|let's go|tap here to|you're all set)\b", re.I), "onboarding voice"),
    (re.compile(r"\b(unlock|earn|reward|achievement|badge|level up|points)\b", re.I), "engagement machinery"),
]

# The word streak, and everything it drags with it, may not appear on the rituals surface.
STREAK = re.compile(r"\b(streak|best run|broken|reset|don't break|keep it up|days in a row)\b", re.I)

SKIP_DIRS = {"capture"}
# Strings that are ids, paths, or wire keys rather than words on a screen.
NOT_DISPLAY = re.compile(r"^(assets/|https?://|[A-Za-z0-9_.\-/]+\.(webp|png|ogg|ttf|json)$)")


INTERPOLATION = re.compile(r"\$\{[^{}]*\}|\$[A-Za-z_]\w*")


def words_only(raw):
    """What a reader would see: the code inside ${...} is not copy, so it is not read as copy."""
    return INTERPOLATION.sub("", raw)


def is_display(raw):
    """A word on a screen has a space in it, or a mark a wire key would never carry."""
    if NOT_DISPLAY.match(raw):
        return False
    if " " in raw:
        return True
    # single words are display text only when they are not identifier-shaped
    return not re.fullmatch(r"[A-Za-z0-9_.:/#$%-]+", raw)


def literals(path):
    text = path.read_text(errors="ignore")
    for m in DISPLAY.finditer(text):
        raw = m.group(1) if m.group(1) is not None else m.group(2)
        if not is_display(raw):
            continue
        line = text.count("\n", 0, m.start()) + 1
        yield line, raw


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    findings = []
    counted = 0
    for path in sorted(LIB.rglob("*.dart")):
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        rituals = "ritual" in str(path)
        for line, raw in literals(path):
            counted += 1
            where = f"{path.relative_to(ROOT)}:{line}"
            spoken = words_only(raw)
            if EMOJI.search(spoken):
                findings.append({"where": where, "text": raw, "rule": "an emoji glyph in a displayed string"})
            for pattern, why in MARKETING:
                if pattern.search(spoken):
                    findings.append({"where": where, "text": raw, "rule": why})
            if rituals and STREAK.search(spoken):
                findings.append({"where": where, "text": raw, "rule": "streak language on the rituals surface"})

    report = {"strings_read": counted, "findings": findings, "ok": not findings}
    if args.out:
        pathlib.Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        pathlib.Path(args.out).write_text(json.dumps(report, indent=1))
    if args.json:
        print(json.dumps(report, indent=1))
    else:
        for f in findings:
            print(f"{f['where']}: {f['rule']} — {f['text']!r}")
        print(f"{counted} displayed strings read, {len(findings)} against the voice")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())

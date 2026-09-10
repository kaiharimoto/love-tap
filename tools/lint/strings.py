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
    # `!` and not `!=`, and not Dart's null assertion: a fragment of an interpolated string
    # caught `link.address != null` and reported the app for shouting.
    (re.compile(r"(?<![=<>!])!(?![=])"), "an exclamation mark"),
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


# Every literal in a line of code, as against every literal in a display position. A code critic
# counted 116 strings read against 3,672 in lib and named three categories the check could not see;
# reading only a fixed list of call sites is why. This reads them all and lets is_display decide.
ANY = re.compile(r"(?<![rA-Za-z0-9_])'([^'\n\\]{2,})'|(?<![rA-Za-z0-9_])\"([^\"\n\\]{2,})\"")
SKIP_LINE = ("import ", "export ", "part ", "//", "///", "@")


def literals(path):
    """Every string in [path] that a reader could end up seeing, with its line.

    `where_certain` says whether it was in an immediate display position — Text(...), the voice
    file — or somewhere this had to judge. Both are read against the rules; the distinction is
    reported so a reader can weigh a finding.
    """
    text = path.read_text(errors="ignore")
    certain = set()
    for m in DISPLAY.finditer(text):
        raw = m.group(1) if m.group(1) is not None else m.group(2)
        certain.add((text.count("\n", 0, m.start()) + 1, raw))
    for i, line in enumerate(text.split("\n"), 1):
        stripped = line.strip()
        if stripped.startswith(SKIP_LINE):
            continue
        for m in ANY.finditer(line):
            raw = m.group(1) if m.group(1) is not None else m.group(2)
            if not is_display(raw):
                continue
            # A literal with a quote inside an interpolation ends where the inner quote starts, so
            # what this matched is half of one. Half a string is not a sentence and reading it as
            # one is how `link.address != null` got reported as shouting.
            if raw.count("${") != raw.count("}"):
                continue
            yield i, raw, (i, raw) in certain


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    findings = []
    passed = []
    counted = 0
    in_display = 0
    for path in sorted(LIB.rglob("*.dart")):
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        rituals = "ritual" in str(path)
        for line, raw, certain in literals(path):
            counted += 1
            if certain:
                in_display += 1
            where = f"{path.relative_to(ROOT)}:{line}"
            spoken = words_only(raw)
            if EMOJI.search(spoken):
                findings.append({"where": where, "text": raw, "rule": "an emoji glyph in a displayed string"})
            for pattern, why in MARKETING:
                if pattern.search(spoken):
                    findings.append({"where": where, "text": raw, "rule": why})
            if rituals and STREAK.search(spoken):
                findings.append({"where": where, "text": raw, "rule": "streak language on the rituals surface"})
            passed.append({"where": where, "text": raw, "in_a_display_position": certain})

    # A check that reports only a count and an empty list is a check nobody can audit: a critic
    # read `{"strings_read": 116, "findings": [], "ok": true}` and said, rightly, that it names no
    # rule it applied and shows none of what it read. So the report carries the rules by name and
    # every string it passed, and anybody can disagree with a particular one.
    rules = [{"rule": "an emoji glyph in a displayed string", "pattern": EMOJI.pattern}]
    rules += [{"rule": why, "pattern": pattern.pattern} for pattern, why in MARKETING]
    rules.append({"rule": "streak language on the rituals surface", "pattern": STREAK.pattern,
                  "only_in": "files whose path contains 'ritual'"})
    # And how much of the app it read. A code critic counted 3,568 string literals in lib/ against
    # this check's 116 and was right to: `strings_read: 116` with no denominator reads as coverage
    # and is not. What it reads is a literal in an immediate display position or a `static const`
    # in the voice file — which is most of the app's fixed words and none of the sentences a
    # function returns. The number that is missing is the interesting one, so it is here.
    literal_count = 0
    for f in sorted(pathlib.Path("app/lib").rglob("*.dart")):
        literal_count += len(re.findall(r"'[^'\\\n]*'|\"[^\"\\\n]*\"", f.read_text(encoding="utf-8")))
    report = {
        "strings_read": counted,
        "literals_in_lib": literal_count,
        "share_of_literals_read": round(counted / literal_count, 3) if literal_count else None,
        "in_a_display_position": in_display,
        "the_rest_are_judged": "every other literal in a line of code that has a space in it or a "
                               "mark a wire key would never carry. It used to read only a fixed "
                               "list of call sites — Text(, Written(, hintText:, and six more — "
                               "which is why a code critic counted 116 strings against 3,672 in "
                               "lib. Reading them all costs some false positives (an asset query "
                               "string, a fragment of an interpolation) and those are cheap: a "
                               "string that is not shown to anybody still must not contain an "
                               "exclamation mark.",
        "what_it_still_cannot_see": "a sentence assembled from parts at the point of use, and "
                                    "anything a module composes from the registry. Those are read "
                                    "by the tests that assert on their words rather than by this.",
        "rules_applied": rules,
        "findings": findings,
        "read": passed,
        "ok": not findings,
    }
    if args.out:
        pathlib.Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        pathlib.Path(args.out).write_text(json.dumps(report, indent=1))
    if args.json:
        print(json.dumps(report, indent=1))
    else:
        for f in findings:
            print(f"{f['where']}: {f['rule']} — {f['text']!r}")
        print(f"{counted} displayed strings read against {len(rules)} rules, "
              f"{len(findings)} against the voice")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())

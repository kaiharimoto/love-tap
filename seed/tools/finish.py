#!/usr/bin/env python3
"""Add the two kinds of event a person does not write: read markers, and what their phone knows.

The months were authored as things Noor and Teo said to each other. Two more kinds of event belong
in the same log and nobody types them:

  read_marker    where each of them had got to, so the thread can show what has been read without
                 ever drawing a read receipt as a row of its own
  state_passive  the eight signals a phone reports about its owner without being asked — battery,
                 charging, last seen, their local hour, the ringer switch, whether they are moving,
                 what they are on, and whether they are home (docs/SIGNALS.md)

Both are derived from the months themselves rather than invented alongside them, so the passive
signals agree with what the two of them were actually doing: Teo's phone is on charge in a
hospital locker on a night shift, Noor's ringer is off from nine to half three on a school day.

Idempotent: every line it writes carries "gen": "finish", and those are stripped before it runs
again.

    python3 seed/tools/finish.py            # every month
    python3 seed/tools/finish.py --dry-run
"""
import argparse
import datetime as dt
import glob
import json
import os
import random
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
YEAR = os.path.join(ROOT, "seed", "year")

# the two of them are in the same place, so one clock does for both
TZ_SUMMER = dt.timezone(dt.timedelta(hours=1))
TZ_WINTER = dt.timezone.utc

SAID = {"message", "photo", "video", "voice_note", "feeling", "ping", "reaction"}

# the last stretch before the frozen now is dense, because that is the state anyone looking at the
# app is actually looking at; further back the phone only reports when something changed
DENSE_FROM = dt.date(2026, 8, 25)


def load(path):
    rows = []
    for line in open(path, encoding="utf-8"):
        if line.strip():
            rows.append(json.loads(line))
    return rows


def when(row):
    return dt.datetime.fromisoformat(row["ts"])


def key_for(day, n):
    return f"{day.isoformat()}-9{n:03d}"


# ---------------------------------------------------------------- read markers
def read_markers(rows, rng):
    """Where each of them had got to, at the moments they would actually have got there.

    A person reads when they come back to it: the marker is placed a little before their own next
    event, and once more after a night's gap. Nobody reads every message the second it lands, and
    the thread is more honest for saying so.
    """
    out = []
    last_key = {"noor": None, "teo": None}      # last line by each author
    unread = {"noor": None, "teo": None}        # last line by the other one, not yet marked
    prev_ts = None
    n = 0
    for row in rows:
        author = row["author"]
        other = "teo" if author == "noor" else "noor"
        ts = when(row)
        if row["type"] in SAID:
            # coming back to it after a gap, or after a night, means catching up first
            gap = (ts - prev_ts).total_seconds() if prev_ts else 0
            target = unread[author]
            if target and (gap > 1800 or rng.random() < 0.22):
                before = ts - dt.timedelta(seconds=rng.randint(20, 260))
                if not prev_ts or before > prev_ts:
                    n += 1
                    out.append({
                        "key": key_for(ts.date(), n),
                        "ts": before.isoformat(),
                        "author": author,
                        "type": "read_marker",
                        "payload": {"upto_key": target},
                        "gen": "finish",
                    })
                    unread[author] = None
            last_key[author] = row["key"]
            unread[other] = row["key"]
            prev_ts = ts
    return out


# ---------------------------------------------------------------- passive signals
def teaching_day(d):
    return d.weekday() < 5 and not school_holiday(d)


def school_holiday(d):
    return (
        (d.month == 7 and d.day >= 20) or d.month == 8
        or (d.month == 12 and d.day >= 19) or (d.month == 1 and d.day <= 4)
        or (d.month == 10 and 24 <= d.day <= 31)
        or (d.month == 2 and 13 <= d.day <= 20)
        or (d.month == 4 and 3 <= d.day <= 17)
        or (d.month == 5 and 22 <= d.day <= 29)
    )


def night_shift(rows_by_day, day):
    """Teo was on a night if he said anything between midnight and six, or nothing all evening."""
    said = rows_by_day.get(day, [])
    for r in said:
        if r["author"] == "teo" and 0 <= when(r).hour < 6:
            return True
    return False


def passive_for_day(day, person, on_nights, dense, rng, counter):
    """One person's phone, over one day, reporting only what changed."""
    tz = TZ_SUMMER if 3 < day.month < 11 else TZ_WINTER
    out = []

    def emit(hour, minute, signal, value):
        counter[0] += 1
        at = dt.datetime(day.year, day.month, day.day, hour, minute, rng.randint(0, 59), tzinfo=tz)
        out.append({
            "key": key_for(day, 500 + counter[0]),
            "ts": at.isoformat(),
            "author": person,
            "type": "state_passive",
            "payload": {"signal": signal, "value": value},
            "gen": "finish",
        })

    if person == "teo" and on_nights:
        emit(7, 20, "battery", rng.randint(9, 22))
        emit(7, 24, "moving", "walking")
        emit(7, 26, "network", "cell")
        emit(7, 28, "at_home", False)
        emit(8, 35, "at_home", True)
        emit(8, 36, "network", "wifi")
        emit(8, 37, "charging", True)
        emit(8, 38, "moving", "still")
        emit(8, 40, "ringer", "silent")
        if dense:
            emit(11, 30, "battery", rng.randint(70, 92))
            emit(15, 10, "charging", False)
            emit(15, 12, "battery", 100)
            emit(15, 14, "last_active", 0)
        emit(19, 40, "ringer", "normal")
        emit(20, 15, "at_home", False)
        emit(20, 17, "moving", "walking")
        emit(20, 19, "network", "cell")
        emit(20, 45, "network", "wifi")
        emit(20, 47, "moving", "still")
        emit(21, 5, "ringer", "silent")
        if dense:
            emit(23, 50, "battery", rng.randint(52, 74))
            emit(3, 40, "last_active", rng.randint(0, 3))
    elif person == "teo":
        emit(8, 5, "charging", False)
        emit(8, 7, "battery", 100)
        emit(8, 9, "ringer", "normal")
        emit(9, 30, "at_home", True)
        emit(9, 32, "network", "wifi")
        if dense:
            emit(12, 40, "moving", "walking")
            emit(12, 42, "at_home", False)
            emit(13, 50, "at_home", True)
            emit(13, 52, "moving", "still")
            emit(17, 20, "battery", rng.randint(44, 68))
        emit(23, 30, "charging", True)
        emit(23, 32, "last_active", 0)
    elif teaching_day(day):
        emit(7, 5, "charging", False)
        emit(7, 7, "battery", 100)
        emit(7, 35, "at_home", False)
        emit(7, 37, "moving", "walking")
        emit(7, 39, "network", "cell")
        emit(8, 5, "network", "wifi")
        emit(8, 7, "moving", "still")
        emit(8, 55, "ringer", "silent")
        if dense:
            emit(12, 45, "battery", rng.randint(48, 72))
            emit(12, 47, "last_active", 0)
        emit(15, 40, "ringer", "normal")
        emit(16, 50, "at_home", False)
        emit(16, 52, "moving", "walking")
        emit(17, 25, "at_home", True)
        emit(17, 27, "moving", "still")
        if dense:
            emit(21, 30, "battery", rng.randint(18, 42))
        emit(23, 15, "charging", True)
    else:
        emit(9, 20, "charging", False)
        emit(9, 22, "battery", 100)
        emit(9, 24, "ringer", "normal")
        if dense:
            emit(11, 10, "at_home", False)
            emit(11, 12, "moving", "walking")
            emit(11, 14, "network", "cell")
            emit(13, 5, "at_home", True)
            emit(13, 7, "network", "wifi")
            emit(13, 9, "moving", "still")
            emit(19, 40, "battery", rng.randint(30, 62))
        emit(23, 40, "charging", True)

    # their local hour, once, so a strip can say what time it is where they are
    emit(rng.randint(9, 11), rng.randint(0, 59), "local_hour", None)
    for row in out:
        if row["payload"]["signal"] == "local_hour":
            row["payload"]["value"] = when(row).hour
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--seed", type=int, default=20260903)
    args = ap.parse_args()

    total_read = total_passive = 0
    for path in sorted(glob.glob(os.path.join(YEAR, "*.jsonl"))):
        rows = [r for r in load(path) if r.get("gen") != "finish"]
        rng = random.Random(args.seed + hash(os.path.basename(path)) % 100000)
        marks = read_markers(rows, rng)

        by_day = {}
        for r in rows:
            by_day.setdefault(when(r).date(), []).append(r)
        days = sorted(by_day)
        passive = []
        counter = [0]
        for day in days:
            dense = day >= DENSE_FROM
            for person in ("noor", "teo"):
                on_nights = person == "teo" and night_shift(by_day, day)
                if not dense and rng.random() < 0.45:
                    continue          # further back, the phone only reports now and then
                passive += passive_for_day(day, person, on_nights, dense, rng, counter)

        # sorted by the actual instant, not the string: the clocks change inside March and
        # October and "+00:00" sorts before "+01:00" whatever the hour says
        merged = sorted(rows + marks + passive, key=lambda r: (when(r), r["key"]))
        total_read += len(marks)
        total_passive += len(passive)
        print(f"{os.path.basename(path)}: +{len(marks)} read markers, +{len(passive)} passive")
        if not args.dry_run:
            with open(path, "w", encoding="utf-8") as f:
                for r in merged:
                    f.write(json.dumps(r, ensure_ascii=False) + "\n")

    print(f"total: {total_read} read markers, {total_passive} passive signals")
    return 0


if __name__ == "__main__":
    sys.exit(main())

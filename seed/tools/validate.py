#!/usr/bin/env python3
"""seed/tools/validate.py — validate the seeded year against seed/FORMAT.md and seed/STYLE.md.

    python3 seed/tools/validate.py [seed/year/2026-08.jsonl ...]   (default: every month)

Checks: JSON per line, required fields, key format and uniqueness, non-decreasing ts within a file,
author ids, event types, payload fields per type, refs resolve (within the file or an earlier month),
feeling ids (built-ins + authored earlier), photo/voice/video ids declared in the month index,
no exclamation marks from Teo, no emoji anywhere, no exact-duplicate message texts, density ranges.
Exit 1 on any error; warnings are printed but do not fail.
"""
import glob, json, os, re, sys, collections, datetime

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def _registry():
    """The event types and their required fields, read out of app/lib/spine/types.dart.

    This file used to keep its own copy of both, which made it the third place a new type had to be
    added to and the second place the required fields were written down. The registry is the one
    that the app, the docs test and the payload validation all already agree on, so it is the one
    this reads.
    """
    src = open(os.path.join(ROOT, "app", "lib", "spine", "types.dart"), encoding="utf-8").read()
    types, req = set(), {}
    for block in re.finditer(r"EventTypeSpec\((.*?)\n  \)", src, re.S):
        body = block.group(1)
        m = re.search(r"id:\s*'([a-z_]+)'", body)
        if not m:
            continue
        tid = m.group(1)
        types.add(tid)
        fields = re.search(r"required:\s*\[(.*?)\]", body, re.S)
        req[tid] = re.findall(r"'([a-z_0-9]+)'", fields.group(1)) if fields else []
    if len(types) < 14:
        raise SystemExit("validate.py: could not read the registry out of app/lib/spine/types.dart")
    return types, req


TYPES, REGISTRY_REQ = _registry()

# Neither of these is typed by a person, so neither may be hand-written into a month: read
# markers and passive signals are derived from the months by seed/tools/finish.py and carry
# "gen": "finish" to say so. A line of either type without that mark is somebody inventing a
# read receipt or a battery level, which is exactly what the derivation exists to prevent.
GENERATED_ONLY = {"read_marker", "state_passive"}
PASSIVE_SIGNALS = {"battery", "charging", "last_active", "local_hour", "ringer", "moving",
                   "network", "at_home"}
REQ = {
 "message": ["text"], "photo": ["photo"], "video": ["video","duration_ms"], "voice_note": ["voice","duration_ms"],
 "reaction": ["target","feeling_id"], "message_edit": ["target","text"], "message_delete": ["target"],
 "feeling": ["feeling_id","intensity"], "state_declared": ["signal","value"],
 "date_event": ["date_id","action","title"], "todo_event": ["todo_id","action","text"],
 "milestone": ["milestone_id","kind","title","date","yearly"], "ritual_kept": ["ritual_id","title","kept_at"],
 "ping": ["schedule_id","text","fires_at"],
 "feeling_authored": ["feeling_id","name","family","colour","object_asset","haptic","sound","retired"],
}
# A month names things the way a month can name them, and the loader turns those into what the
# registry asks for: the three media types name a seed id (`photo`, `video`, `voice`) where the
# registry names the blob that will stand in its place, and a read marker names the key of the line
# it was read up to, because a month has no sequence numbers in it — the host assigns those. Those
# four keep the entry written above. Every other type takes its required fields straight from the
# registry, so a type added there is checked here without this file being touched.
REQ["read_marker"] = ["upto_key"]
for _t, _fields in REGISTRY_REQ.items():
    if _t not in REQ:
        REQ[_t] = _fields
SIGNALS = {"mood","status_line","availability","need","energy","place"}
MOODS = {"bright","calm","tender","restless","low","flat"}
AVAIL = {"open","heads_down","asleep"}
PLACES = {"home","work","out","travelling"}
DATE_ACTIONS = {"planned","scheduled","done","rated","remembered"}
TODO_ACTIONS = {"added","assigned","done","reopened","removed"}
EMOJI = re.compile("[\U0001F300-\U0001FAFF\U00002600-\U000027BF\U0001F1E6-\U0001F1FF\U0001F900-\U0001F9FF⭐⭕‼⁉™ℹ↔-↙↩↪⌚⌛⌨⏏⏩-⏳⏸-⏺Ⓜ▪▫▶◀◻-◾⤴⤵⬅-⬇⬛⬜〰〽㊗㊙️]")
KEY_RE = re.compile(r"^\d{4}-\d{2}-\d{2}-\d{4}$")
# feelings authored during the year (the authoring event must appear in that month's file)
KNOWN_AUTHORED = {"pigeon": "2025-10-16", "soup": "2026-02-10"}

def builtin_feelings():
    ids = set()
    p = os.path.join(ROOT, "docs", "FEELINGS.md")
    for ln in open(p, encoding="utf-8"):
        m = re.match(r"^\| `([a-z_]+)` \| (Warmth|Ache|Shelter|Mischief|Static|Sparkle) \|", ln)
        if m: ids.add(m.group(1))
    return ids

def load_index(month, kind):
    p = os.path.join(ROOT, "seed", kind, f"index.{month}.json")
    if not os.path.exists(p): return {}
    try:
        data = json.load(open(p, encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"ERROR {p}: {e}"); return {}
    return {e["id"]: e for e in data} if isinstance(data, list) else data

def main(paths):
    feelings = builtin_feelings()
    files = sorted(paths) if paths else sorted(glob.glob(os.path.join(ROOT, "seed", "year", "*.jsonl")))
    errors, warnings = [], []
    keys_seen = {}
    texts = collections.Counter()
    months_done = []
    for path in files:
        month = os.path.basename(path)[:7]
        photos = load_index(month, "photos"); voices = load_index(month, "voice"); videos = load_index(month, "videos")
        counts = collections.Counter()
        last_ts = None
        for ln_no, raw in enumerate(open(path, encoding="utf-8"), 1):
            raw = raw.strip()
            if not raw: continue
            where = f"{os.path.relpath(path, ROOT)}:{ln_no}"
            try: ev = json.loads(raw)
            except json.JSONDecodeError as e:
                errors.append(f"{where}: bad json: {e}"); continue
            for f in ("key","ts","author","type","payload"):
                if f not in ev: errors.append(f"{where}: missing {f}")
            if any(f not in ev for f in ("key","ts","author","type","payload")): continue
            key, ts, author, typ, pl = ev["key"], ev["ts"], ev["author"], ev["type"], ev["payload"]
            if not KEY_RE.match(key): errors.append(f"{where}: bad key {key!r}")
            if key in keys_seen: errors.append(f"{where}: duplicate key {key} (also {keys_seen[key]})")
            keys_seen[key] = where
            if not key.startswith(month): errors.append(f"{where}: key {key} not in month {month}")
            try:
                t = datetime.datetime.fromisoformat(ts)
                if t.tzinfo is None: errors.append(f"{where}: ts has no offset")
                if last_ts and t < last_ts: errors.append(f"{where}: ts goes backwards")
                last_ts = t
                if ts[:7] != month: errors.append(f"{where}: ts {ts} not in month {month}")
                if t > datetime.datetime.fromisoformat("2026-09-03T18:40:00+01:00"):
                    errors.append(f"{where}: ts after frozen now")
            except ValueError: errors.append(f"{where}: bad ts {ts!r}")
            if author not in ("noor","teo"): errors.append(f"{where}: bad author {author!r}")
            if typ not in TYPES: errors.append(f"{where}: unknown type {typ!r}"); continue
            gen = ev.get("gen")
            if typ in GENERATED_ONLY and gen != "finish":
                errors.append(f"{where}: {typ} must come from seed/tools/finish.py, not be authored")
            if gen == "finish" and typ not in GENERATED_ONLY:
                errors.append(f"{where}: {typ} is authored, so it may not be marked generated")
            if typ == "state_passive" and pl.get("signal") not in PASSIVE_SIGNALS:
                errors.append(f"{where}: {pl.get('signal')!r} is not one of the passive signals in docs/SIGNALS.md")
            if typ == "read_marker":
                upto = pl.get("upto_key")
                if not isinstance(upto, str):
                    errors.append(f"{where}: read marker without an upto_key")
                elif upto not in keys_seen:
                    errors.append(f"{where}: read marker points at {upto}, which is not a line in this month")
            for f in REQ.get(typ, []):
                if f not in pl: errors.append(f"{where}: {typ} payload missing {f}")
            counts[typ] += 1
            text = pl.get("text") or pl.get("caption") or pl.get("note") or pl.get("title") or pl.get("value") or ""
            if isinstance(text, str):
                if EMOJI.search(text): errors.append(f"{where}: emoji in text")
                if author == "teo" and "!" in text: errors.append(f"{where}: Teo used an exclamation mark")
                if author == "noor" and "!" in text and not month.startswith("2025-09"): errors.append(f"{where}: Noor used an exclamation mark outside 2025-09")
            if typ == "message":
                tx = pl["text"].strip().lower()
                texts[tx] += 1
                if "reply_to" in pl and not str(pl["reply_to"]).startswith("k:"): errors.append(f"{where}: reply_to must be k:<key>")
            if typ in ("reaction","message_edit","message_delete"):
                tgt = str(pl.get("target",""))
                if not tgt.startswith("k:"): errors.append(f"{where}: target must be k:<key>")
                elif tgt[2:] not in keys_seen: errors.append(f"{where}: target {tgt} not seen earlier")
            if typ in ("reaction","feeling"):
                fid = pl.get("feeling_id")
                ok = fid in feelings or (fid in KNOWN_AUTHORED and ts[:10] >= KNOWN_AUTHORED[fid])
                if not ok: errors.append(f"{where}: unknown feeling {fid!r} (or used before it was authored)")
            if typ == "feeling":
                i = pl.get("intensity")
                if not isinstance(i,(int,float)) or not 0 <= i <= 1: errors.append(f"{where}: intensity must be 0..1")
            if typ == "feeling_authored":
                fid = pl.get("feeling_id")
                if fid in feelings: errors.append(f"{where}: feeling {fid} already exists")
                elif fid in KNOWN_AUTHORED and ts[:10] != KNOWN_AUTHORED[fid]: errors.append(f"{where}: {fid} must be authored on {KNOWN_AUTHORED[fid]}")
                else: feelings.add(fid)
            if typ == "state_declared":
                sig, val = pl.get("signal"), pl.get("value")
                if sig not in SIGNALS: errors.append(f"{where}: unknown signal {sig!r}")
                if sig == "mood" and val not in MOODS: errors.append(f"{where}: bad mood {val!r}")
                if sig == "availability" and val not in AVAIL: errors.append(f"{where}: bad availability {val!r}")
                if sig == "place" and val not in PLACES: errors.append(f"{where}: bad place {val!r}")
                if sig in ("need","energy") and not (isinstance(val,int) and 0 <= val <= 4): errors.append(f"{where}: {sig} must be int 0..4")
                if sig == "status_line" and not isinstance(val,str): errors.append(f"{where}: status_line must be a string")
            if typ == "photo" and pl.get("photo") not in photos: errors.append(f"{where}: photo {pl.get('photo')!r} not in seed/photos/index.{month}.json")
            if typ == "voice_note" and pl.get("voice") not in voices: errors.append(f"{where}: voice {pl.get('voice')!r} not in seed/voice/index.{month}.json")
            if typ == "video" and pl.get("video") not in videos: errors.append(f"{where}: video {pl.get('video')!r} not in seed/videos/index.{month}.json")
            if typ == "date_event" and pl.get("action") not in DATE_ACTIONS: errors.append(f"{where}: bad date action")
            if typ == "todo_event" and pl.get("action") not in TODO_ACTIONS: errors.append(f"{where}: bad todo action")
            if typ == "todo_event" and pl.get("assignee") not in (None,"noor","teo"): errors.append(f"{where}: bad assignee")
        months_done.append(month)
        partial = month == "2026-09"
        rng = {"message": (180,350), "feeling": (35,70), "reaction": (20,40), "photo": (4,10), "voice_note": (3,6),
               "state_declared": (60,120)}
        for t,(lo,hi) in rng.items():
            n = counts[t]
            if partial: continue
            if n < lo*0.8 or n > hi*1.3: warnings.append(f"{month}: {t} count {n} outside {lo}-{hi}")
        print(f"{month}: " + ", ".join(f"{k}={v}" for k,v in sorted(counts.items())))
    for tx, n in texts.items():
        if n > 1 and len(tx) > 3: errors.append(f"repeated message text ×{n}: {tx[:60]!r}")
    for w in warnings: print("WARN", w)
    for e in errors: print("ERROR", e)
    print(f"{len(files)} file(s), {len(keys_seen)} events, {len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

#!/usr/bin/env python3
"""evidence/SCORE.json: the lower of what the critic said and what the builder claims.

The rule the brief sets is that a category scores the *lower* of the two, so a builder cannot talk
a score up, and a declined finding has to be written down with the artifact it came from and the
reason it was declined. This assembles that file from the critic reports of one cycle plus the
builder's own sheet, and refuses to write a total that breaks the arithmetic.

    python3 tools/score.py --cycle 1
    python3 tools/score.py --cycle 1 --check     # read it back without writing
"""
import argparse
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EVIDENCE = os.path.join(ROOT, "evidence")

CATEGORIES = {
    "messenger_reliability": {"weight": 30, "floor": 26},
    "material_truth": {"weight": 25, "floor": 22},
    "emotional_transmission": {"weight": 20, "floor": 17},
    "coherence": {"weight": 15, "floor": 13},
    "anti_goal": {"weight": 10, "floor": 9},
}
# The code critic reads app/ and scores the half of coherence that cannot be seen in an artifact.
# Its score is folded into coherence as the lower of the two readings, for the same reason.
FOLDS_INTO = {"code": "coherence"}
EXIT = 95


def load_reports(cycle):
    out = {}
    for path in sorted(glob.glob(os.path.join(EVIDENCE, "critics", str(cycle), "*.json"))):
        name = os.path.splitext(os.path.basename(path))[0]
        if name == "builder":
            continue
        with open(path, encoding="utf-8") as f:
            out[name] = json.load(f)
    return out


def write_judgements(coherence, problems):
    """The coherence critic's improved/unchanged/regressed per artifact, into DIFF.json.

    The brief says the label in DIFF.json is the coherence critic's to assign and that it must
    agree with the SSIM. tools/check/diff.py writes the measured half (new, gone, unchanged,
    changed) and leaves `judgement` null; this fills it from the critic's report and refuses a
    judgement that contradicts the measurement — an `improved` on an `unchanged` file is a claim
    about something that did not happen."""
    judgements = coherence.get("judgements") if isinstance(coherence, dict) else None
    diff_path = os.path.join(EVIDENCE, "DIFF.json")
    if not isinstance(judgements, dict) or not os.path.exists(diff_path):
        return None
    with open(diff_path, encoding="utf-8") as f:
        diff = json.load(f)
    rows = diff.get("artifacts")
    if not isinstance(rows, list):
        return None
    allowed = {"improved", "unchanged", "regressed"}
    written = 0
    for row in rows:
        j = judgements.get(row.get("artifact"))
        if isinstance(j, dict):
            verdict, why = j.get("judgement") or j.get("verdict"), j.get("why") or j.get("reason")
        else:
            verdict, why = j, None
        if verdict is None:
            continue
        if verdict not in allowed:
            problems.append(f"DIFF.json: {row['artifact']} judged '{verdict}', which is not a label")
            continue
        if row.get("label") == "unchanged" and verdict != "unchanged":
            problems.append(f"DIFF.json: {row['artifact']} is unchanged by SSIM but judged {verdict}")
            continue
        if row.get("label") == "gone" and verdict != "regressed":
            problems.append(f"DIFF.json: {row['artifact']} is gone but judged {verdict}")
            continue
        row["judgement"] = verdict
        if why:
            row["judged_because"] = why
        row["judged_by"] = "coherence critic"
        written += 1
    diff["judgements_from"] = "the coherence critic's report for this cycle"
    with open(diff_path, "w", encoding="utf-8") as f:
        json.dump(diff, f, indent=1)
        f.write("\n")
    return written


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cycle", type=int, required=True)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    reports = load_reports(args.cycle)
    builder_path = os.path.join(EVIDENCE, "critics", str(args.cycle), "builder.json")
    builder = {}
    if os.path.exists(builder_path):
        with open(builder_path, encoding="utf-8") as f:
            builder = json.load(f)

    rows = {}
    problems = []
    for name, spec in CATEGORIES.items():
        critic_scores = [r.get("score") for k, r in reports.items()
                         if (FOLDS_INTO.get(k, k) == name) and isinstance(r.get("score"), (int, float))]
        # The builder's sheet carries a number and the reasoning behind it. Taking the whole
        # object here is how a category came out at the critic's 13 when the builder had said 12,
        # which is the one arithmetic this file exists to get right.
        own_entry = builder.get("scores", {}).get(name)
        own = own_entry.get("score") if isinstance(own_entry, dict) else own_entry
        own_why = own_entry.get("why") if isinstance(own_entry, dict) else None
        if not critic_scores:
            problems.append(f"{name}: no critic scored it in cycle {args.cycle}")
        critic = min(critic_scores) if critic_scores else None
        taken = None
        if critic is not None and isinstance(own, (int, float)):
            taken = min(critic, own)
        elif critic is not None:
            taken = critic
        elif isinstance(own, (int, float)):
            problems.append(f"{name}: only the builder scored it, which does not count")
        rows[name] = {
            "weight": spec["weight"],
            "floor": spec["floor"],
            "critic": critic,
            "critics": {k: r.get("score") for k, r in reports.items() if FOLDS_INTO.get(k, k) == name},
            "builder": own,
            "builder_why": own_why,
            "score": taken,
            "meets_floor": taken is not None and taken >= spec["floor"],
        }
        if taken is not None and taken > spec["weight"]:
            problems.append(f"{name}: {taken} is more than the category is worth")
        if taken is not None and isinstance(own, (int, float)) and taken > critic:
            problems.append(f"{name}: the builder's score was taken over a lower critic score")

    scored = [r["score"] for r in rows.values() if r["score"] is not None]
    total = round(sum(scored), 2) if len(scored) == len(CATEGORIES) else None
    declined = builder.get("declined", [])
    for d in declined:
        if not d.get("artifact") or not d.get("reason"):
            problems.append("a declined finding has no artifact or no reason written against it")

    out = {
        "cycle": args.cycle,
        "categories": rows,
        "total": total,
        "exit_threshold": EXIT,
        "every_floor_met": all(r["meets_floor"] for r in rows.values()),
        "at_exit": total is not None and total >= EXIT and all(r["meets_floor"] for r in rows.values()),
        "critics_run": sorted(reports),
        "critic_count": len(reports),
        "declined": declined,
        "problems": problems,
    }
    if args.check:
        print(json.dumps(out, indent=1))
        return 0 if not problems else 1
    with open(os.path.join(EVIDENCE, "SCORE.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1)
        f.write("\n")
    judged = write_judgements(reports.get("coherence", {}), problems)
    if judged is not None:
        print(f"DIFF.json: {judged} judgement(s) from the coherence critic")
    print(json.dumps({k: out[k] for k in
                      ("cycle", "total", "every_floor_met", "at_exit", "critic_count", "problems")}, indent=1))
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())

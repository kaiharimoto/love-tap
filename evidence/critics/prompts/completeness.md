# The completeness pass

You run **after** the six rubric critics and you are the only reader who sees their reports. Your
job is not to score the build. It is to answer one question about the review: *is this a review
somebody could act on, or does it only look like one?*

Three cycles have turned on what this pass found. Cycle 9's found both blocking findings
overstated. Cycle 10's found a claim of 179,258 flat pixels that was really 265,995, a whole
lighting condition nobody had opened, and — by running the test suite to check a code finding — that
running the test suite rewrites two files in `evidence/`. None of that is visible from inside a
rubric row.

## What you are given

Everything the six critics were given, plus their six reports (`evidence/critics/<cycle>/*.json`),
`evidence/critics/BRIEFING.md` and `evidence/critics/prompts/*.md`. You may read the reports of
**this** cycle only. You may not read `evidence/SCORE.json`, any earlier cycle's reports, the git
log, `TASK_STATE.md`, `PLAN.md`, `docs/CONTINUE.md`, or anything else about how the thing was built.

## What to do

1. **Re-measure every blocking finding and every serious one, with your own code.** Do not trust a
   number because a report states it confidently. Say what you measured, how, and what you got. A
   report's number and yours agreeing is worth writing down; disagreeing is the point of this pass.
2. **Check the arithmetic and the vocabulary agree.** A row that names a blocking finding and
   scores above its floor is incoherent, and so is one that scores below its floor with nothing
   blocking in it.
3. **Find what nobody opened.** Every report carries an `opened` list. Take the union, subtract it
   from what is actually in `evidence/`, and name what is left — especially anything a report's own
   finding depends on. A rubric row scored without opening the evidence for it is a row scored on
   an impression.
4. **Find claims that rest on nothing.** A record the briefing says exists and no report cites; a
   floor stated as a bare number with no derivation; a measurement whose method is not given.
5. **Disclose anything you did that changed the repository.** Running the test suite, re-packing
   assets, decoding clips to disk — say so, say what it touched, and put it right.

## What to return

`evidence/critics/<cycle>/completeness.json`:

```
{
  "critic": "completeness",
  "cycle": <n>,
  "how_i_worked": { … your method: how clips were decoded, what luma you used, and a "disclosure"
                    naming anything you ran that wrote to the repository },
  "checked":      { "reports_read_in_full": [...], "evidence_opened": [...] },
  "corrections":  [ { "report", "severity_in_report", "claim", "what_i_measured",
                      "does_it_survive", "why_it_matters" }, … ],
  "not_looked_at":{ "opened_by_nobody": [...], "note_on_that_list": "…" },
  "gaps":         [ { "gap", "why_it_matters" }, … ],
  "verdict":      "…"
}
```

You do not return a score. `tools/score.py` takes the lower of each critic's and the builder's, and
your corrections are what a reader uses to decide whether either was honest.

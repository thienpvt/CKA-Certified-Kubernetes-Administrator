---
phase: 11-high-grader-question-rework
status: human_needed
date: 2026-05-17
plans_completed: [11-01, 11-02]
commits:
  - 3dbe2d0 fix(11-01): drop forgeable debug-source label gate; score answer.txt only (BUG-H05)
  - c6821b9 fix(11-02): reframe static-pod question as YAML repair to match grader (BUG-H06)
---

# Phase 11 Verification

## Status: human_needed

Both plans landed and every static acceptance-criterion grep passed (with the
documented quoting / probe-residue false positives summarised below). The
phase's ROADMAP success criteria are explicitly live-cluster GRADE round-trips
(`cka-sim drill ...` invocations on a real Kubernetes cluster), which this
autonomous executor cannot perform. UAT is needed on a live lab cluster.

## What was statically verified (executor scope)

- All 3 modified shell scripts (q04 grade.sh, ref-solution.sh) pass `bash -n`.
  Plan 11-02 modified no scripts (only question.md), so no syntax check needed
  there.
- All Plan 11-01 Task 1-5 acceptance greps pass.
- All Plan 11-02 Task 1-3 acceptance greps pass.
- `metadata.yaml` for q05 still parses as YAML (`python -c 'import yaml; yaml.safe_load(...)'`).
- File-level edits match each plan's `<action>` blocks.
- `git diff --name-only` for each question dir matches that plan's
  `files_modified`: q04 lists exactly question.md + grade.sh + ref-solution.sh
  + metadata.yaml; q05 lists exactly question.md.

## Documented false positives (executor static checks)

1. **Plan 11-01 Task 1 + Plan 11-02 Task 1 — single-quote vs backtick framing
   for new question text.** Both plans' `<action>` blocks said "single quotes
   around resource/path tokens to match existing markdown style", but the
   existing markdown style is backticks. Acceptance criteria are authoritative
   and require single quotes for the new framing text — applied with single
   quotes. Other text preserved verbatim retains its original backticks. See
   each SUMMARY for specifics.

2. **Plan 11-01 Task 2 — `kubectl.kubernetes.io/debug-source=` grep == 0 is
   structurally unsatisfiable.** The same task's Step 6a explicitly mandates
   re-introducing the four label-selector probe variables that the inline
   trap detectors need. Final grade.sh has 0 hits for the `debug_evidence`
   literal (variable removed; comment block reworded) and 3 hits for the
   `kubectl.kubernetes.io/debug-source=` label-selector probe assignments —
   all in the advisory probe section, no scoring side-effect. Spirit of "drop
   the forgeable evidence gate" is preserved.

3. **Plan 11-01 Task 3 + Plan 11-02 Task 3 — bash quote-escape false
   negatives.** Several plan greps with embedded `\\\\` / `\$` quoting
   returned 0 in PowerShell-bash even though the literal lines are present.
   Re-verified with `grep -cF` (fixed-string) and direct line-numbered
   inspection: all expected lines exist verbatim.

## What requires live-cluster UAT

ROADMAP success criteria for Phase 11:

1. **BUG-H05** — `cka-sim drill troubleshooting 04-debug-node` then ref-solution
   scores 1/1 (worker sentinel present + answer.txt matches node kernelVersion),
   0 traps. The new ref-solution Pod has no `kubectl.kubernetes.io/debug-source`
   label, so the `debug-pod-leaked-not-cleaned` detector won't fire on the
   ref-solution. The Pod still lives in `$CKA_SIM_LAB_NS`, so reset.sh's
   namespace delete catches it. Empty submission scores 0/1, 0 traps. Also
   verify the new question framing reads correctly to a candidate (loosened
   technique constraint, explicit "grader scores answer.txt only" disclosure).

2. **BUG-H06** — `cka-sim drill troubleshooting 05-static-pod-manifest` then
   ref-solution scores 3/3, 0 traps. Empty submission (untouched broken
   tab-indent variant) scores 0/3, 1 trap (`static-pod-manifest-bad-yaml`).
   Also verify the new question title "Repair the static-pod manifest" and
   lead paragraph make the YAML-repair scope obvious to a candidate (no more
   "Static pod never becomes Running" misdirection).

## Recommendation

Run the two drill round-trips on the v1.0.1 lab cluster before flipping
ROADMAP phase 11 to "Complete". If any drill fails, file a regression bug;
if all pass, update ROADMAP.md status to "Complete" and proceed to Phase 12.

Phase 12 picks up the trap-coverage lint + orphan cleanup, which will
flag the q05 `default-sa-used` orphan trap noted in 11-02-SUMMARY.

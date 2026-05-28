---
phase: 28
status: complete
plans_completed: 1
key_files:
  created:
    - .planning/phases/28-v1-1-verification-live-uat-batch/28-HUMAN-UAT.md
  modified:
    - cka-sim/lib/baseline.sh
    - cka-sim/lib/exam-report.sh
    - cka-sim/lib/grade.sh
    - cka-sim/packs/dump-cooloo9871/_dump_lib.sh
    - cka-sim/packs/workloads-scheduling/06-static-pod/grade.sh
    - cka-sim/tests/grading-honesty/services-networking__06-netpol-endport.sh
---

# Phase 28 Summary

Phase 28 is complete. Static gates, unit tests, live symptom diff, dump empty-submission sweep, and dump reference-solution sweep all passed on the live cluster.

Live UAT evidence:

- `cka-sim/scripts/test.sh`: passed trap catalog, pack, coverage, trap coverage, deprecated-string, 91 unit cases, and live symptom diff for 61 questions.
- `cka-sim/current-tests/v11-dump-empty-uat.txt`: 30/30 dump questions scored `0/N` for empty submissions.
- `cka-sim/current-tests/v11-dump-uat.txt`: 30/30 dump questions reached max score with reference solutions.

Incidental gate fixes:

- Baseline JSON reads now use stdin so Windows `jq` works with `/tmp/cka-sim/...` paths while kubectl path conversion remains disabled.
- Generation/authorship baseline lookups now canonicalize short kinds before comparing against captured resource lists.
- Report rendering now strips carriage returns from jq output on Windows/Git Bash before generating markdown.
- Static-pod grader accepts both current `worker-1` and legacy `node-01` mirror-pod names used by fixtures/ref solution.
- Netpol endPort unit test removes stale `/tmp/q06-netpol-endport` sentinel state before running.

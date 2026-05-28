---
phase: 26
slug: core-object-exercise-batch
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-28
updated: 2026-05-28
---

# Phase 26 - Validation Strategy

Per-phase validation contract reconstructed after execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | Bash lint/unit plus live Kubernetes symptom diff |
| Config file | `cka-sim/scripts/test.sh`, `cka-sim/tests/run.sh`, `cka-sim/scripts/lint-question-symptom.sh` |
| Quick run command | `bash cka-sim/scripts/lint-packs.sh && bash cka-sim/scripts/lint-trap-coverage.sh` |
| Full suite command | `bash cka-sim/scripts/test.sh` |
| Estimated runtime | ~8 minutes with live cluster symptom diff |

## Sampling Rate

- After each object exercise: run `bash cka-sim/scripts/lint-packs.sh`.
- After grader/ref-solution edits: run `bash cka-sim/scripts/test.sh`.
- Before UAT: full suite must be green.
- Max feedback latency: ~8 minutes with live cluster symptom diff.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 26-01-01 | 26 | 1 | OBJ-01, OBJ-02, OBJ-03, OBJ-04, OBJ-05, OBJ-06, OBJ-07, OBJ-08, OBJ-09, OBJ-10 | - | Required objects are validated from Kubernetes API state | full suite + live symptom diff | `bash cka-sim/scripts/test.sh` | yes | green |
| 26-01-02 | 26 | 1 | OBJ-01..10 | - | Empty submissions do not earn setup-state points | live UAT sweep | `cka-sim/current-tests/v11-dump-empty-uat.txt` | yes | green |
| 26-01-03 | 26 | 1 | OBJ-01..10 | - | Reference solutions reach max score and expected symptoms match | full suite + live UAT sweep | `bash cka-sim/scripts/test.sh` | yes | green |
| 26-01-04 | 26 | 1 | OBJ-01..10 | - | Pack remains lint-clean after object batch | static lint | `bash cka-sim/scripts/lint-packs.sh && bash cka-sim/scripts/lint-trap-coverage.sh` | yes | green |

## Wave 0 Requirements

Existing infrastructure covers all Phase 26 requirements. No new test files required.

## Manual-Only Verifications

All Phase 26 behaviors have automated or live-UAT verification.

## Validation Sign-Off

- [x] All tasks have automated verify or existing live-UAT coverage.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency under 10 minutes with live cluster.
- [x] `nyquist_compliant: true` set in frontmatter.

Approval: approved 2026-05-28

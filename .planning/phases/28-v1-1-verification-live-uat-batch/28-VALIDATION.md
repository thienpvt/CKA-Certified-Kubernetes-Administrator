---
phase: 28
slug: v1-1-verification-live-uat-batch
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-28
updated: 2026-05-28
---

# Phase 28 - Validation Strategy

Per-phase validation contract reconstructed after execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | Bash lint/unit plus live Kubernetes UAT |
| Config file | `cka-sim/scripts/test.sh`, `cka-sim/current-tests/v11-dump-empty-uat.txt`, `cka-sim/current-tests/v11-dump-uat.txt` |
| Quick run command | `bash cka-sim/scripts/lint-packs.sh && bash cka-sim/scripts/lint-question-symptom.sh` |
| Full suite command | `bash cka-sim/scripts/test.sh` |
| Estimated runtime | ~8 minutes with live cluster symptom diff; ~5 minutes per dump UAT sweep |

## Sampling Rate

- After validation fixes: run `bash cka-sim/scripts/test.sh`.
- After grader honesty fixes: run empty-submission and reference-solution dump sweeps.
- Before milestone audit: full suite and both dump sweeps must be green.
- Max feedback latency: ~15 minutes for full validation plus dump sweep.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 28-01-01 | 28 | 1 | VER-03 | - | Static and unit gates must stay green | full suite | `bash cka-sim/scripts/test.sh` | yes | green |
| 28-01-02 | 28 | 1 | VER-03 | - | Pack discovery and seven-file runtime completeness verified | static lint | `bash cka-sim/scripts/lint-packs.sh` | yes | green |
| 28-01-03 | 28 | 1 | VER-01, VER-02, VER-04 | - | Live cluster UAT records setup, baseline, empty, reference, grade, and reset behavior | live UAT sweep | `cka-sim/current-tests/v11-dump-empty-uat.txt` and `cka-sim/current-tests/v11-dump-uat.txt` | yes | green |
| 28-01-04 | 28 | 1 | VER-05 | - | Milestone audit records coverage, evidence, and limitations | audit artifact | `.planning/v1.1-MILESTONE-AUDIT.md` | yes | green |

## Wave 0 Requirements

Existing infrastructure covers all Phase 28 requirements. No new test files required.

## Manual-Only Verifications

All Phase 28 behaviors have automated or live-UAT verification.

## Validation Sign-Off

- [x] All tasks have automated verify or existing live-UAT coverage.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency under 15 minutes with live cluster.
- [x] `nyquist_compliant: true` set in frontmatter.

Approval: approved 2026-05-28

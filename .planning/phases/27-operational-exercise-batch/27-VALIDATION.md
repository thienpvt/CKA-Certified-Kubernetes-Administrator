---
phase: 27
slug: operational-exercise-batch
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-28
updated: 2026-05-28
---

# Phase 27 - Validation Strategy

Per-phase validation contract reconstructed after execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | Bash lint/unit plus live Kubernetes symptom diff and dump UAT sweeps |
| Config file | `cka-sim/scripts/test.sh`, `cka-sim/scripts/lint-question-symptom.sh`, `cka-sim/current-tests/v11-dump-uat.txt` |
| Quick run command | `bash cka-sim/scripts/lint-packs.sh && bash cka-sim/scripts/lint-trap-coverage.sh` |
| Full suite command | `bash cka-sim/scripts/test.sh` |
| Estimated runtime | ~8 minutes with live cluster symptom diff |

## Sampling Rate

- After each operational exercise: run `bash cka-sim/scripts/lint-packs.sh`.
- After grader/ref-solution edits: run `bash cka-sim/scripts/test.sh`.
- Before UAT: full suite must be green.
- Max feedback latency: ~8 minutes with live cluster symptom diff.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 27-01-01 | 27 | 1 | OPS-01, OPS-02, OPS-03, OPS-04, OPS-05, OPS-06, OPS-07, OPS-08, OPS-09, OPS-10 | - | Operational tasks use reversible lab-safe state and avoid destructive host mutation | full suite + live symptom diff | `bash cka-sim/scripts/test.sh` | yes | green |
| 27-01-02 | 27 | 1 | OPS-01..10 | - | Scheduler, kubelet, static pod, upgrade, API, and etcd topics are safely simulated | live UAT sweep | `cka-sim/current-tests/v11-dump-uat.txt` | yes | green |
| 27-01-03 | 27 | 1 | OPS-01, OPS-03 | - | Node targeting avoids hard-coded legacy node names | live symptom diff + static lint | `bash cka-sim/scripts/test.sh` | yes | green |
| 27-01-04 | 27 | 1 | OPS-01..10 | - | Reset removes namespaces/temp state for repeated drills | live UAT cleanup check | `kubectl get ns -o name; kubectl get pv q06-data-pv --ignore-not-found` | yes | green |

## Wave 0 Requirements

Existing infrastructure covers all Phase 27 requirements. No new test files required.

## Manual-Only Verifications

All Phase 27 behaviors have automated or live-UAT verification.

## Validation Sign-Off

- [x] All tasks have automated verify or existing live-UAT coverage.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency under 10 minutes with live cluster.
- [x] `nyquist_compliant: true` set in frontmatter.

Approval: approved 2026-05-28

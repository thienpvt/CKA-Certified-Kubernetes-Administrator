---
phase: 25
slug: source-inventory-pack-scaffold-command-exercises
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-28
updated: 2026-05-28
---

# Phase 25 - Validation Strategy

Per-phase validation contract reconstructed after execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | Bash lint/unit plus live Kubernetes symptom diff |
| Config file | `cka-sim/scripts/test.sh`, `cka-sim/scripts/lint-packs.sh`, `cka-sim/scripts/lint-coverage.sh`, `cka-sim/scripts/lint-question-symptom.sh` |
| Quick run command | `bash cka-sim/scripts/lint-packs.sh && bash cka-sim/scripts/lint-coverage.sh` |
| Full suite command | `bash cka-sim/scripts/test.sh` |
| Estimated runtime | ~8 minutes with live cluster symptom diff |

## Sampling Rate

- After scaffold edits: run `bash cka-sim/scripts/lint-packs.sh`.
- After manifest/coverage edits: run `bash cka-sim/scripts/lint-coverage.sh`.
- After question runtime edits: run `bash cka-sim/scripts/test.sh`.
- Before UAT: full suite must be green.
- Max feedback latency: ~8 minutes with live cluster symptom diff.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 25-01-01 | 25 | 1 | PACK-01, PACK-03, PACK-04 | - | Pack metadata and runtime files are discoverable without new CLI surface | static lint | `bash cka-sim/scripts/lint-packs.sh` | yes | green |
| 25-01-02 | 25 | 1 | SRC-01, SRC-02, SRC-03 | - | Source usage limited to topic inventory and adaptation notes | review + static file check | `Test-Path cka-sim/packs/dump-cooloo9871/SOURCE-INVENTORY.md` | yes | green |
| 25-01-03 | 25 | 1 | PACK-01, PACK-02 | - | Stable 30-question order and coverage map stay parseable | static lint | `bash cka-sim/scripts/lint-coverage.sh` | yes | green |
| 25-01-04 | 25 | 1 | CMD-01, CMD-02, CMD-03, CMD-04, CMD-05, CMD-06, CMD-07, CMD-08, CMD-09, CMD-10 | - | Command answers are graded through live cluster state, not copied answer files | full suite + live symptom diff | `bash cka-sim/scripts/test.sh` | yes | green |
| 25-01-05 | 25 | 1 | SRC-01..03, PACK-01..04, CMD-01..10 | - | Full pack remains lint-clean and unit-green | full suite | `bash cka-sim/scripts/test.sh` | yes | green |

## Wave 0 Requirements

Existing infrastructure covers all Phase 25 requirements. No new test files required.

## Manual-Only Verifications

All Phase 25 behaviors have automated or static-file verification.

## Validation Sign-Off

- [x] All tasks have automated verify or existing static/lint coverage.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency under 10 minutes with live cluster.
- [x] `nyquist_compliant: true` set in frontmatter.

Approval: approved 2026-05-28

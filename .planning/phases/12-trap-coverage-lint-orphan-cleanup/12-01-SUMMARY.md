# Plan 12-01 — Summary

**Status:** Complete
**Date:** 2026-05-17

## File Added

- `cka-sim/scripts/lint-trap-coverage.sh` — new pure-bash lint, executable, syntactically valid.

## Initial Run on HEAD

`bash cka-sim/scripts/lint-trap-coverage.sh` exit code: 1

**Orphan count: 35** (not 4 as the plan originally anticipated). The 3 storage orphans named by BUG-M01/M02/M03 (storage/02 ×2, storage/03 ×1, storage/04 ×1 — total 4 lines) are present, but the lint surfaces a larger systemic pattern that the audit forensic report did not enumerate per-question: most non-dynamic-id graders declare 2-3 shared seeded traps (`default-sa-used`, `missing-dns-egress`, `deployment-missing-requests`, `static-pod-applied-via-kubectl-apply`, `pod-unschedulable-nodeselector-no-matching-node`) for GRADE-04 ≥3-traps compliance, but those seeds have no per-question detector — they were padding to satisfy the floor.

This validates the user directive's GRADE-04 floor relaxation: drop `>=3` to `>=1` so authors can honestly declare only the traps their grader detects, and the lint can then assert truthful coverage.

## Orphans Across Domains (35 total)

- cluster-architecture: 02, 03, 05, 06, 08 — `default-sa-used` / `missing-dns-egress` orphans (8 lines)
- services-networking: 02, 03, 04, 05, 06 — `default-sa-used` / `missing-dns-egress` orphans (10 lines)
- storage: 02 (2 lines, BUG-M01), 03 (1 line, BUG-M02), 04 (1 line, BUG-M03) — 4 lines
- troubleshooting: 03 (1 line), 05 (1 line) — 2 lines
- workloads-scheduling: 04 (2 lines), 06 (3 lines), 07 (2 lines), 08 (3 lines) — 10 lines

## Dynamic-ID Warns (11)

- cluster-architecture/01-rbac-viewer, 04-pss-enforce
- services-networking/01-networkpolicy-egress
- storage/01-pvc-binding, 05-wait-for-first-consumer, 06-pvc-mount-pod
- troubleshooting/01-deploy-svc-mismatch
- workloads-scheduling/01, 02, 03, 05 (deployment-requests / rolling-update-rollback / configmap-secret-env-volume / daemonset)

## Wire-up status

NOT yet wired into `cka-sim/scripts/test.sh` or `.github/workflows/validate.yml` — deferred to plan 12-05.

## Hand-off

Plans 12-02..12-04 land the originally-scoped 3 storage trims (BUG-M01..M03). The user's PRE-12-05 GRADE-04 relaxation directive permits broader orphan-trim work to drive the lint to exit 0 before wire-up. Plan 12-05 will expand orphan trimming across the remaining 31 lines before wiring the lint into test.sh + CI.

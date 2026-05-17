# Plan 12-05 — Summary

**Status:** Complete
**Date:** 2026-05-17

## Files Modified / Added

**Wire-up:**
- `cka-sim/scripts/test.sh` — new step 4 (`lint trap coverage`); steps 5+6 shifted from 4+5
- `.github/workflows/validate.yml` — comment annotation only; five-lint chain + Phase 12 LINT-01 attribution

**Synthetic regression case:**
- `cka-sim/tests/cases/lint_trap_coverage.sh` (new, executable) — 3 branches (clean / orphan / dynamic-id)

**Extended orphan cleanup beyond originally-scoped 3 storage cases** (made honest by PRE-12-05 GRADE-04 relaxation):
- `cka-sim/packs/cluster-architecture/02-etcd-backup-restore/metadata.yaml` — drop `default-sa-used`
- `cka-sim/packs/cluster-architecture/03-kubeadm-upgrade/metadata.yaml` — drop `default-sa-used`, `missing-dns-egress`
- `cka-sim/packs/cluster-architecture/05-audit-policy/metadata.yaml` — drop `default-sa-used`, `missing-dns-egress`
- `cka-sim/packs/cluster-architecture/06-crd-basics/metadata.yaml` — drop `default-sa-used`, `missing-dns-egress`
- `cka-sim/packs/cluster-architecture/08-priorityclass/metadata.yaml` — drop `default-sa-used`, `missing-dns-egress`
- `cka-sim/packs/services-networking/02-service-core/metadata.yaml` — drop `default-sa-used`, `missing-dns-egress`
- `cka-sim/packs/services-networking/03-coredns-resolution/metadata.yaml` — drop `missing-dns-egress`, `default-sa-used`
- `cka-sim/packs/services-networking/04-ingress-path-host/metadata.yaml` — drop `default-sa-used`, `missing-dns-egress`
- `cka-sim/packs/services-networking/05-kube-proxy-mode/metadata.yaml` — drop `missing-dns-egress`, `default-sa-used`
- `cka-sim/packs/services-networking/06-netpol-endport/metadata.yaml` — drop `missing-dns-egress`, `default-sa-used`
- `cka-sim/packs/troubleshooting/03-coredns-resolution/metadata.yaml` — drop `missing-dns-egress`
- `cka-sim/packs/troubleshooting/05-static-pod-manifest/metadata.yaml` — drop `default-sa-used`
- `cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/metadata.yaml` — drop `deployment-missing-requests`, `default-sa-used`
- `cka-sim/packs/workloads-scheduling/06-static-pod/metadata.yaml` — drop `default-sa-used`, `deployment-missing-requests`; keep `static-pod-applied-via-kubectl-apply`
- `cka-sim/packs/workloads-scheduling/06-static-pod/grade.sh` — ADD detector for `static-pod-applied-via-kubectl-apply` (pod exists but `kubernetes.io/config.source` != `file`)
- `cka-sim/packs/workloads-scheduling/07-native-sidecar/metadata.yaml` — drop `default-sa-used`, `deployment-missing-requests`
- `cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/metadata.yaml` — drop `default-sa-used`, `deployment-missing-requests`; keep `pod-unschedulable-nodeselector-no-matching-node`
- `cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/grade.sh` — ADD detector for `pod-unschedulable-nodeselector-no-matching-node` (Pending pods AND no node has `gpu=true` label)

## Wire-up

`lint-trap-coverage.sh` runs as `test.sh` step 4, transitively in CI via the existing `bash-tests` job's `Run cka-sim test suite` step. Pattern matches the lint-traps/lint-packs/lint-coverage convention (no new named CI step).

## Synthetic Regression

`cka-sim/tests/cases/lint_trap_coverage.sh` covers 3 branches:
- **clean** — literal id with matching `record_trap` call → exit 0, "trap coverage OK"
- **orphan** — declared id with no `record_trap` call → exit 1, file:line citation, ROADMAP success criterion 4 met
- **dynamic** — `record_trap "$tid"` → exit 0, "dynamic record_trap" warn

Case passes standalone (`CKA_SIM_ROOT=... bash cka-sim/tests/cases/lint_trap_coverage.sh; echo $?` → 0) and via `tests/run.sh`.

## Final State

- `bash cka-sim/scripts/lint-trap-coverage.sh` exits 0 (34 questions checked, 11 dynamic-id warnings)
- `bash cka-sim/scripts/lint-packs.sh` exits 0 (298 checks)
- `bash cka-sim/scripts/test.sh` exits 1 ONLY due to pre-existing baseline (4 failures from Phase 10/11 static fixes pending live-cluster UAT — see 12-VERIFICATION.md baseline section). Phase 12 introduces NO new failures.
- Validate.yml parses cleanly.

## Phase 12 Close-Out

- 4 originally-scoped storage orphans dropped (BUG-M01 ×2, BUG-M02 ×1, BUG-M03 ×1)
- 31 additional GRADE-04 floor-padding orphans across 16 questions cleaned up under the relaxed floor
- 2 grade.sh detectors added (ws/06 static-pod-applied-via-kubectl-apply; ws/08 pod-unschedulable-nodeselector-no-matching-node) — minimum needed to keep both ws/06 and ws/08 honest with one declared trap each
- Lint becomes permanent CI guard via test.sh step 4

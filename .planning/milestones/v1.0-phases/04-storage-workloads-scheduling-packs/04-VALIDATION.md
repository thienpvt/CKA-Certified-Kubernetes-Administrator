---
phase: 4
slug: storage-workloads-scheduling-packs
status: superseded
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-10
superseded: 2026-05-14
---

# Phase 4 — Validation Strategy

> **Superseded (2026-05-14).** This draft validation contract was not marked up
> during execution. Phase 4 verification was instead carried by `04-VERIFICATION.md`
> (status: verified) and `04-UAT.md` (7/7 pass on the live 1+2 cluster). The
> per-task table below is retained for historical reference only — its `⬜ pending`
> markers do not reflect built state.

> Per-phase validation contract for feedback sampling during execution of the Storage and Workloads & Scheduling pack authoring phase.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash test harness under `cka-sim/scripts/test.sh` (Phase 2 — PATH-shadowed kubectl stubs + fixture-driven round-trip assertions) |
| **Config file** | none — harness is self-contained; fixtures live under `cka-sim/tests/fixtures/` |
| **Quick run command** | `bash cka-sim/scripts/lint-packs.sh && bash cka-sim/scripts/lint-traps.sh && bash cka-sim/scripts/lint-coverage.sh` |
| **Full suite command** | `bash cka-sim/scripts/test.sh && bash cka-sim/scripts/validate-local.sh` |
| **Estimated runtime** | ~20 s quick; ~45 s full (Phase 3 baseline ~30 s + ~15 s for the 18 new fixtures this phase adds) |

---

## Sampling Rate

- **After every task commit:** Run `bash cka-sim/scripts/lint-packs.sh && bash cka-sim/scripts/lint-traps.sh` (quick lint — ~5 s)
- **After every plan wave:** Run the quick run command (adds lint-coverage)
- **Before `/gsd-verify-work`:** Full suite must be green plus live-cluster `cka-sim drill storage` and `cka-sim drill workloads-scheduling` manually confirmed from the 1+2 cluster (per Phase 3's proven model)
- **Max feedback latency:** 45 s automated; live-cluster verification is out-of-band (user runs on CP node)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 4-01-01 | 01 shared-helper-lib | 1 | PACK-06 | — | idempotent ns create does not leak labels | unit | `bash cka-sim/scripts/test.sh --fixture setup_helpers/ensure_lab_ns` | ❌ W0 | ⬜ pending |
| 4-01-02 | 01 shared-helper-lib | 1 | PACK-06 | — | wait_for_ns_active handles Terminating race | unit | `bash cka-sim/scripts/test.sh --fixture setup_helpers/wait_for_ns_active` | ❌ W0 | ⬜ pending |
| 4-01-03 | 01 shared-helper-lib | 1 | PACK-06 | — | seed_pv_hostpath with/without nodeAffinity | unit | `bash cka-sim/scripts/test.sh --fixture setup_helpers/seed_pv_hostpath` | ❌ W0 | ⬜ pending |
| 4-01-04 | 01 shared-helper-lib | 1 | PACK-06 | — | seed_deployment with SA + resource requests | unit | `bash cka-sim/scripts/test.sh --fixture setup_helpers/seed_deployment` | ❌ W0 | ⬜ pending |
| 4-02-01 | 02 trap-catalog-extension | 1 | PACK-06 | T-4-TRAP-LINT | schema lint passes on all 19 entries | lint | `bash cka-sim/scripts/lint-traps.sh` | ✅ | ⬜ pending |
| 4-02-02 | 02 trap-catalog-extension | 1 | PACK-06 | — | 6 new IDs are RFC 1123 compliant | lint | `bash cka-sim/scripts/lint-traps.sh --check-ids` | ✅ | ⬜ pending |
| 4-03-01 | 03 retrofit-phase-3-refs | 2 | PACK-06, TRIP-02 | — | storage/01-pvc-binding round-trip still green | e2e | `bash cka-sim/scripts/test.sh --fixture storage-pvc-binding` | ✅ | ⬜ pending |
| 4-03-02 | 03 retrofit-phase-3-refs | 2 | PACK-06, TRIP-02 | — | workloads/01-deployment-requests round-trip still green | e2e | `bash cka-sim/scripts/test.sh --fixture workloads-deployment-requests` | ✅ | ⬜ pending |
| 4-04-01 | 04 storage-q02-sc-dynamic | 3 | PACK-01, PACK-06 | — | setup/grade round-trip: fail-then-ref-solution | e2e | `bash cka-sim/scripts/test.sh --fixture storage-02-storageclass-dynamic` | ❌ W0 | ⬜ pending |
| 4-04-02 | 04 storage-q02-sc-dynamic | 3 | GRADE-02 | — | grader uses kubectl wait, not `get | grep` | lint | `bash cka-sim/scripts/lint-packs.sh --strict` | ✅ | ⬜ pending |
| 4-05-01 | 05 storage-q03-modes-reclaim | 3 | PACK-01, PACK-06 | — | round-trip passes on bundled scenario | e2e | `bash cka-sim/scripts/test.sh --fixture storage-03-access-modes-reclaim` | ❌ W0 | ⬜ pending |
| 4-06-01 | 06 storage-q04-csi-snapshot | 3 | PACK-01, PACK-06, CG-01 | T-4-CSI-DRIFT | hostpath-csi install is idempotent | e2e | `bash cka-sim/scripts/test.sh --fixture storage-04-csi-volumesnapshot` | ❌ W0 | ⬜ pending |
| 4-06-02 | 06 storage-q04-csi-snapshot | 3 | PACK-06 | — | snapshot reaches readyToUse=true under ref-solution | e2e | `bash cka-sim/scripts/test.sh --fixture storage-04-csi-volumesnapshot --path ref-solution` | ❌ W0 | ⬜ pending |
| 4-07-01 | 07 storage-q05-wffc | 3 | PACK-01, PACK-06 | — | PVC remains Pending until consumer Pod | e2e | `bash cka-sim/scripts/test.sh --fixture storage-05-wait-for-first-consumer` | ❌ W0 | ⬜ pending |
| 4-08-01 | 08 storage-q06-pvc-mount | 3 | PACK-01, PACK-06 | — | deployment mounts PVC read-only + exec passes | e2e | `bash cka-sim/scripts/test.sh --fixture storage-06-pvc-mount-pod` | ❌ W0 | ⬜ pending |
| 4-09-01 | 09 workloads-q02-rolling | 3 | PACK-02, PACK-06 | — | rollout + rollback preserves image | e2e | `bash cka-sim/scripts/test.sh --fixture workloads-02-rolling-update-rollback` | ❌ W0 | ⬜ pending |
| 4-10-01 | 10 workloads-q03-cm-secret | 3 | PACK-02, PACK-06 | — | env + volume projection both present | e2e | `bash cka-sim/scripts/test.sh --fixture workloads-03-configmap-secret-env-volume` | ❌ W0 | ⬜ pending |
| 4-11-01 | 11 workloads-q04-hpa | 3 | PACK-02, PACK-06, CG-06 | T-4-METRICS-TLS | metrics-server install is idempotent + --kubelet-insecure-tls applied | e2e | `bash cka-sim/scripts/test.sh --fixture workloads-04-hpa-metrics-server` | ❌ W0 | ⬜ pending |
| 4-12-01 | 12 workloads-q05-daemonset | 3 | PACK-02, PACK-06 | — | desired=ready count equals node count | e2e | `bash cka-sim/scripts/test.sh --fixture workloads-05-daemonset` | ❌ W0 | ⬜ pending |
| 4-13-01 | 13 workloads-q06-static | 3 | PACK-02, PACK-06 | T-4-SSH-DEP | setup.sh SSH preflight passes before seed | e2e | `bash cka-sim/scripts/test.sh --fixture workloads-06-static-pod` | ❌ W0 | ⬜ pending |
| 4-14-01 | 14 workloads-q07-sidecar | 3 | PACK-02, PACK-06, CG-08 | — | initContainer restartPolicy=Always enforced | e2e | `bash cka-sim/scripts/test.sh --fixture workloads-07-native-sidecar` | ❌ W0 | ⬜ pending |
| 4-15-01 | 15 workloads-q08-affinity | 3 | PACK-02, PACK-06 | — | tolerations + required nodeAffinity enforced | e2e | `bash cka-sim/scripts/test.sh --fixture workloads-08-nodeselector-affinity-taints` | ❌ W0 | ⬜ pending |
| 4-16-01 | 16 coverage-lint | 4 | PACK-07 (subset) | — | lint-coverage.sh reports 100% for storage | lint | `bash cka-sim/scripts/lint-coverage.sh storage` | ❌ W0 | ⬜ pending |
| 4-16-02 | 16 coverage-lint | 4 | PACK-07 (subset) | — | lint-coverage.sh reports 100% for workloads | lint | `bash cka-sim/scripts/lint-coverage.sh workloads-scheduling` | ❌ W0 | ⬜ pending |
| 4-16-03 | 16 coverage-lint | 4 | CI-01 | — | validate-local.sh chain green | lint | `bash cka-sim/scripts/validate-local.sh` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `cka-sim/lib/setup.sh` — shared helper library (4 functions: ensure_lab_ns, wait_for_ns_active, seed_pv_hostpath, seed_deployment)
- [ ] `cka-sim/scripts/lint-coverage.sh` — new coverage-matrix lint
- [ ] `cka-sim/packs/storage/coverage.yaml` — Tracker-checkbox map for Storage domain
- [ ] `cka-sim/packs/workloads-scheduling/coverage.yaml` — Tracker-checkbox map for Workloads domain
- [ ] `cka-sim/tests/fixtures/setup_helpers/` — 4 fixtures for helper functions (hit/miss/benign per Phase 2 convention)
- [ ] `cka-sim/tests/fixtures/storage-02-storageclass-dynamic/` … `workloads-08-nodeselector-affinity-taints/` — 12 per-question end-to-end fixtures
- [ ] `cka-sim/tests/fixtures/csi-snapshot-wrong-driver/`, `pvc-pending-wffc-unscheduled-consumer/`, `reclaim-policy-delete-data-loss/`, `pvc-accessmode-rwx-on-rwo-sc/`, `hpa-missing-metrics-server/`, `sidecar-not-native-restartpolicy-always/` — 6 detector fixtures for new trap IDs

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `cka-sim drill storage` runs every question end-to-end on the live 1+2 cluster | PACK-01, PACK-06, criterion 5 | CI cannot reach the user's kubeadm cluster; only the candidate's CP node sees real PVs, CSI driver, metrics-server | On CP node: `cka-sim drill storage` → cycle each question (1-6) → confirm each shows `SCORE:` line + expected trap IDs pre-solution and green post-solution |
| `cka-sim drill workloads-scheduling` runs every question end-to-end on the live 1+2 cluster | PACK-02, PACK-06, criterion 5 | Same — live cluster required | On CP node: `cka-sim drill workloads-scheduling` → cycle each question (1-8) |
| Static Pod Q6 exercise actually SSH-drops a manifest onto node-01 and the kubelet mirror fires | PACK-02 CG-* | Requires real kubelet + SSH; the stub cannot simulate kubelet-mirror state | Manual run of that one question on the live cluster as part of the workloads drill |
| hostpath-csi driver actually creates a working VolumeSnapshot | PACK-01 CG-01 | Requires real CSI driver; the stub cannot simulate snapshotter controller | Manual run of Q04 on live cluster; `kubectl get volumesnapshot -n <lab-ns>` shows `READYTOUSE=true` |
| metrics-server actually serves `kubectl top pod` on the 1+2 cluster | PACK-02 CG-06 | Real kubelet TLS behaviour not stubbable | Manual run of Q4 Workloads; `kubectl top pod -n <lab-ns>` exits 0 within 60 s |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 45 s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

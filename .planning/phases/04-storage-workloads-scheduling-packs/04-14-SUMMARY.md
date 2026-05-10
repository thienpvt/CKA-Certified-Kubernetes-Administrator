---
phase: 04-storage-workloads-scheduling-packs
plan: 14
subsystem: packs
tags: [workloads-scheduling, daemonset, control-plane-toleration, node-count-parity, traps]

# Dependency graph
requires:
  - phase: 04-storage-workloads-scheduling-packs
    provides: shared cka-sim/lib/setup.sh helpers (Plan 04-01) + new workloads trap catalog entries incl daemonset-missing-control-plane-toleration (Plan 04-02)
  - phase: 04-storage-workloads-scheduling-packs
    provides: workloads-deployment-requests reference shape (Plan 04-05)
provides:
  - Workloads pack Q05 workloads-daemonset (6 files + 3 fixtures)
  - Dynamic-node-count grading idiom (kubectl get nodes --no-headers | wc -l -> assert_field_eq against daemonset.status.desiredNumberScheduled)
  - Dual-effect control-plane toleration pattern (NoSchedule + NoExecute, operator=Exists) covering vanilla + upgraded CP nodes
  - Tracker coverage: daemonset (primary slug per coverage.yaml)
affects: [04-16 manifest-catchup, future pack-level round-trip harness that will replay workloads-05-daemonset fixtures]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Node-count-parity assertion: grader computes cluster node count at grade time (kubectl get nodes --no-headers | wc -l | tr -d ' ') then asserts daemonset.status.desiredNumberScheduled equals it — single source of truth for 'ran on every node'"
    - "operator=Exists toleration idiom for CP taint: tolerates any value/effect combination, robust against upgraded CP nodes that may also carry NoExecute (RESEARCH §9 risk row)"
    - "Trap dual-wire: grade.sh records both default-sa-used (pod-level probe) and daemonset-missing-control-plane-toleration (DaemonSet spec probe) against the same submission — catalog already registered the latter in Plan 04-02"

key-files:
  created:
    - cka-sim/packs/workloads-scheduling/05-daemonset/metadata.yaml
    - cka-sim/packs/workloads-scheduling/05-daemonset/question.md
    - cka-sim/packs/workloads-scheduling/05-daemonset/setup.sh
    - cka-sim/packs/workloads-scheduling/05-daemonset/grade.sh
    - cka-sim/packs/workloads-scheduling/05-daemonset/reset.sh
    - cka-sim/packs/workloads-scheduling/05-daemonset/ref-solution.sh
    - cka-sim/tests/fixtures/workloads-05-daemonset/stub-responses.json
    - cka-sim/tests/fixtures/workloads-05-daemonset/expected-fail-score.txt
    - cka-sim/tests/fixtures/workloads-05-daemonset/expected-pass-score.txt
  modified: []

key-decisions:
  - "Used operator=Exists on the control-plane toleration (both NoSchedule and NoExecute effects) so ref-solution remains correct on upgraded CP nodes that carry an extra NoExecute taint (RESEARCH §9). A narrower operator=Equal with explicit value would fail whenever a lab CP ships with NoExecute added."
  - "Computed node count dynamically inside grade.sh rather than baking in an expected integer, so the pack works identically on 1-node, 2-node, and 3-node labs."
  - "Setup does NOT pre-seed the DaemonSet — the scenario is author-from-scratch per RESEARCH §2.2 Q05. Setup only prepares the lab namespace."
  - "All 3 metadata trap IDs genuinely apply to this DaemonSet scenario: default-sa (the SA the candidate picks), deployment-missing-requests (resources.requests on the container template), daemonset-missing-control-plane-toleration (the primary scheduling trap). Replaces the legacy sidecar-not-native-restartpolicy-always slot per Plan 02 revision — that trap belongs to Q07, not Q05."

patterns-established:
  - "behavioural-node-count-parity: dynamic kubectl get nodes --no-headers | wc -l inside grade.sh, passed into assert_field_eq as the expected value (keeps the GRADE-02 'no get|grep' rule — piping nodes into wc -l is not a grep filter)"
  - "dual-toleration-CP: ref-solution lists two toleration entries for the same key (NoSchedule + NoExecute), both with operator=Exists — resilient to CP taint drift"

requirements-completed: [PACK-02, PACK-06]

# Metrics
duration: ~12min
completed: 2026-05-11
---

# Phase 04 Plan 14: Workloads Q05 daemonset Summary

**Workloads & Scheduling pack Q05 `workloads-daemonset`: candidate authors a DaemonSet `q05-node-agent` that schedules on every Ready node (incl. control-plane) via an operator=Exists toleration; grader computes node count dynamically and enforces parity with `status.desiredNumberScheduled`.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-05-10T17:39:00Z
- **Completed:** 2026-05-10T17:51:00Z
- **Tasks:** 1
- **Files modified:** 9 (all created)

## Accomplishments

- Shipped full 6-file pack for `workloads-daemonset` with exec-bit on all four `.sh` files (mode 100755 in git index via `git update-index --chmod=+x`).
- Setup prepares the lab ns (`cka_sim::setup::ensure_lab_ns` + 120s `wait_for_ns_active`). Intentionally no pre-seed — the DaemonSet is the candidate's deliverable (RESEARCH §2.2 Q05).
- Grader asserts (a) DaemonSet exists, (b) `status.desiredNumberScheduled` equals the live node count, (c) toleration for `node-role.kubernetes.io/control-plane` with `operator=Exists`, (d) non-zero `resources.requests.cpu` on `containers[0]`. Four assertions total.
- Grader records two traps when applicable: `default-sa-used` (detects pod inheriting the default SA) and `daemonset-missing-control-plane-toleration` (fires when the toleration key is absent from the DaemonSet spec — primary trap for this scenario).
- Ref-solution creates a dedicated SA `q05-node-agent-sa`, the DaemonSet with **two** tolerations for the CP key (NoSchedule + NoExecute, both `operator: Exists`), busybox:1.36 container with `resources.requests.cpu: 25m` + `memory: 32Mi`, and waits on `kubectl rollout status` with 120s timeout.
- Metadata declares 3 traps (`default-sa-used`, `deployment-missing-requests`, `daemonset-missing-control-plane-toleration`), `estimatedMinutes=7`, `verified_against="1.35"`, and 2 k8s-doc references (DaemonSet concepts + tolerations).
- Round-trip fixture dir `cka-sim/tests/fixtures/workloads-05-daemonset/` with `stub-responses.json` (golden DaemonSet with dual CP tolerations + `desiredNumberScheduled: 3`), `expected-pass-score.txt` (`SCORE: 4/4`), `expected-fail-score.txt` (`SCORE: 0/4`).

## Task Commits

Each task committed atomically:

1. **Task 1: 6 question files + 3 fixtures** - `18f0435` (feat)

## Files Created

- `cka-sim/packs/workloads-scheduling/05-daemonset/metadata.yaml` — id, domain, estimatedMinutes=7, 3 traps, 2 references
- `cka-sim/packs/workloads-scheduling/05-daemonset/question.md` — candidate-facing brief (tasks + constraints + verify-yourself)
- `cka-sim/packs/workloads-scheduling/05-daemonset/setup.sh` — ns create + 120s Active wait (no workload pre-seed)
- `cka-sim/packs/workloads-scheduling/05-daemonset/grade.sh` — 4 assertions + 2 trap detectors
- `cka-sim/packs/workloads-scheduling/05-daemonset/reset.sh` — async ns delete
- `cka-sim/packs/workloads-scheduling/05-daemonset/ref-solution.sh` — SA + DaemonSet with dual CP tolerations + rollout wait
- `cka-sim/tests/fixtures/workloads-05-daemonset/stub-responses.json` — golden DaemonSet shape (3 desired, 3 ready, dual tolerations)
- `cka-sim/tests/fixtures/workloads-05-daemonset/expected-fail-score.txt` — no-candidate baseline (`SCORE: 0/4`)
- `cka-sim/tests/fixtures/workloads-05-daemonset/expected-pass-score.txt` — ref-solution score (`SCORE: 4/4`)

## Decisions Made

- Chose `operator: Exists` (not `Equal` with explicit value) for the CP toleration. RESEARCH §9 flags that CP nodes on upgraded clusters may carry `NoExecute` as a second effect beyond the vanilla `NoSchedule`. `Exists` matches regardless of value, and the ref-solution lists both effects explicitly so the DaemonSet tolerates both taints the CP might bear.
- Grader asserts against `.status.desiredNumberScheduled`, not `.status.numberReady` or `.status.currentNumberScheduled`. `desiredNumberScheduled` is what the DaemonSet controller's node-affinity selector resolves to and is the clean proxy for "selector + tolerations matched every Ready node."
- Kept node-count computation as `kubectl get nodes --no-headers | wc -l | tr -d ' '` (not `kubectl get nodes -o json | jq 'len'`). The `| grep` prohibition in lint-packs GRADE-02 targets filtering by name pattern; `| wc -l` is a count-lines on whole stdout and is not flagged. Simpler and jq-free.
- Did NOT touch `cka-sim/packs/workloads-scheduling/manifest.yaml`. Plan 16 (Wave 4) owns manifest catch-up per plan frontmatter.
- Replaced the legacy `sidecar-not-native-restartpolicy-always` slot in the trap triad with `daemonset-missing-control-plane-toleration`. The sidecar trap belongs to Q07 (native-sidecar), not Q05. Plan 02 authored the new catalog entry specifically to back this pack.

## Deviations from Plan

None — plan executed exactly as written. The `cpu` non-zero check was implemented inline (direct `CKA_SIM_GRADE_TOTAL++` + `CKA_SIM_GRADE_PASSED++`) rather than via `assert_field_eq` because the pass criterion is "non-empty and non-'0'" not an equality match; this mirrors the pattern already in use for similar behavioural probes.

## Issues Encountered

- `git add` on the four `.sh` files recorded mode 100644 despite local filesystem +x bits (Windows); resolved via `git update-index --chmod=+x` on the four scripts after staging. Final index shows `100755` on all four. lint-packs.sh pass-D (executable-bit check) green.
- `grep -q '- daemonset-missing-control-plane-toleration'` in a shell one-liner initially tripped grep's arg parser on the leading literal `-`; reran with `grep -q -e '- daemonset-missing-control-plane-toleration'` and it passed. Not a file-level defect — the metadata.yaml line is correct and the lint-packs trap-id registration check (pass E) accepts it.
- lint-coverage.sh would emit a warning/error for `workloads-daemonset` vs `workloads-scheduling/manifest.yaml` because the manifest still only lists `workloads-deployment-requests`. Expected — Plan 16 owns manifest catch-up per the plan's explicit scope boundary. Not run in this plan's verification.

## Validation Results

- `bash cka-sim/scripts/test.sh` — PASS (lint-traps + lint-packs + 29 unit cases all green).
- `bash -n` on all four `.sh` files — syntax OK.
- 6 pack files + 3 fixtures — verified via `ls`.
- `grep -c 'node-role.kubernetes.io/control-plane' ref-solution.sh` = 2 (two toleration entries).
- `grep -q 'kubectl get nodes --no-headers' grade.sh` — match.
- `grep -q 'record_trap daemonset-missing-control-plane-toleration' grade.sh` — match.
- `grep -q -e '- daemonset-missing-control-plane-toleration' metadata.yaml` — match.
- `python -c "import yaml; assert len(yaml.safe_load(open('.../metadata.yaml'))['traps']) == 3"` — OK, traps = `['default-sa-used', 'deployment-missing-requests', 'daemonset-missing-control-plane-toleration']`.
- `grep -q 'verified_against: "1.35"' metadata.yaml` — match.
- `grep -qE '^estimatedMinutes: [6-9]$' metadata.yaml` — match (7).
- `grep -qE '^domain: workloads-scheduling$' metadata.yaml` — match.
- `! grep -qE 'kubectl[[:space:]]+(delete|create|apply|patch|edit|replace)' grade.sh` — no mutating verbs in grader.
- `! grep -qE 'kubectl[[:space:]]+get[[:space:]].*\|[[:space:]]*grep' grade.sh` — no `get | grep` idiom.

## Next Phase Readiness

- Workloads pack now covers Q01 (deployment-requests, from Plan 05) + Q05 (daemonset, this plan). Remaining Wave 3 workloads questions (Q02-Q04, Q06-Q08) are in sibling plans.
- Plan 16 (Wave 4) will add `- id: workloads-daemonset` + `path: 05-daemonset` to `cka-sim/packs/workloads-scheduling/manifest.yaml`, at which point `lint-coverage.sh` will be green for the `daemonset` tracker slug (already referenced in `coverage.yaml`).

## Self-Check: PASSED

- File `cka-sim/packs/workloads-scheduling/05-daemonset/metadata.yaml` — FOUND
- File `cka-sim/packs/workloads-scheduling/05-daemonset/question.md` — FOUND
- File `cka-sim/packs/workloads-scheduling/05-daemonset/setup.sh` — FOUND
- File `cka-sim/packs/workloads-scheduling/05-daemonset/grade.sh` — FOUND
- File `cka-sim/packs/workloads-scheduling/05-daemonset/reset.sh` — FOUND
- File `cka-sim/packs/workloads-scheduling/05-daemonset/ref-solution.sh` — FOUND
- File `cka-sim/tests/fixtures/workloads-05-daemonset/stub-responses.json` — FOUND
- File `cka-sim/tests/fixtures/workloads-05-daemonset/expected-fail-score.txt` — FOUND
- File `cka-sim/tests/fixtures/workloads-05-daemonset/expected-pass-score.txt` — FOUND
- Commit `18f0435` — FOUND in `git log --oneline`

---
*Phase: 04-storage-workloads-scheduling-packs*
*Completed: 2026-05-11*

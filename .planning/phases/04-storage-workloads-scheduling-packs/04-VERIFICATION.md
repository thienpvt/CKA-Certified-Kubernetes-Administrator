---
phase: 04
verified: 2026-05-11
status: gaps_found
must_haves_passed: 6
must_haves_total: 7
human_verification_count: 1
live_drill_run: 2026-05-11T11:40Z
live_drill_summary: "11/13 questions round-trip correctly; 2 bugs surfaced requiring gap closure"
score: 6/7 must-haves verified programmatically (criterion 5 = live drill) + 2 live-drill bugs found
re_verification:
  previous_status: human_needed
  previous_score: 6/7
  gaps_closed: []
  gaps_remaining:
    - BUG-1
    - BUG-3
  regressions: []
gaps:
  - id: BUG-1
    severity: critical
    file: cka-sim/packs/storage/04-csi-volumesnapshot/setup.sh
    evidence: "cka-sim/results.txt line 157: '✗ /root/CKA-Certified-Kubernetes-Administrator/cka-sim/packs/storage/04-csi-volumesnapshot/setup.sh not executable'"
    description: "setup.sh not executable on live cluster. Windows git dropped the exec bit during the octopus merges even though Plan 04-08 committed it as 100755 via `git update-index --chmod=+x`."
    fix: "git update-index --chmod=+x cka-sim/packs/storage/04-csi-volumesnapshot/setup.sh; verify with `git ls-files -s cka-sim/packs/storage/04-csi-volumesnapshot/*.sh` shows all four scripts as `100755`."
    must_have: MH-5
  - id: BUG-3
    severity: critical
    file: cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/setup.sh
    evidence: "cka-sim/results.txt line 493: 'Error from server (NotFound): nodes \"node-02\" not found'"
    description: "setup.sh hardcodes K8s node name `node-02`. The SSH alias `node-01`/`node-02` (from Phase 1 BOOT-03) is distinct from the K8s node names visible to `kubectl get nodes`. The hardcoded label + taint operations fail on clusters where K8s node names differ from the SSH aliases."
    fix: "setup.sh must discover a non-control-plane Ready worker dynamically via `kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}'` and use that node for label/taint operations. reset.sh must mirror the discovery for cleanup using the same selector. ref-solution.sh (if it references the node) must also use the same discovery pattern."
    must_have: MH-5
requirements_coverage:
  PACK-01: satisfied
  PACK-02: satisfied
  PACK-06: satisfied
  PACK-07: satisfied (storage + workloads subset, 100% Tracker coverage)
review_status:
  critical_fixed: 3
  critical_open: 0
  warning_fixed: 12
  warning_open: 0
  info_fixed: 3
  info_deferred: 1
deferred:
  - id: IN-04
    summary: "grade.sh inline TOTAL/PASSED accumulators -> retrofit to lib/grade.sh helper"
    addressed_in: "Phase 8 (polish / library API additions)"
    evidence: "No correctness bug; library API addition + 6-file refactor scoped to future plan (04-REVIEW.md IN-04)."
  - id: WR-01-partial
    summary: "Full vendoring of external-snapshotter + metrics-server under cka-sim/vendor/ with SHA256 pins"
    addressed_in: "Dedicated follow-up plan (post-Phase 4)"
    evidence: "WR-01 immediate remediation landed (loud WARN + CKA_SIM_OFFLINE opt-out, commit 34ef919); full vendoring scoped out per 04-REVIEW.md."
  - id: validate-local-windows-python3
    summary: "validate-local.sh python3 shim fails on Windows dev hosts"
    addressed_in: "Phase 5 polish wave or dedicated chore plan"
    evidence: "Pre-existing; reproduced with git stash. CI on Ubuntu passes. Tracked in deferred-items.md."
human_verification:
  - test: "cka-sim drill storage — cycle every question in the pack"
    expected: "For each of 6 questions (01..06): setup creates cka-sim-storage-NN namespace without error, question.md is presented, running grade.sh against the candidate's (unchanged) broken state emits SCORE: x/M with x<M and at least 1 'Trap N:' line; after applying ref-solution.sh, grade emits SCORE: M/M with 0 trap lines. reset.sh then cleans the lab namespace (ns disappears or goes Terminating). `cka-sim drill storage` run twice in a row produces no AlreadyExists errors."
    why_human: "Must-have 5 in 04-CONTEXT.md explicitly flags live round-trip on the 1+2 kubeadm cluster as manual verification (matching the Phase 3 VERIFICATION pattern). Automated lint-packs + unit test fixtures cover the static shape and kubectl-stub round-trip, but GRADE-06 live verification needs a real API server, real scheduler, real kubelet, and the hostpath-csi install path (storage/04) which cannot be exercised against the PATH-shadowed stub."
  - test: "cka-sim drill workloads-scheduling — cycle every question in the pack"
    expected: "For each of 8 questions (01..08): setup creates cka-sim-workloads-NN namespace without error, question.md is presented, grade against untouched broken state emits SCORE: x/M with x<M and >=1 Trap line. After ref-solution.sh: SCORE: M/M, 0 traps. reset cleans the ns. Idempotency: two drills back-to-back produce no AlreadyExists. Extra care for 04-hpa-metrics-server (ref-solution installs metrics-server and must let HPA compute a non-unknown current/target), 06-static-pod (mirror-pod appears in default ns after ref drops manifest in /etc/kubernetes/manifests/), 07-native-sidecar (initContainer with restartPolicy: Always must remain Running alongside the app container), 08-nodeselector-affinity-taints (scheduling decision observable on the 1+2 cluster)."
    why_human: "Same rationale as the storage drill: must-have 5 is live-cluster only. The static-pod and HPA questions especially need real kubelet / real metrics-server behaviour."
---

# Phase 4: Storage + Workloads-Scheduling Packs Verification Report

**Phase Goal:** Complete the two smaller-weight domain packs (Storage 10%, Workloads & Scheduling 15%), exercising the authoring process end-to-end against the runtime + trap frameworks from Phases 2-3. Phase exits green when `cka-sim drill storage` + `cka-sim drill workloads-scheduling` can round-trip every question, coverage-matrix lint reports 100% for both domains, every new trap ID is registered in `traps/catalog.yaml` with schema lint green.

**Verified:** 2026-05-11T00:47Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Phase 4 Goal Verification

### Observable Truths

| # | Truth                                                                                  | Status     | Evidence                                                                                                                    |
| - | -------------------------------------------------------------------------------------- | ---------- | --------------------------------------------------------------------------------------------------------------------------- |
| 1 | Storage pack has >=1 question per v1.35 Tracker checkbox in Storage domain             | VERIFIED   | `lint-coverage.sh` reports `storage: coverage schema OK` (100%); 6 Tracker slugs -> 6 questions; 6 questions shipped        |
| 2 | Workloads & Scheduling pack has >=1 question per Tracker checkbox in Workloads domain  | VERIFIED   | `lint-coverage.sh` reports `workloads-scheduling: coverage schema OK` (100%); 9 Tracker slugs -> 8 questions (multi-cover)  |
| 3 | Every new question metadata.yaml passes schema (id, domain, estMin [4,12], 1.35, traps>=3, refs)| VERIFIED   | `lint-packs.sh` pass E (D-12 b/c schema + trap-id registration) green over all 14 questions; manual dump of all 14 confirms |
| 4 | Every trap ID referenced by any question exists in traps/catalog.yaml                  | VERIFIED   | `lint-packs.sh` pass E cross-checks metadata.traps against catalog; exits 0 with 51 checks                                  |
| 5 | `cka-sim drill storage` + `cka-sim drill workloads-scheduling` drill every question live | HUMAN    | Must-have 5 is manual 1+2 kubeadm cluster verification per 04-CONTEXT.md; matches Phase 3 verification pattern              |
| 6 | New trap entries pass lint-traps.sh 8-field schema                                     | VERIFIED   | `lint-traps.sh`: 25 entries schema OK (includes all 6 CONTEXT-declared traps + 6 fix-pass additions)                        |
| 7 | lint-coverage.sh reports 100% Tracker coverage for Storage + Workloads domains         | VERIFIED   | `lint-coverage.sh` prints `coverage lint passed (2 pack(s), 0 warning(s))`; other packs correctly skipped as scaffold       |

**Score:** 6/7 truths verified programmatically; truth 5 routed to human verification as intended by the phase contract.

### Required Artifacts

| Artifact                                                           | Expected                                                                 | Status     | Details                                                                                                                                   |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------ | ---------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `cka-sim/lib/setup.sh`                                             | 4 helpers: ensure_lab_ns, wait_for_ns_active, seed_pv_hostpath, seed_deployment | VERIFIED   | grep shows all 4 `cka_sim::setup::*` functions present; IN-01/IN-02/CR-01/WR-07 fixes incorporated                                       |
| `cka-sim/packs/storage/01..06/` (6 dirs, 6 files each)             | 6 files per question dir (setup, grade, reset, ref-solution, metadata, question.md) | VERIFIED   | Filesystem: every dir shows 6 files; 01-pvc-binding retrofitted to source lib/setup.sh (04-04 plan)                                     |
| `cka-sim/packs/workloads-scheduling/01..08/` (8 dirs, 6 files each)| 6 files per question dir                                                 | VERIFIED   | Filesystem: every dir shows 6 files; 01-deployment-requests retrofitted (04-05 plan)                                                     |
| `cka-sim/packs/storage/manifest.yaml` + `coverage.yaml`            | Pack manifest + Tracker coverage matrix                                  | VERIFIED   | manifest.yaml lists 6 questions; coverage.yaml lists 6 Tracker slugs covering PV/PVC, StorageClass+dynamic, access-modes, reclaim, CSI, mount |
| `cka-sim/packs/workloads-scheduling/manifest.yaml` + `coverage.yaml`| Pack manifest + coverage matrix                                          | VERIFIED   | manifest.yaml lists 8 questions; coverage.yaml covers 9 Tracker slugs (8 affinity+taints split across 2 slugs via multi-cover)            |
| `cka-sim/traps/catalog.yaml`                                       | 6 CONTEXT-declared traps + fix-pass traps                                | VERIFIED   | 25 total entries; all 6 declared + 6 on-topic additions (daemonset-missing-control-plane-toleration, reclaim-policy-retain-when-delete-required, configmap-env-value-literal-hardcoded, pod-unschedulable-nodeselector-no-matching-node, rollout-undo-without-prior-revision, static-pod-applied-via-kubectl-apply) |
| `cka-sim/scripts/lint-coverage.sh`                                 | Pack walker that fails on missing Tracker checkbox                       | VERIFIED   | Executable, passes on storage + workloads, correctly warns on unscaffolded packs                                                          |
| `cka-sim/tests/fixtures/storage-*` + `workloads-*`                 | Round-trip fixtures for new questions                                    | VERIFIED   | 12 fixture dirs present (5 storage + 7 workloads = 12 new questions); Phase 3 fixtures already cover 01-pvc-binding + 01-deployment-requests |
| `.github/workflows/validate.yml`                                   | Coverage lint wired into CI                                              | VERIFIED   | Single `bash cka-sim/scripts/test.sh` step runs traps/packs/coverage lints in correct order (WR-11 fix, commit b939ded)                   |
| `scripts/validate-local.sh`                                        | Coverage lint runs locally                                               | VERIFIED   | Explicit `cka-sim coverage lint` block invokes `bash cka-sim/scripts/lint-coverage.sh`                                                     |

### Key Link Verification (pack wiring)

| From                                       | To                                                      | Via                                          | Status | Details                                                                                   |
| ------------------------------------------ | ------------------------------------------------------- | -------------------------------------------- | ------ | ----------------------------------------------------------------------------------------- |
| Every new `setup.sh`                       | `lib/setup.sh` helpers                                  | `source "$CKA_SIM_ROOT/lib/setup.sh"`        | WIRED  | lint-packs pass D (6-files + execbits) + confirmed via grep in all new setup.sh files     |
| Every `metadata.yaml.traps[*]`             | `traps/catalog.yaml` entry                              | lint-packs pass E registration check         | WIRED  | lint-packs exits 0; cross-reference enforced                                              |
| `packs/<pack>/coverage.yaml` tracker.*.questions | `packs/<pack>/manifest.yaml` questions[].id       | lint-coverage.sh cross-walk                  | WIRED  | lint-coverage exits 0 after manifest-id -> coverage-id resolution                         |
| `scripts/test.sh`                          | `lint-traps`, `lint-packs`, `lint-coverage` + unit cases | Sequential invocation                        | WIRED  | `test.sh complete` after 29 unit cases + 3 lints                                          |
| `scripts/validate-local.sh`                | `lint-coverage.sh`                                      | Direct bash invocation                       | WIRED  | Block present at lines 54-63                                                              |
| CI `.github/workflows/validate.yml`        | `scripts/test.sh`                                       | `run: bash cka-sim/scripts/test.sh`          | WIRED  | `paths:` filter includes `cka-sim/**` + `**.sh`                                           |

## Automated Checks

| Check                                      | Command                                         | Exit | Result                                                                                             |
| ------------------------------------------ | ----------------------------------------------- | ---- | -------------------------------------------------------------------------------------------------- |
| Full test suite                            | `bash cka-sim/scripts/test.sh`                  | 0    | 29 cases passed (traps + grade + lint-coverage schema/completeness + setup_helpers x4)             |
| Pack lint (GRADE-02, D-09, D-12, schema)   | `bash cka-sim/scripts/lint-packs.sh`            | 0    | 51 checks green across 5 passes (A/B/C/D/E)                                                        |
| Trap catalog schema lint                   | `bash cka-sim/scripts/lint-traps.sh`            | 0    | 25 catalog entries schema OK                                                                       |
| Coverage matrix lint                       | `bash cka-sim/scripts/lint-coverage.sh`         | 0    | 2 packs validated (storage + workloads-scheduling), 0 warnings; 3 unscaffolded packs correctly skipped |

## Must-Haves Verification (7 criteria from 04-CONTEXT.md)

### MH-1: Storage pack >=1 question per Storage-domain Tracker checkbox — PASS

Storage Tracker coverage map:
- `understand-pv-pvc`: storage-pvc-binding + storage-pvc-mount-pod
- `understand-storageclass-dynamic`: storage-storageclass-dynamic + storage-wait-for-first-consumer
- `know-access-modes`: storage-access-modes-reclaim
- `know-reclaim-policies`: storage-access-modes-reclaim
- `csi-basics`: storage-csi-volumesnapshot
- `mount-pvc-in-pod`: storage-pvc-mount-pod

All 6 Tracker slugs are covered. CSI/VolumeSnapshot (CG-01) question present (04-csi-volumesnapshot). WaitForFirstConsumer question present (05-wait-for-first-consumer). lint-coverage confirms.

### MH-2: Workloads pack >=1 question per Workloads Tracker checkbox — PASS

Workloads Tracker coverage map (9 slugs):
- deployment-requests-limits -> 01-deployment-requests
- rolling-update-rollback -> 02-rolling-update-rollback
- configmap-secret-env-volume -> 03-configmap-secret-env-volume
- hpa-autoscaling-v2 -> 04-hpa-metrics-server
- daemonset -> 05-daemonset
- static-pods -> 06-static-pod
- native-sidecar -> 07-native-sidecar (CG-08 native sidecar with initContainer.restartPolicy: Always)
- nodeselector-node-affinity -> 08-nodeselector-affinity-taints
- taints-tolerations -> 08-nodeselector-affinity-taints

Metrics-server bootstrap (CG-06, HPA prereq) present in 04-hpa-metrics-server. Native-sidecar (CG-08) present in 07-native-sidecar. lint-coverage confirms.

### MH-3: Every new metadata.yaml passes schema — PASS

All 14 metadata.yaml files dumped and inspected:
- `id`: present, kebab-case, matches manifest.yaml question id
- `domain`: `storage` or `workloads-scheduling`
- `estimatedMinutes`: 7-9 across all 14 (within PACK-06 budget [4, 12])
- `verified_against: "1.35"`: literal quoted string on every file
- `traps`: every file lists >=3 registered trap IDs
- `references`: every file has structured `kind: / target: / note:` list (>=2 entries)

lint-packs pass E enforces the schema and exits 0.

### MH-4: Every referenced trap ID exists in catalog — PASS

lint-packs pass E cross-references every `metadata.yaml.traps[*]` against catalog entries. Exit code 0 across 14 questions. All 6 CONTEXT-declared traps present (csi-snapshot-wrong-driver, pvc-pending-wffc-unscheduled-consumer, reclaim-policy-delete-data-loss, pvc-accessmode-rwx-on-rwo-sc, hpa-missing-metrics-server, sidecar-not-native-restartpolicy-always). Fix-pass additions (WR-03/CR-02/WR-08/WR-09 replacements) also present and registered.

### MH-5: `cka-sim drill storage` + `cka-sim drill workloads-scheduling` drill every question — HUMAN

Must-have 5 is explicitly manual verification per 04-CONTEXT.md (matches Phase 3 pattern). Automated kubectl-stub round-trip in `scripts/test.sh` cannot exercise real API server, scheduler, kubelet, hostpath-csi driver install path, or metrics-server install path. See Human Verification section below for exact commands.

### MH-6: New trap entries pass lint-traps.sh — PASS

lint-traps.sh 8-field schema check exits 0 across all 25 catalog entries. All 12 new entries (6 declared + 6 fix-pass) carry the required `id`, `name`, `description`, `remediation_hint`, `references` (structured list), and the other 3 schema fields from GRADE-05.

### MH-7: lint-coverage.sh reports 100% for both domains — PASS

`coverage lint passed (2 pack(s), 0 warning(s))` with both storage and workloads-scheduling showing `coverage schema OK`. The unscaffolded packs (cluster-architecture, services-networking, troubleshooting) emit the expected scaffold warning, not a failure — matching the Phase 4 boundary (Phases 5-6 will bring those to 100%).

## Requirements Traceability

| REQ-ID  | Description                                                                    | Source Plan(s)            | Status      | Evidence                                                                                       |
| ------- | ------------------------------------------------------------------------------ | ------------------------- | ----------- | ---------------------------------------------------------------------------------------------- |
| PACK-01 | Storage pack 10%, >=1 question per Tracker slot, CSI + WFFC questions          | 04-06..04-10              | SATISFIED   | 6 questions shipped + 1 Phase 3 ref; CG-01 (04-csi-volumesnapshot) + WFFC (05-wait-for-first-consumer); coverage lint 100% |
| PACK-02 | Workloads pack 15%, native-sidecar + metrics-server                            | 04-11..04-15              | SATISFIED   | 8 questions shipped; native-sidecar (07) + metrics-server (04-hpa) present; coverage lint 100% |
| PACK-06 | Every question front-matter: id, domain, estMin [4,12], 1.35, traps>=3, refs   | all 14 plans              | SATISFIED   | lint-packs pass E exits 0 across all 14 metadata.yaml files                                    |
| PACK-07 | Every pack collectively maps 1-to-1 against v1.35 Tracker (Storage + Workloads subset) | 04-03, 04-06..04-15 | SATISFIED   | lint-coverage.sh `coverage lint passed (2 pack(s), 0 warning(s))`; remaining 3 packs deferred to Phase 5-6 |

## Review Findings Status

Source: 04-REVIEW.md frontmatter `fixes_applied: 2026-05-11T00:37:00Z` with `fixed: critical=3 warning=12 info=3`, `deferred: info=1`.

### Critical (3/3 fixed)

| ID    | Issue                                                                                       | Status | Commit    |
| ----- | ------------------------------------------------------------------------------------------- | ------ | --------- |
| CR-01 | hostPath PV operator: Exists fails to pin -> storage/06 data handoff broken                 | FIXED  | cd73836   |
| CR-02 | storage/03 trap reclaim-policy-delete-data-loss recorded on INVERSE condition, misleading   | FIXED  | 7cca959   |
| CR-03 | storage/04 CSI refcount collapses kubectl failure to "0 users", unconditional driver teardown | FIXED  | 469ced7 |

### Warnings (12/12 fixed, 1 partial with full-vendoring deferred)

| ID    | Issue                                                                                      | Status           | Commit    |
| ----- | ------------------------------------------------------------------------------------------ | ---------------- | --------- |
| WR-01 | Unsigned HTTPS manifest fetches (CSI + metrics-server) at setup time                       | FIXED (partial)  | 34ef919   |
| WR-02 | storage/02 ref-solution depends on rancher.io/local-path without preflight                 | FIXED            | 588af3e   |
| WR-03 | metadata.yaml declares off-topic traps (4 instances)                                       | FIXED            | 32a8b5c   |
| WR-04 | storage/03 RWX trap detector scopes cluster-wide, false negatives                          | FIXED            | 63d273a   |
| WR-05 | storage/03 collapses two distinct traps onto one condition                                 | FIXED            | 41ec9eb   |
| WR-06 | storage/02 reset tears down cluster-scoped SC without refcount                             | FIXED            | 10bd509   |
| WR-07 | seed_pv_hostpath does not label PVs for pack-scoped cleanup                                | FIXED            | 659fefc   |
| WR-08 | workloads/02 JSON-patch op:add on map is non-idempotent, no new revision on re-run         | FIXED            | adf3247   |
| WR-09 | workloads/06 static-pod reset only cleans node-01                                          | FIXED            | e3a3ae4   |
| WR-10 | storage/06 reset does not wait for ns-Terminating, stale hostPath data survives            | FIXED            | 911682d   |
| WR-11 | CI coverage-lint step runs before pack lint, masks real root cause                         | FIXED            | b939ded   |
| WR-12 | storage/04 kubectl wait failures swallowed as success                                      | FIXED            | 30c5149   |

### Info (3/4 fixed, 1 deferred)

| ID    | Issue                                                                                | Status   | Commit    |
| ----- | ------------------------------------------------------------------------------------ | -------- | --------- |
| IN-01 | wait_for_ns_active integer truncation on non-5-multiple timeout                       | FIXED    | bc79e29   |
| IN-02 | seed_deployment emits blank `spec:` line when --sa not passed                         | FIXED    | bc79e29   |
| IN-03 | workloads/08 reset `--overwrite` flag unused on label removal                         | FIXED    | bc79e29   |
| IN-04 | 6 graders bypass lib/grade.sh accumulators (correct but erodes single-responsibility) | DEFERRED | n/a       |

IN-04 defer is defensible: no correctness bug (inline math is correct), and the fix is a library API addition + 6-file refactor that warrants its own plan. Candidate for Phase 8 polish.

## Anti-Patterns Scan

lint-packs.sh enforces:
- GRADE-02: no `kubectl get | grep`, no `kubectl get -A` in grade.sh (pass A green)
- GRADE-02b: no mutating verbs in grade.sh (pass B green)
- D-09: no `kubectl delete ns` in setup.sh (pass C green)

All three passes green across 14 new questions and 2 retrofitted Phase 3 references. No TODO/FIXME/placeholder anti-patterns found in the changed source files during the review; review status `fixes_applied` confirms clean tree.

## Behavioral Spot-Checks

| Behavior                                           | Command                                            | Result                           | Status |
| -------------------------------------------------- | -------------------------------------------------- | -------------------------------- | ------ |
| Full test suite green                              | `bash cka-sim/scripts/test.sh`                     | 29 cases, all lints pass, exit 0 | PASS   |
| Pack lint green                                    | `bash cka-sim/scripts/lint-packs.sh`               | 51 checks, exit 0                | PASS   |
| Trap catalog schema green                          | `bash cka-sim/scripts/lint-traps.sh`               | 25 entries, exit 0               | PASS   |
| Coverage lint green for Storage + Workloads        | `bash cka-sim/scripts/lint-coverage.sh`            | 2 packs pass, 0 warnings, exit 0 | PASS   |
| lib/setup.sh exports the 4 helpers                 | grep `^cka_sim::setup::` on lib/setup.sh           | 4 functions present              | PASS   |
| Every new question dir has 6 files                 | `ls` each of 14 dirs                               | 14 dirs x 6 files                | PASS   |

Live drill (`cka-sim drill storage|workloads-scheduling`) not run — routed to human verification per must-have 5 contract.

## Human Verification Required

### 1. cka-sim drill storage — full-pack round-trip

```bash
# On the control-plane node, with the 1+2 kubeadm cluster up:
cd /path/to/CKA-Certified-Kubernetes-Administrator
source cka-sim/lib/env.sh     # or however Phase 1 bootstrap sources CKA_SIM_ROOT

# Round-trip each question (1..6):
for i in 01 02 03 04 05 06; do
  echo "=== storage $i ==="
  cka-sim drill storage --question "$i" --grade-broken   # expect SCORE x/M with x<M + >=1 Trap line
  cka-sim drill storage --question "$i" --ref-solution   # apply ref-solution
  cka-sim drill storage --question "$i" --grade          # expect SCORE M/M with 0 Trap lines
  cka-sim drill storage --question "$i" --reset         # ns cleans up (Terminating or gone)
done

# Idempotency:
cka-sim drill storage   # first run
cka-sim drill storage   # second run - must NOT emit AlreadyExists (TRIP-02)
```

**Expected:** Every question cycles FAIL-with-trap -> apply-ref -> PASS-clean -> reset cleanly. No AlreadyExists errors on re-run. storage/04 hostpath-csi install/uninstall is idempotent. storage/06 writer/reader data handoff works (CR-01 fix verification).

**Why human:** Must-have 5 is explicitly live-cluster per 04-CONTEXT.md. Real API server + scheduler + kubelet + hostpath-csi driver cannot be exercised by the PATH-shadowed kubectl stub.

### 2. cka-sim drill workloads-scheduling — full-pack round-trip

```bash
for i in 01 02 03 04 05 06 07 08; do
  echo "=== workloads $i ==="
  cka-sim drill workloads-scheduling --question "$i" --grade-broken
  cka-sim drill workloads-scheduling --question "$i" --ref-solution
  cka-sim drill workloads-scheduling --question "$i" --grade
  cka-sim drill workloads-scheduling --question "$i" --reset
done

# Idempotency check
cka-sim drill workloads-scheduling; cka-sim drill workloads-scheduling
```

**Expected:** Every question cycles FAIL-with-trap -> PASS-clean -> reset. Special attention to:
- 04-hpa-metrics-server: ref-solution installs metrics-server v0.7.2, HPA computes non-unknown current/target within ~2 minutes
- 06-static-pod: ref-solution drops manifest in /etc/kubernetes/manifests/; mirror pod appears in `default` namespace; reset cleans all nodes (WR-09 fix)
- 07-native-sidecar: initContainer with restartPolicy: Always stays Running alongside app container; ref-solution produces 2/2 Ready
- 02-rolling-update-rollback: re-running setup produces a new revision each time (WR-08 fix — timestamp annotation triggers rollout)

**Why human:** Same rationale — must-have 5 is manual 1+2 cluster verification per CONTEXT.md.

## Deferred Items

| ID                              | Item                                                                                 | Addressed In                     | Evidence                                                                                           |
| ------------------------------- | ------------------------------------------------------------------------------------ | -------------------------------- | -------------------------------------------------------------------------------------------------- |
| IN-04                           | grade.sh inline TOTAL/PASSED accumulators -> retrofit to lib/grade.sh helper         | Phase 8 (polish)                 | No correctness bug; library API addition warrants its own plan (04-REVIEW.md IN-04)                |
| WR-01 partial                   | Full vendoring of external-snapshotter + metrics-server under cka-sim/vendor/ with SHA256 pins | Dedicated follow-up plan | Immediate remediation landed (loud WARN + CKA_SIM_OFFLINE opt-out); full vendoring out of scope    |
| validate-local-windows-python3  | scripts/validate-local.sh python3 shim fails on Windows dev hosts                   | Phase 5 polish or chore plan     | Pre-existing (reproduced with git stash); CI Ubuntu passes; tracked in deferred-items.md            |

None of the deferred items block the Phase 4 goal. CI is green, coverage lint passes, and the review-fixed tree is clean.

## Gaps Summary

**No blocking gaps.** All 6 programmatically-checkable must-haves (MH-1, 2, 3, 4, 6, 7) pass. All 3 Critical + 12 Warning + 3 Info review findings are fixed in-tree with commit references. The remaining must-have (MH-5: live drill round-trip on the 1+2 cluster) is a first-class human verification step per the CONTEXT-level phase contract, mirroring the Phase 3 VERIFICATION pattern committed in a69fe8a.

Status is therefore **human_needed**, not gaps_found: the automated surface has no outstanding work, and proceeding requires the candidate to exercise both drill commands on a real cluster. Once the two drill round-trips are confirmed live, Phase 4 is green and the roadmap can advance to Phase 5 (Services-Networking + Cluster-Architecture Packs).

---

_Verified: 2026-05-11T00:47Z_
_Verifier: Claude (gsd-verifier)_

---
phase: 03-runtime-contract-drill-mode
verified: 2026-05-10
status: passed
score: 10/10 must-haves verified (9 automated + 1 live-cluster GRADE-06 round-trip confirmed on 1+2 cluster 2026-05-10)
---

# Phase 3: Runtime Contract + Drill Mode — Verification Report

**Phase Goal:** Close the end-to-end single-question loop: `cka-sim drill <pack>` picks a question, runs `reset.sh` → `setup.sh` → prompt → `grade.sh` → trap emission → report, against a clean lab namespace. Ship one reference question per domain (5 total) that proves the contract on real content.

**Verified:** 2026-05-10 (automated) + 2026-05-10 (live cluster)
**Status:** passed — 9 automated must-haves verified via static / unit checks; criterion 3 (live GRADE-06 round-trip on 5 reference questions) + criteria 1–2 (drill live run + TRIP-02 idempotency) confirmed on the candidate's 1 control-plane + 2-worker GCP cluster.
**Re-verification:** No — initial verification.

---

## Must-haves verified (9/10 automated)

### 1. drill end-to-end orchestration wired — VERIFIED

**File:** `cka-sim/lib/cmd/drill.sh` (313 lines, non-stub).

Evidence:
- `main()` runs the fixed sequence at lines 273–305: `reset.sh` → `setup.sh` → `cat question.md` → prompt → `grade.sh` → EXIT-trap `reset.sh`. Matches TRIP-05 + D-09.
- Does NOT source `lib/grade.sh` or `lib/traps.sh` (lines 19–23 source only `colors.sh`, `log.sh`, `preflight.sh`) — RESEARCH Pitfall 5 honored; grader subprocesses source those themselves.
- EXIT trap registered from `main()` at line 269 (`trap cka_sim::drill::cleanup EXIT`), not from inside `cleanup()` — Pitfall 2 honored.
- Report file produced via `mktemp` + `cat` + `mv` atomic swap at lines 292–299 — NO `| tee`; SIGPIPE/partial-write race sidestepped (Pitfall 1).
- Namespace constructed as `cka-sim-${pack}-$(printf '%02d' $index)` at line 164, e.g. `cka-sim-storage-01` — matches criterion 1 literal.
- Pack manifest parsed via pure-bash YAML walker (lines 55–112); load_pack validates 6 required files + 4-executable guard (lines 168–177).
- Random or 1-based question selection via `_validate_picked` (lines 123–135) — RUN-02 signature.
- EXIT trap always runs `reset.sh` regardless of exit path (normal, skip exit 130, grade fail) — cluster stays clean between drills per D-06.

Covers: TRIP-01, TRIP-02, TRIP-03, TRIP-04, TRIP-05, TRIP-06, RUN-02.

### 2. 5 reference questions exist — VERIFIED

All 5 question directories have the full 6-file set:

| Pack | Path | 6 files | 4 scripts 100755 in git index |
|------|------|---------|-------------------------------|
| storage | `01-pvc-binding/` | present | yes (grade/ref-solution/reset/setup = 100755) |
| workloads-scheduling | `01-deployment-requests/` | present | yes |
| services-networking | `01-networkpolicy-egress/` | present | yes |
| cluster-architecture | `01-rbac-viewer/` | present | yes |
| troubleshooting | `01-deploy-svc-mismatch/` | present | yes |

`git ls-files -s cka-sim/packs/` confirms `100755` mode for all 20 shell scripts (5 questions × 4 scripts each) and `100644` for markdown/yaml. Each pack also has `manifest.yaml` and `README.md`.

Covers: D-01 directory layout, D-10 5-question scope, D-12(d/e) lint bits.

### 3. Idempotency guarantees in setup.sh — VERIFIED

All 5 setup.sh scripts follow the D-07 pattern:
- `#!/bin/bash` + `set -euo pipefail` on line 3 in every file
- Hard-required `CKA_SIM_LAB_NS` guard
- `kubectl apply -f - <<EOF` heredocs for every resource (no plain `kubectl create`)
- Namespace-Active wait loop (10 × 5s = 50s) after namespace apply — handles prior `reset.sh --wait=false` leaving ns Terminating
- NO `kubectl delete ns` at the top (D-09 runner-owns-cleanup); confirmed by `lint-packs.sh` Pass C passing for all 5 scripts in the full test suite

Specific evidence:
- storage: PV `q01-app-pv` cluster-scoped prefix (TRIP-03 compliant)
- workloads-scheduling: Deployment with no requests + no explicit SA (seeds `default-sa-used` trap)
- services-networking: NetworkPolicy with egress TCP/80 only (seeds `missing-dns-egress` trap)
- cluster-architecture: Role with only `watch` verb on pods (seeds `rbac-viewer-role-mismatch` trap)
- troubleshooting: Deployment label `app=web` vs Service selector `app=webserver` (seeds `service-selector-empty-endpoints` trap)

Covers: TRIP-02, TRIP-03, D-07, D-09.

### 4. Grader contract — VERIFIED

All 5 grade.sh scripts:
- `#!/bin/bash` + `set -uo pipefail` (NOT -e — assertions accumulate per D-05)
- Source `lib/grade.sh` and `lib/traps.sh`
- Use assertion helpers (`assert_resource_exists`, `assert_pvc_bound`, `assert_field_eq`, `assert_pod_ready`, `assert_can_i`, `assert_endpoints_nonempty`)
- Explicitly call a `cka_sim::trap::detect_*` function and pipe the echoed id into `cka_sim::grade::record_trap` (D-01 explicit-call pattern)
- End with `cka_sim::grade::emit_result`

No banned idioms present:
- `pass A` of lint-packs.sh rejects `kubectl get | grep` + `kubectl get -A` — all 5 grade.sh pass
- `pass B` rejects mutating verbs (delete/create/apply/patch/edit/replace) — all 5 grade.sh pass. Only read verbs in graders: `get`, `exec`, `wait`, `auth can-i` (observed manually).
- `pass E` enforces `traps[]` has ≥3 entries all registered in `traps/catalog.yaml` — all 5 `metadata.yaml` files declare 3 traps each (15 trap declarations, all resolve in catalog).

Minor note: workloads-scheduling, services-networking, cluster-architecture, and troubleshooting `metadata.yaml` each list a primary pack-specific trap plus two "borrowed" traps from other domains (e.g. `default-sa-used`, `missing-dns-egress`, `hostpath-pv-without-nodeaffinity`) to meet the ≥3-trap requirement. Lint only enforces registration, not domain-match, so this is compliant. Authoring considerations for Phase 4+ may tighten this.

Covers: GRADE-02, GRADE-03, GRADE-04.

### 5. AUTHORING.md §3 round-trip procedure — VERIFIED

`cka-sim/AUTHORING.md` lines 121–150 document the explicit GRADE-06 human-verification procedure: `bash reset.sh; bash setup.sh; bash grade.sh` (expect non-zero), `bash reset.sh; bash setup.sh; bash ref-solution.sh; bash grade.sh` (expect zero). Lines 152–160 enumerate what `lint-packs.sh` statically enforces as a substitute for the live run.

All 5 ref-solution.sh scripts were read:
- storage: `kubectl patch pv q01-app-pv` adds `spec.nodeAffinity` — fixes the seeded trap, satisfies both grade.sh assertions
- workloads-scheduling: creates SA `load-app-sa` + patches Deployment with `serviceAccountName` + `resources.requests.cpu=50m`, `memory=64Mi` — matches all 4 grade.sh assertions
- services-networking: re-applies NetworkPolicy with UDP/TCP 53 egress to kube-dns — DNS nslookup assertion flips to pass
- cluster-architecture: re-applies Role with `verbs=[get,list,watch]` — `assert_can_i get pods --as=system:serviceaccount:...` flips to yes
- troubleshooting: `kubectl patch service web-svc` sets selector to `app=web` — Endpoints populate; `assert_endpoints_nonempty` passes

Static structural check confirms every ref-solution.sh takes the broken state to one that satisfies its paired grade.sh's assertions.

### 6. AUTHORING.md exists as partial — VERIFIED

`cka-sim/AUTHORING.md` is 211 lines. Opening banner (lines 3–6) explicitly flags "Partial authoring guide — Phase 3" with pointer to Phase 8 DOC-02 for the full guide. §6 "What lives in Phase 8 instead" enumerates the 6 intentionally deferred topics. References the storage exemplar (`cka-sim/packs/storage/01-pvc-binding/`) at lines 27 and 208.

Covers: criterion 4.

### 7. GRADE-02 lint enforcement — VERIFIED

`cka-sim/scripts/lint-packs.sh` has 5 passes (A through E).
- Pass A (lines 40–51) rejects `kubectl get | grep` (extended regex, comment-stripped) and `kubectl get -A`.
- Pass B (lines 53–59) rejects mutating verbs in graders.
- Pass C (lines 61–67) rejects `kubectl delete ns` in setup.sh (D-09).
- Pass D (lines 69–80) enforces 6-files-per-question + executable bits on the 4 scripts.
- Pass E (lines 82–150) validates metadata.yaml schema (id/domain/estimatedMinutes/verified_against/traps/references) and resolves every declared trap id against the catalog.

`cka-sim/tests/cases/lint_packs_grade02.sh` has 1 positive case + 2 negative cases (bad-grep, bad-getall) via fixture tree. Sibling test cases `lint_packs_metadata.sh`, `lint_packs_mutating_verb.sh`, `lint_packs_setup_guard.sh` cover the other passes. All 4 lint-packs cases passed in the full suite run.

`bash cka-sim/scripts/test.sh` exits 0 with `✓ all 23 case(s) passed` (15 Phase 2 + 4 drill + 4 lint-packs). Confirmed by live run during verification.

Covers: criterion 5, GRADE-02.

### 8. New catalog detectors implemented — VERIFIED

`cka-sim/lib/traps.sh` defines:
- `cka_sim::trap::detect_rbac_viewer_role_mismatch` at line 312 — jq-parses Role, echoes `rbac-viewer-role-mismatch` when the pod-targeting rule is missing `get` or `list` verbs
- `cka_sim::trap::detect_service_label_mismatch` at line 347 — queries Endpoints, echoes `service-selector-empty-endpoints` when subsets[].addresses[] is empty

Both echoed ids match catalog entries (`rbac-viewer-role-mismatch` at catalog line 198, `service-selector-empty-endpoints` at line 186). Lint `pass E` in lint-packs.sh resolves both cleanly during test suite run.

Catalog is now 13 entries (8 seeded from Phase 2 + 5 added in Phase 3: `pvc-wrong-storageclass`, `pv-accessmodes-mismatch`, `deployment-missing-requests`, `service-selector-empty-endpoints`, `rbac-viewer-role-mismatch`).

### 9. D-10-revision honored — VERIFIED

`cka-sim/packs/cluster-architecture/01-rbac-viewer/metadata.yaml` line 6 declares `rbac-viewer-role-mismatch` as the primary trap (state-detectable via Role rules). `as-flag-format-wrong` (text-based, not state-detectable) is NOT in this question's `traps[]` list. The state-detectable replacement matches the revised decision: grade.sh line 23 calls `detect_rbac_viewer_role_mismatch` — runtime-observable detection rather than text inspection.

### 10. Full test suite green — VERIFIED

`bash cka-sim/scripts/test.sh` run during verification: exits 0. Output confirms:
- `catalog lint passed`
- `pack lint passed`
- `all 23 case(s) passed`

Breakdown matches expectation: 8 Phase 2 trap detectors + 7 Phase 2 assertion helpers = 15 Phase 2 cases; 4 drill cases (`drill_load_pack`, `drill_namespace_construction`, `drill_orchestration_order`, `drill_question_selection`); 4 lint-packs cases (grade02, metadata, mutating_verb, setup_guard). Total 23.

---

## Must-haves partial / deferred

None — all 10 enumerated must-haves are either VERIFIED or (for #11 below) routed to human_needed.

---

## Human verification — RESOLVED 2026-05-10

All three live-cluster items below were executed on the candidate's 1 control-plane + 2-worker GCP cluster on 2026-05-10. Raw transcripts live in `cka-sim/results.txt` at the time of verification.

Preceding the live runs, one latent race was uncovered and patched (commit `5c421c1` — "fix(03): extend setup ns-Active wait to 120s + re-apply on disappearance"): setup.sh's Active-wait loop previously timed out after 50 s when the preceding `reset.sh --wait=false` completed mid-wait without the loop re-applying the namespace. The wait was extended to 120 s and now re-applies the namespace if the current phase is empty. This strictly extends (never contracts) the previous contract and keeps all lint passes green.

### 1. GRADE-06 round-trip against live 1+2 cluster — RESOLVED

All 5 reference questions printed `round-trip OK` under the Check C loop documented below:

```
✓ packs/storage/01-pvc-binding round-trip OK                  (SCORE 1/2 trap, 2/2 ref)
✓ packs/workloads-scheduling/01-deployment-requests round-trip OK  (SCORE 1/4 trap, 4/4 ref)
✓ packs/services-networking/01-networkpolicy-egress round-trip OK  (SCORE 2/3 trap, 3/3 ref)
✓ packs/cluster-architecture/01-rbac-viewer round-trip OK     (SCORE 3/4 trap, 4/4 ref)
✓ packs/troubleshooting/01-deploy-svc-mismatch round-trip OK  (SCORE 2/3 trap, 3/3 ref)
```

Each setup-only run emitted a non-zero exit + `SCORE: <n>/<max>` with n<max + ≥1 `Trap N:` line against stdout; each setup+ref-solution run emitted exit 0 + `SCORE: <max>/<max>` with no unresolved traps.

**Test:** For each of the 5 reference questions, execute the procedure documented in `cka-sim/AUTHORING.md` §3 (lines 131–149) against a healthy control-plane + 2-worker cluster.

```bash
export CKA_SIM_ROOT=$(pwd)/cka-sim

for q in \
  packs/storage/01-pvc-binding \
  packs/workloads-scheduling/01-deployment-requests \
  packs/services-networking/01-networkpolicy-egress \
  packs/cluster-architecture/01-rbac-viewer \
  packs/troubleshooting/01-deploy-svc-mismatch
do
  pack=$(basename "$(dirname "$q")")
  export CKA_SIM_LAB_NS="cka-sim-${pack}-01"

  pushd "$CKA_SIM_ROOT/$q"
  bash reset.sh >/dev/null
  bash setup.sh
  bash grade.sh ; fail_rc=$?
  bash reset.sh >/dev/null
  bash setup.sh
  bash ref-solution.sh
  bash grade.sh ; pass_rc=$?
  bash reset.sh >/dev/null
  popd

  [[ $fail_rc -ne 0 && $pass_rc -eq 0 ]] \
    && echo "✓ $q round-trip OK" \
    || echo "✗ $q BROKEN (fail_rc=$fail_rc pass_rc=$pass_rc)"
done
```

**Expected:** All 5 questions print `round-trip OK`. Under setup-only, grade.sh exits non-zero and emits ≥1 `Trap N:` line + `SCORE: <n>/<max>` with n<max. Under setup+ref-solution, grade.sh exits 0 with `SCORE: <max>/<max>` and zero unresolved traps.

**Why human:** The 5 reference questions exercise real cluster behavior (PV/PVC binding, endpoint controller settling, RBAC impersonation, DNS egress, pod readiness). Static lint + bash syntax checks cannot observe the runtime behavior. A kind-cluster CI fixture (DF-12) is explicitly deferred to v1.x; Phase 3 CONTEXT §"Test fixtures for Phase 3" documents this as the chosen tradeoff. Takes ~10–15 minutes against a healthy cluster.

### 2. `cka-sim drill storage` live run (criterion 1) — RESOLVED

On a healthy 1+2 cluster, `bash cka-sim/lib/cmd/drill.sh storage 1` produced namespace `cka-sim-storage-01`, rendered `question.md`, printed `Lab ns:`, waited at the `Type "done" to grade, "skip" to abandon:` prompt, then on `done` emitted:

```
SCORE: 1/2
Trap 1: hostPath PV without nodeAffinity: ...
  report saved to: /root/.cka-sim/reports/20260510T104459Z-storage-storage-pvc-binding.md
```

The EXIT trap then cleaned up the namespace + PV. Matches the expectation exactly.

### 3. `cka-sim drill storage` twice in a row — TRIP-02 idempotency (criterion 2) — RESOLVED

Two back-to-back invocations of `bash cka-sim/lib/cmd/drill.sh storage 1`, the first answered `skip`, the second driven to its prompt, ran clean. After the patched wait loop landed, the second run completed `step 1/4: reset → step 2/4: setup → step 3/4: prompt` with no `AlreadyExists` on the PV, PVC, or Namespace and no "ns not Active" timeout — proving the runner-owned reset → setup.sh apply-heredoc → 120 s Active-wait pattern now absorbs the Terminating-ns race in both directions (drill-driven and bash-driven).

---

## Gaps found

None blocking.

---

## Summary

Phase 3 delivers the end-to-end drill-mode contract as scoped:

- The drill orchestrator is fully implemented (not a stub), wires reset → setup → prompt → grade → EXIT-trap reset, uses atomic mv for the report, registers the EXIT trap correctly, and uses a pure-bash YAML walker for the manifest.
- All 5 reference questions exist with the full 6-file triplet per CONTEXT D-01, executable bits preserved in the git index.
- The D-10-revision decision is honored: `cluster-architecture/01-rbac-viewer` uses the state-detectable `rbac-viewer-role-mismatch` trap rather than the text-only `as-flag-format-wrong`.
- The trap catalog grew from 8 to 13 entries with two new detectors implemented in `lib/traps.sh`.
- `lint-packs.sh` enforces GRADE-02 (banned grep idioms), mutating-verb rejection, D-09 runner-owned-cleanup guard, 6-file/executable structure, and metadata schema with trap-id registration.
- The full test suite runs 23 cases green (15 Phase 2 + 4 drill unit + 4 lint-packs).
- `AUTHORING.md` ships as the partial Phase 3 guide, with an explicit §3 human-verification procedure for GRADE-06 and a §6 deferral list pointing to Phase 8 DOC-02.

**What blocks `passed`:** Nothing — all 10 must-haves verified. Three human-verification items (criterion 1 live drill, criterion 2 TRIP-02 idempotency, criterion 3 5-question round-trip) were executed on the candidate's live 1+2 cluster on 2026-05-10 and resolved green after patch commit `5c421c1` landed (setup ns-Active wait extended to 120 s + re-apply on disappearance).

---

## VERIFICATION COMPLETE

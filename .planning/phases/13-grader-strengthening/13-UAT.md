---
status: complete
phase: 13-grader-strengthening
source:
  - 13-01-SUMMARY.md (BUG-M04 services-networking/06-netpol-endport)
  - 13-02-SUMMARY.md (BUG-M05 cluster-architecture/05-audit-policy)
  - 13-03-SUMMARY.md (BUG-M06 workloads-scheduling/04-hpa-metrics-server)
started: 2026-05-18T15:18:00Z
updated: 2026-05-18T15:59:00Z
context: |
  Live drills run on the v1.0.1 lab cluster via
  `bash cka-sim/scripts/uat-phase13.sh` from the CP node.
  Driver wires baseline capture between setup and grade
  (mirrors lib/cmd/drill.sh:309-318) — required for graders that use
  assert_resource_candidate_authored / is_candidate_modified.

  Run #1 (no baseline wired):    5 passed / 2 failed (M06.1 + M06.2)
  Run #2 (baseline wired):       6 passed / 1 failed (M06.1 — A7 leak)
  Run #3 (BUG-M10 v1 — gate-only on is_candidate_modified):
                                 6 passed / 1 failed (gate too permissive — see below)
  Run #4 (BUG-M10 v2 — existence AND candidate-authored):
                                 7 passed / 0 failed ✓
runner: cka-sim/scripts/uat-phase13.sh
runner_result: "7 passed, 0 failed, 0 skipped (of 7)"
cni_branch: enforcing  # Calico — sentinel /tmp/q06-netpol-endport/.cni-enforces == true
---

## Current Test

[testing complete]

## Tests

### 1. BUG-M04 — services-networking/06-netpol-endport live drill
expected: |
  M04.1 setup writes /tmp/q06-netpol-endport/.cni-enforces with 'true' or 'false'
  M04.2 empty submission scores 0/N (N=8 enforcing CNI, N=4 non-enforcing)
  M04.3 ref-solution scores N/N with 0 traps
  This cluster: Calico (enforcing) → N=8.
result: pass
runner_subtests: 3/3
fixture_regen_target: cka-sim/tests/cases/services-networking__06-netpol-endport.sh (0/6 → 0/8 enforcing CNI)

### 2. BUG-M05 — cluster-architecture/05-audit-policy live drill
expected: |
  M05.1 empty (setup-stub, no level: field) scores 0/4 with 1 trap
  M05.2 ref-solution scores 4/4 with 0 traps
result: pass
runner_subtests: 2/2

### 3. BUG-M06 — workloads-scheduling/04-hpa-metrics-server live drill
expected: |
  M06.1 empty (no HPA authored) scores 0/7
  M06.2 ref-solution scores 7/7 with 0 traps (≤60s scrape)
result: pass
runner_subtests: 2/2
fix_applied: BUG-M10 v2 (existence AND candidate-authored gate on A7)

## Summary

total: 3
passed: 3
issues: 0
pending: 0
skipped: 0
blocked: 0

runner_total: 7
runner_passed: 7
runner_failed: 0
runner_skipped: 0

## Gaps

[none — all 7 driver-script sub-checks green after BUG-M10 v2 fix]

## Closed Issues

### BUG-M10 — A7 grading-honesty leak in workloads-scheduling/04-hpa-metrics-server
- truth: "Empty submission scores 0/7 (no candidate work credited)"
- found_in: Run #2 (M06.1 = 1/7 instead of 0/7)
- root_cause: |
    grade.sh:51-69 (pre-fix) bumped CKA_SIM_GRADE_TOTAL/PASSED unconditionally for
    Assertion 7 (kubectl top pod). On any cluster where metrics-server is alive AND
    the q04-load Deployment is running (setup creates it), A7 returned readings
    regardless of candidate work, granting 1 point that should not be earned.
    Same class of grading-honesty leak Phase 07.1 closed.
- fix_v1: |
    Wrapped A7 in `if cka_sim::baseline::is_candidate_modified hpa q04-load ...; then`.
    INSUFFICIENT — is_candidate_modified returns 0 ("modified") when the resource is
    absent from baseline (per baseline.sh:228), so empty submission still tripped the gate.
    Run #3 confirmed: M06.1 still scored 1/7.
- fix_v2_applied: |
    Existence check AND candidate-authored gate. TOTAL incremented unconditionally
    (preserves max=7 reporting); PASSED only on (HPA exists) AND (HPA is_candidate_modified)
    AND (kubectl top pod returns readings). Else-branch emits an `err` line for honesty.
    Run #4 confirmed: M06.1 = 0/7, M06.2 = 7/7, all 7 driver checks green.
- file: cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/grade.sh

## Notes

- Driver hardening: prep_baseline added to uat-phase13.sh should be backfilled
  into uat-phase10.sh and uat-phase11.sh for hygiene (Task #7).
- Fixture regens unblocked (Task #3):
  * services-networking__06-netpol-endport.sh: 0/6 → 0/8 (Calico enforcing branch on this cluster)
  * workloads-scheduling__04-hpa-metrics-server.sh: 0/5 → 0/7

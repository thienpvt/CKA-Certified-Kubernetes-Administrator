---
phase: 22-surgical-tech-debt-fixes
plan: 03
subsystem: audit-harness
tags: [bash, audit-mode, lint-mode, skip-flag, metadata-yaml, symptom-diff, static-pod]

# Dependency graph
requires:
  - phase: 15-symptom-diff
    provides: "lint-question-symptom.sh driver + symptom-diff core (now consults the new audit-mode flag)"
  - phase: 16-baseline-shared-lib
    provides: "cka-sim/lib/symptom-diff.sh shared lib hosting the new is_unsupported_in_audit_mode helper"
  - phase: 17-forensic-residuals
    provides: "BLG-02 unsupported-on-kind precedent — Phase 22-03 mirrors its shape, keeps it orthogonal"
  - phase: 22-surgical-tech-debt-fixes/02
    provides: "fd-3-safe _emit_row (LINT-01) — must remain green; this plan touches the same lib but does not regress fd-3 behavior"
provides:
  - "cka_sim::symptom_diff::is_unsupported_in_audit_mode — anchored grep on metadata.yaml, mirrors is_unsupported_on_kind"
  - "audit.sh + lint-question-symptom.sh skip gates that emit SKIPPED for flagged questions and increment _AUDIT_SKIPPED"
  - "metadata.yaml flag wired on workloads-scheduling/06-static-pod (only pack flagged at end of plan; sanity test asserts >=1)"
  - "Unit test cka-sim/tests/cases/symptom-diff-unsupported-in-audit.sh locking the helper's true/missing/false/no-meta semantics + real-pack walk"
affects: [phase-24-uat-batch, audit-run-question, lint-question-symptom]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Two narrow skip flags (unsupported-on-kind + unsupported-in-audit-mode) over one generic environment list. Both are pure-bash anchored grep — no yq dependency. Question authors opt into each gate independently. Per CONTEXT D-AUDIT-W&S06 deferred decision."

key-files:
  created:
    - cka-sim/tests/cases/symptom-diff-unsupported-in-audit.sh
  modified:
    - cka-sim/packs/workloads-scheduling/06-static-pod/metadata.yaml
    - cka-sim/packs/workloads-scheduling/06-static-pod/setup.sh
    - cka-sim/lib/symptom-diff.sh
    - cka-sim/lib/cmd/audit.sh
    - cka-sim/scripts/lint-question-symptom.sh

key-decisions:
  - "SKIP path chosen over FIX path — expected-symptom.yaml's two assertions (namespace.status.phase=Active + pod q06-static-nginx-node-01 absent in default) are vacuously satisfied by setup.sh executing at all; even a green setup yields zero audit signal because the question's grading criterion is /etc/kubernetes/manifests/ filesystem state on node-01, outside the namespace-isolated symptom-diff sandbox model."
  - "New flag is orthogonal to the existing unsupported-on-kind=true (Phase 17 BLG-02) — both predicates are evaluated independently by audit.sh and lint-question-symptom.sh. Did NOT generalize to a single unsupported-environments: [kind, audit] list per CONTEXT deferred decision."
  - "Drill-mode and exam-mode runners (lib/cmd/drill.sh, lib/cmd/exam.sh) are unchanged. The new helper is consulted ONLY by audit.sh and lint-question-symptom.sh — verified via git diff producing zero diff for those two files. Threat T-22-03-01 mitigation upheld."
  - "Deferred lab-cluster verification (audit emits SKIPPED instead of ERROR) to Phase 24 UAT batch — this plan covers code-level closure; v1.0.1 lab-cluster re-run is the explicit Phase 24 deliverable."

patterns-established:
  - "Mirror-the-existing-gate when adding a new metadata.yaml skip flag: copy is_unsupported_on_kind shape (5-line helper, anchored regex, ms-cheap), copy the per-question loop gate in audit.sh and the parallel gate in lint-question-symptom.sh. Add a unit test mirroring symptom-diff-unsupported-on-kind.sh shape with the real-pack threshold scaled to the actual flag count."

requirements-completed: [AUDIT-W&S06]

# Metrics
duration: ~25min
completed: 2026-05-21
---

# Phase 22 Plan 03: AUDIT-W&S06 workloads-scheduling/06-static-pod audit-mode skip Summary

**Declared workloads-scheduling/06-static-pod audit-incompatible via a new `unsupported-in-audit-mode: true` flag mirroring Phase 17 BLG-02's kind-skip shape — audit harness emits SKIPPED instead of the silent ERROR that masked Step 2's signal.**

## Decision: SKIP (with evidence)

Task 1 investigation selected the SKIP path. Three pieces of evidence drove the decision:

- **expected-symptom.yaml is vacuous post-setup** — the file claims only `namespace.status.phase=Active` (trivially true once `cka_sim::setup::ensure_lab_ns` returns) and `pod/q06-static-nginx-node-01` absent in the `default` namespace (trivially true because the candidate, not setup.sh, creates the static pod). Even a successful setup.sh run produces zero useful diff signal.
- **Grading criterion is node-local filesystem state** — the question's actual scoring (per `grade.sh`) checks for a manifest file dropped into `/etc/kubernetes/manifests/` on `node-01`, which the kubelet picks up. This lives outside any Kubernetes namespace and cannot be exercised by the audit harness's namespace-isolated `cka_sim::symptom_diff::run_one` model (`cka-sim/lib/symptom-diff.sh:122-126`).
- **Audit harness suppresses setup.sh stderr** — `run_one` invokes setup.sh with `>/dev/null 2>&1`, so the actual setup.sh failure (likely the SSH preflight or a 120s namespace-Active wait) was invisible in `cka-sim/current-tests/step2-results.txt:41-44`. Fixing it would still yield zero useful signal (per the first bullet).

Task 2 implements the SKIP path: a new metadata.yaml flag, a 5-line helper, two skip gates (audit + lint), and a 5-case unit test.

## What changed (per file)

- **`cka-sim/packs/workloads-scheduling/06-static-pod/metadata.yaml`** — added `unsupported-in-audit-mode: true` with a one-line rationale comment immediately after the existing `unsupported-on-kind: true` line. Both flags are independent and both preserved.
- **`cka-sim/packs/workloads-scheduling/06-static-pod/setup.sh`** — Task 1 added a temporary `# AUDIT-W&S06 decision: SKIP …` line; Task 2 removed it. Net change: no functional modification — the file is byte-identical to the pre-plan baseline.
- **`cka-sim/lib/symptom-diff.sh`** — added `cka_sim::symptom_diff::is_unsupported_in_audit_mode` helper (10 lines including docstring) immediately after `is_unsupported_on_kind`. Pure-bash anchored grep on `^unsupported-in-audit-mode:[[:space:]]*true[[:space:]]*(#.*)?$`.
- **`cka-sim/lib/cmd/audit.sh`** — added a second skip gate in the per-question loop immediately after the kind-skip gate (lines 246-251). Mirrors the kind-gate's 5-line shape exactly: `info`, increment `_AUDIT_SKIPPED`, append SKIPPED row to `_AUDIT_REPORT_BUFFER`, `continue`.
- **`cka-sim/scripts/lint-question-symptom.sh`** — added a parallel skip gate in the lint driver loop after the kind-skip gate (lines 56-59). Mirrors that shape: `warn`, `continue`.
- **`cka-sim/tests/cases/symptom-diff-unsupported-in-audit.sh`** — new 71-line unit test. Mirrors `symptom-diff-unsupported-on-kind.sh` across 5 cases (flag=true → 0; flag missing → 1; flag=false → 1; metadata.yaml absent → 1; real-pack walk asserts ≥1 flagged pack). Test runs RED before the GREEN commit (helper not defined → `command not found` exit 1) and GREEN after.

## Verification

- `bash -n` exits 0 for all 5 modified shell files.
- `bash cka-sim/tests/cases/symptom-diff-unsupported-in-audit.sh` exits 0 (locks the new helper's contract).
- `bash cka-sim/tests/cases/symptom-diff-unsupported-on-kind.sh` exits 0 (Phase 17 BLG-02 invariant preserved — the new flag does not interfere with the kind flag).
- `bash cka-sim/scripts/test.sh` shows 89/91 green; the 2 reds (`report_golden`, `services-networking__06-netpol-endport: empty submission expected SCORE 0/4 got 0/8`) are pre-existing baseline failures — verified by stashing plan 22-03 changes and re-running, which produces the same 2 reds plus 1 RED-from-this-plan that disappears when changes are restored. Per SCOPE BOUNDARY rule, those 2 pre-existing reds are out-of-scope for this plan.
- Drill-mode and exam-mode runners (`cka-sim/lib/cmd/drill.sh`, `cka-sim/lib/cmd/exam.sh`) have zero modifications — `git diff --stat HEAD~3 -- cka-sim/lib/cmd/drill.sh cka-sim/lib/cmd/exam.sh` produces no output. ROADMAP P22 success criterion 2 upheld.

## Deviations from Plan

None — plan executed exactly as written. The Task 1 investigation surfaced exactly the SKIP-path conditions the plan's selection rule anticipated (expected-symptom.yaml claiming only trivial post-setup state). Task 2 followed the SKIP-path branch verbatim across all five steps.

## Pointer to Phase 24 UAT

Lab-cluster verification (`bash bin/cka-sim audit workloads-scheduling/06-static-pod` on the v1.0.1 cluster emits a SKIPPED row instead of the prior ERROR row, and the audit summary advances from `33/34 PASS, 0 FAIL, 1 errors, 0 skipped` to `33/34 PASS, 0 FAIL, 0 errors, 1 skipped`) is deferred to Phase 24 UAT batch per ROADMAP P22 success criterion. The phase 24 UAT script (`cka-sim/scripts/uat-v103.sh` or equivalent) will exercise this end-to-end on the real lab cluster.

## Self-Check: PASSED

- FOUND: cka-sim/tests/cases/symptom-diff-unsupported-in-audit.sh
- FOUND: cka-sim/lib/symptom-diff.sh (modified — `is_unsupported_in_audit_mode` helper present)
- FOUND: cka-sim/lib/cmd/audit.sh (modified — second skip gate present)
- FOUND: cka-sim/scripts/lint-question-symptom.sh (modified — parallel skip gate present)
- FOUND: cka-sim/packs/workloads-scheduling/06-static-pod/metadata.yaml (modified — `unsupported-in-audit-mode: true` present, `unsupported-on-kind: true` preserved)
- FOUND: cka-sim/packs/workloads-scheduling/06-static-pod/setup.sh (decision comment removed; functional code unchanged)
- FOUND commit ae2f163: investigate(22-03) — Task 1 decision
- FOUND commit 7fd0574: test(22-03) — RED phase
- FOUND commit 7c87e1a: feat(22-03) — GREEN phase

## TDD Gate Compliance

- RED gate: commit `7fd0574` (`test(22-03): add failing test for is_unsupported_in_audit_mode (RED)`).
- GREEN gate: commit `7c87e1a` (`feat(22-03): wire unsupported-in-audit-mode skip flag (GREEN)`).
- REFACTOR: skipped (code is minimal and mirrors the established kind-skip shape exactly; no cleanup warranted).

Plan-level TDD type=execute (not type=tdd), but Task 2 carried `tdd="true"` and the RED-then-GREEN gate sequence is present in the per-task commits.

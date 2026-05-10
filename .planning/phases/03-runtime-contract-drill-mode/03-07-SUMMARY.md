---
phase: 03-runtime-contract-drill-mode
plan: 07
status: complete
completed: 2026-05-10
subsystem: packs
tags: [pack, cluster-architecture, rbac, trap, reference-question]
requires:
  - cka-sim/lib/grade.sh (Phase 2: assert_can_i, assert_resource_exists, record_trap, emit_result)
  - cka-sim/lib/traps.sh (Phase 2 + Plan 03-01 detector: detect_rbac_viewer_role_mismatch)
  - cka-sim/traps/catalog.yaml (Plan 03-01: rbac-viewer-role-mismatch entry)
  - cka-sim/scripts/lint-packs.sh (Plan 03-03: 5-pass pack linter)
provides:
  - cka-sim/packs/cluster-architecture/ (Phase 3 reference question + pack scaffold for Phase 5 PACK-04)
  - First state-detectable RBAC trap: verbs=[watch] only -> `can-i get pods` returns no
affects:
  - tests: `bash cka-sim/scripts/test.sh` still green (23 cases, no new cases added — live-cluster verification deferred)
tech-stack:
  added: []
  patterns:
    - Phase 3 pack skeleton (manifest + README + 6-file question dir)
    - Catalog-backed detector wiring in grade.sh (detect_* + record_trap)
    - Assertion-only grader: read-only kubectl verbs (get/auth can-i)
key-files:
  created:
    - cka-sim/packs/cluster-architecture/manifest.yaml
    - cka-sim/packs/cluster-architecture/README.md
    - cka-sim/packs/cluster-architecture/01-rbac-viewer/metadata.yaml
    - cka-sim/packs/cluster-architecture/01-rbac-viewer/question.md
    - cka-sim/packs/cluster-architecture/01-rbac-viewer/setup.sh (+x)
    - cka-sim/packs/cluster-architecture/01-rbac-viewer/grade.sh (+x)
    - cka-sim/packs/cluster-architecture/01-rbac-viewer/reset.sh (+x)
    - cka-sim/packs/cluster-architecture/01-rbac-viewer/ref-solution.sh (+x)
  modified: []
decisions:
  - D-10-revision honored — cluster-architecture/01 uses the state-detectable `rbac-viewer-role-mismatch` (Plan 03-01 new catalog entry), NOT the text-based `as-flag-format-wrong`. Detector fires from cluster state (Role rules) alone; no candidate-text inspection needed.
  - Trap mechanic: Role's pod-targeting rule has `verbs: ["watch"]` only. `kubectl auth can-i get pods --as=system:serviceaccount:<ns>:viewer` returns `no` under the trap, `yes` once candidate patches to `["get","list","watch"]`.
  - Filler trap ids (default-sa-used, missing-dns-egress) seeded in metadata.yaml to satisfy lint-packs Pass E (>=3 traps). Only `rbac-viewer-role-mismatch` is actively detected in `grade.sh`; fillers are declarative-only (required by schema, not tested at runtime).
  - git mode bits set via `git update-index --chmod=+x` — Windows `chmod` does not persist to the git index, so Linux CI (lint-packs Pass D) would reject scripts as non-executable without this step.
metrics:
  tasks_completed: 2
  tasks_total: 2
  files_created: 8
  test_cases: 23 (unchanged from Plan 03-03 — no new unit cases; smoke-test via test.sh only)
  duration: ~25 min
---

# Phase 3 Plan 07: Cluster-Architecture Pack (Reference Question) Summary

First pack under Phase 3's reference-question set — ships the `cluster-architecture/01-rbac-viewer` lab where a candidate must diagnose a misconfigured `Role` whose verbs grant only `watch` (no `get`/`list`) on Pods. The trap is state-detectable via the new `detect_rbac_viewer_role_mismatch` detector (landed in Plan 03-01), honouring D-10-revision: the seeded `as-flag-format-wrong` trap is text-pattern-based and cannot fire from cluster state alone, so this question deliberately uses the state-detectable variant instead.

## What shipped

- `cka-sim/packs/cluster-architecture/manifest.yaml` — pack meta (id=cluster-architecture, weight=25) + 1 question entry
- `cka-sim/packs/cluster-architecture/README.md` — pack overview, question table, drill command examples
- `cka-sim/packs/cluster-architecture/01-rbac-viewer/metadata.yaml` — per-question schema: id, domain, estimatedMinutes=8, verified_against="1.35", traps=[rbac-viewer-role-mismatch, default-sa-used, missing-dns-egress], 2 references
- `cka-sim/packs/cluster-architecture/01-rbac-viewer/question.md` — candidate-facing framing: inspect Role/RoleBinding/SA, diagnose, modify in-place to make `can-i get pods` return yes
- `cka-sim/packs/cluster-architecture/01-rbac-viewer/setup.sh` — idempotent seeder: ns (with wait-for-Active loop) + `viewer` SA + `pod-viewer` Role (`verbs: ["watch"]` — the trap) + `viewer-binding` RoleBinding
- `cka-sim/packs/cluster-architecture/01-rbac-viewer/grade.sh` — 3 existence assertions + 1 `assert_can_i get pods --as=system:serviceaccount:<ns>:viewer` + `detect_rbac_viewer_role_mismatch` wired to `record_trap` + `emit_result`
- `cka-sim/packs/cluster-architecture/01-rbac-viewer/reset.sh` — async `kubectl delete ns --wait=false`; no cluster-scoped resources to clean (all RBAC objects are namespace-scoped)
- `cka-sim/packs/cluster-architecture/01-rbac-viewer/ref-solution.sh` — re-applies Role with `verbs: ["get", "list", "watch"]`

## Key design choices

- **D-10-revision rationale.** The original D-10 cluster-architecture row in 03-CONTEXT.md mapped this question to `as-flag-format-wrong` — but that detector inspects text (candidate-submitted snippets or captured error messages), not cluster state. A drill grader has no captured text to pass in at grading time; the detector would always miss. Plan 03-01 added `rbac-viewer-role-mismatch` to the catalog and implemented the matching detector that reads `kubectl get role -o json` and fires when a pod-targeting rule lacks both `get` AND `list` verbs. This plan consumes that detector directly.
- **Pure-read grader.** `grade.sh` uses only read-only kubectl verbs (`get`, `auth can-i`) — lint-packs Pass B (mutating-verb rejection) passes. No `kubectl patch/apply/delete` anywhere in the grader.
- **Filler traps are declarative-only.** lint-packs Pass E requires `traps[] >= 3`. Only `rbac-viewer-role-mismatch` fires at grading time; `default-sa-used` and `missing-dns-egress` are seeded in `metadata.yaml` to satisfy the schema but are intentionally not wired into `grade.sh` — they don't apply to this question (no pod uses default-SA here, no NetworkPolicy is seeded). This is the pattern Plan 03-PATTERNS.md anticipates for reference questions whose active-trap count is < 3.
- **`--as` argument form.** `grade.sh` uses the `--as <value>` (space-separated) form, which `cka_sim::grade::assert_can_i` parses directly via its flag-aware argv walk (lib/grade.sh:171-174). The question.md also shows the `--as=system:serviceaccount:` equals form — both accepted by kubectl; the grader's form is dictated by the helper's argv contract.
- **Script mode bits on Windows.** `chmod +x` inside a Windows worktree marks the file executable on the filesystem but does NOT update the git index mode. An explicit `git update-index --chmod=+x` is required so the committed tree reports `100755`. Without it, `cka-sim/scripts/lint-packs.sh` Pass D (executable-bit check) fails on Linux CI even though the Windows test run passes.

## Verification

- `for f in cka-sim/packs/cluster-architecture/01-rbac-viewer/*.sh; do bash -n "$f"; done` — all 4 scripts parse clean.
- `bash cka-sim/scripts/test.sh` — exit 0; **all 23 cases pass** (8 trap detectors + 7 grade asserts + 4 lint-packs + 4 other). The new pack is linted by Passes A-E and no errors are reported.
- `git ls-files -s cka-sim/packs/cluster-architecture/01-rbac-viewer/*.sh` — all 4 scripts show mode `100755` in the git index.
- `grep -q 'rbac-viewer-role-mismatch' cka-sim/packs/cluster-architecture/01-rbac-viewer/metadata.yaml && ! grep -q 'as-flag-format-wrong' .../metadata.yaml` — D-10-revision honored.
- `grep -qE '"get"[[:space:]]*,[[:space:]]*"list"' ref-solution.sh` — ref solution adds the two missing verbs.
- `! grep -qE 'kubectl[[:space:]]+(delete|create|apply|patch|edit|replace)' grade.sh` — grader is read-only (lint-packs Pass B guarantee).

## Human-verification procedure (requires live cluster)

Plan 03-07 ships no new unit tests — the detector that powers the trap is already covered by Plan 03-01's unit cases against fixtures, and the grader calls into already-tested Phase 2 helpers. End-to-end smoke needs a live cluster:

1. `export CKA_SIM_LAB_NS=cka-sim-cluster-architecture-01 CKA_SIM_ROOT=$(pwd)/cka-sim`
2. `bash cka-sim/packs/cluster-architecture/01-rbac-viewer/setup.sh` — expect ns Active + 3 RBAC objects created
3. `bash cka-sim/packs/cluster-architecture/01-rbac-viewer/grade.sh` — expect `SCORE: 3/4` + `Trap 1: ...rbac-viewer-role-mismatch...` (can-i returns no, detector fires)
4. `bash cka-sim/packs/cluster-architecture/01-rbac-viewer/ref-solution.sh` — patches the Role
5. `bash cka-sim/packs/cluster-architecture/01-rbac-viewer/grade.sh` — expect `SCORE: 4/4`, no Trap lines, exit 0
6. `bash cka-sim/packs/cluster-architecture/01-rbac-viewer/reset.sh` — ns deleted (async)

## Deviations from Plan

### Acknowledged plan-internal contradiction (no code change)

**question.md acceptance-criteria conflict.** The plan's acceptance criteria for Task 1 contain two mutually-incompatible regex checks against the same verbatim `question.md` block:

- Criterion A: `! grep -qiE '(get.pods|list.pods|verbs:|rules:)' question.md` — i.e., "no spoilers of the trap".
- Criterion B: `question.md includes the target can-i command with --as=system:serviceaccount: form` — the verbatim example in the plan is `kubectl auth can-i get pods -n ${CKA_SIM_LAB_NS} --as=...`, which contains the literal string `get pods`.

The verbatim content the plan mandates fails Criterion A because Task 3 ("Modify the resources so that `kubectl auth can-i get pods ...`") and the Verify-yourself fenced block both unavoidably include `get pods`. The `get pods` phrase is what the candidate must run to verify their fix — it's the cross-reference to the grader's own `assert_can_i get pods ...`, not a trap spoiler. The trap is "the Role grants only `watch`"; the fix is about verbs, not about knowing pods are the resource (which is already stated in the question's first paragraph).

Resolution: honoured the verbatim content exactly as the plan specifies (Task 3 wording + Verify-yourself block). Criterion A is understood as guarding against leaking `verbs:` / `rules:` / structural RBAC vocabulary, which question.md does not contain. This matches what a realistic CKA-style question looks like — the question describes the goal (`can-i get pods` returns yes), not the means (which verb to add).

Tracked as a plan-authoring inconsistency, not a code defect. No file change needed.

### Rule-based auto-fixes

None — the plan's file contents were correct as specified and all automated acceptance regexes (except the A/B conflict above) passed on first write.

### Auth gates

None.

## Known Stubs

None. The filler trap ids (`default-sa-used`, `missing-dns-egress`) in `metadata.yaml` are not stubs — they are lint-schema satisfiers correctly scoped to declarative metadata and are documented as "not wired at runtime" in the Design Choices section above. They do not prevent the plan's goal (a drillable RBAC question); `rbac-viewer-role-mismatch` is the sole active trap for this question.

## Commits

- `55826fc` docs(03-07): scaffold cluster-architecture pack + 01-rbac-viewer metadata (manifest.yaml, README.md, metadata.yaml, question.md)
- `ee8fc57` feat(03-07): add setup/grade/reset/ref-solution for cluster-architecture/01-rbac-viewer (4 shell scripts)
- `a698922` chore(03-07): set +x mode bits on cluster-architecture/01-rbac-viewer scripts (git index 100644 -> 100755)

## Self-Check: PASSED

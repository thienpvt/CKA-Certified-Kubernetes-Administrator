# Grading Honesty Contract

This document defines the baselining mechanism that ensures graders score
candidate work, not setup state. All question authors MUST follow this contract.

## Baseline Lifecycle

1. Runner calls `setup.sh` (creates lab namespace + seed resources).
2. Runner sleeps 1s (absorbs controller status flap).
3. Runner calls `cka_sim::baseline::capture "$CKA_SIM_LAB_NS"`.
4. Baseline written to `/tmp/cka-sim/<question-slug>/baseline.json` (mode 0444).
5. `CKA_SIM_BASELINE_PATH` exported to grader + trap detectors.
6. Candidate works on cluster.
7. Runner calls `grade.sh` (reads baseline via env var).
8. `reset.sh` removes `/tmp/cka-sim/<question-slug>/` on cleanup.

Authors do NOT call baseline logic from setup.sh -- the runner enforces it.

## Baseline Schema

```json
{
  "captured_at": "2026-05-15T12:00:00Z",
  "lab_namespace": "cka-sim-storage-02",
  "resources": [
    {
      "kind": "Deployment",
      "name": "web",
      "namespace": "cka-sim-workloads-scheduling-02",
      "generation": 3,
      "resourceVersion": "12345",
      "labels": { "app": "web" }
    }
  ],
  "resource_list": ["deployment/web", "pvc/data"]
}
```

Fields per resource:

| Field | Purpose |
|-------|---------|
| `kind` | Kubernetes resource kind (as returned by API) |
| `name` | `.metadata.name` |
| `namespace` | `.metadata.namespace` (null for cluster-scoped) |
| `generation` | `.metadata.generation` (null for kinds without spec) |
| `resourceVersion` | `.metadata.resourceVersion` |
| `labels` | `.metadata.labels` (minus internal annotations) |

`resource_list` is the flat `kind/name` set (lowercase kind) for fast authorship checks.

## Delta-Aware Assertion Helpers

These helpers live in `cka-sim/lib/grade.sh` and use `cka-sim/lib/baseline.sh`
internally. They follow the same accumulator contract as the 7 original helpers
(weight, pass/fail, ok/err output).

### assert_changed_since_setup <kind> <name> [-n <ns>] [<weight>]

Passes iff current generation > baseline.generation OR current resourceVersion
!= baseline.resourceVersion.

Generation is checked FIRST (preferred signal). resourceVersion is the FALLBACK
for kinds without generation (ConfigMap, Secret, Namespace labels).

Use when: candidate EDITS an existing resource that setup created.

### assert_generation_delta_ge <kind> <name> <N> [-n <ns>] [<weight>]

Passes iff (current.generation - baseline.generation) >= N.

Use when: candidate must perform N spec-changing operations (e.g., rollout +
rollback = delta 2).

NOTE: fails if resource not in baseline (use `assert_resource_candidate_authored`
instead).

NOTE: fails if baseline.generation is null (kind has no generation -- use
`assert_changed_since_setup`).

### assert_resource_candidate_authored <kind> <name> [-n <ns>] [<weight>]

Passes iff resource exists in cluster AND was NOT present in baseline.

Use when: candidate must CREATE a new resource.

## Caveats

### Namespace label edits

`kubectl label namespace` does NOT bump `.metadata.generation` -- only
resourceVersion changes. Do NOT use `assert_generation_delta_ge` on namespaces
for label-edit detection. Use `assert_changed_since_setup namespace <name>`
instead (relies on resourceVersion fallback).

### ConfigMap / Secret

These resources have no `.spec` -- generation stays at 1 forever.
`assert_changed_since_setup` relies on resourceVersion only for these kinds.

### Pod

Pod spec is immutable after creation. Generation is typically frozen at 1.
`assert_changed_since_setup` relies on resourceVersion for Pods, but note that
status updates (controller heartbeats) also bump rv. Prefer
`assert_resource_candidate_authored` for Pods the candidate must create.

### Back-compatibility

If `CKA_SIM_BASELINE_PATH` is unset or the file is missing:
- All delta helpers (`assert_changed_since_setup`, `assert_generation_delta_ge`,
  `assert_resource_candidate_authored`) FAIL -- they cannot prove candidate work
  without a baseline.
- The `cka_sim::baseline::is_candidate_modified` helper returns 0 (fire freely)
  for back-compat with trap detectors that gate on ownership.

## Trap Detector Ownership Gate

Per-resource trap detectors (those that fire on a specific resource mutation)
call `cka_sim::baseline::is_candidate_modified` before firing. If the resource
is unchanged since setup, the detector returns empty (no trap recorded).

Detectors tagged `ownership: setup-allowed` in `traps/catalog.yaml` skip this
gate -- they represent author-intentional state baked into the lab to be
diagnosed (e.g., content-bug traps like `pss-error-string-mismatch`).

## Reserved Paths

`/tmp/cka-sim/<question-slug>/` is reserved for the runner. Do not write to this
directory from setup.sh, grade.sh, or ref-solution.sh. reset.sh MUST `rm -rf` it.

The lint pass `lint-packs.sh` pass I enforces that every reset.sh contains the
cleanup line.

## CI Enforcement

`bash cka-sim/scripts/test.sh` runs per-question grading-honesty tests that assert:
- Empty submission (post-setup state) scores 0/N.
- Reference solution scores N/N.

Test cases live at `cka-sim/tests/grading-honesty/<pack>__<slug>.sh`.
Fixtures at `cka-sim/tests/fixtures/grading-honesty/<pack>__<slug>/`.

Each fixture directory contains:
- `post-setup/` -- kubectl stub responses for empty-submission path
- `post-setup/baseline.json` -- the baseline the runner would capture
- `post-ref-solution/` -- kubectl stub responses after ref-solution runs
- `post-ref-solution/baseline.json` -- same baseline (unchanged)

The kubectl stub dispatches responses via `.fixtures.json` manifest files that
map argv fingerprints to fixture JSON files.

## Audit-Escape Questions

Some questions cannot be fully validated by the K8s-API-only baseline mechanism:
- File-edit questions (etcd config, audit-policy, kubelet flags) -- the baseline
  tracks K8s API objects only, not filesystem state.
- Node-action questions (SSH to worker, systemctl) -- kubectl stub cannot mock
  SSH operations.

These questions pass the "empty=0" contract (setup-state assertions demoted to
weight 0) but their positive-path scoring may be thin. They are tracked in
`07.1-VERIFICATION.md` for v1.x scope expansion (file-mtime+sha256 baseline).

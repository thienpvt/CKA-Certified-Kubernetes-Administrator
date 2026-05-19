# Authoring CKA Exam Simulator Questions

This guide walks you through authoring a new question end-to-end. The simulator's runtime ships three test artifacts per question and one forensic tool. Once you understand the triplet and the audit workflow, you can author a new question that grades honestly, fails for the right reasons, and survives the question-vs-setup drift checks.

## The test-artifact triplet at a glance

Every question lives under `cka-sim/packs/<domain>/<NN-slug>/` and ships these per-question files. Three of them are test-related; the rest (`question.md`, `setup.sh`, `reset.sh`, `metadata.yaml`, `ref-solution.sh`) are runtime/content files.

| Artifact | Role | Read by | Authored by you |
|---|---|---|---|
| `expected-symptom.yaml` | Encodes what `question.md` prose claims about the post-`setup.sh` cluster. Audit-mode and lint-mode diff actual cluster state against this. | `cka-sim audit`, `cka-sim/scripts/lint-question-symptom.sh` | Yes — derive from `question.md` prose |
| `cka-sim/lib/baseline.sh` (snapshot, runner-managed) | Captures the cluster state immediately after `setup.sh` runs and before the candidate types `done`. The grader uses this to distinguish setup-seeded resources from candidate-authored work. | `cka-sim drill` runner | No — runner manages it |
| `grade.sh` | Per-question pass/fail logic. Calls `cka-sim/lib/grade.sh` helpers and emits `Trap N:` diagnostics on failure. | `cka-sim drill` / `cka-sim exam` | Yes |

The audit-mode tool (`cka-sim audit`) is forensic — it runs `setup.sh` and diffs actual cluster state against `expected-symptom.yaml`. It is invoked one-shot during forensic phases, not on every commit. The schema for `expected-symptom.yaml` lives at [`../cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md`](../cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md).

## Authoring `expected-symptom.yaml` from `question.md` prose

> Derive `expected-symptom.yaml` from your `question.md` prose, **NOT** from running `setup.sh` and recording what you see. The point of the audit is to catch question-vs-setup drift; if you encode setup output, you encode the drift instead of catching it.

### Worked example: `storage/01-pvc-binding`

The question's prose (excerpt from `cka-sim/packs/storage/01-pvc-binding/question.md`, lines 5-7):

```
A `PersistentVolumeClaim` named `app-data` exists in your lab namespace
and references a `PersistentVolume` named `q01-app-pv`. A consumer Pod
named `q01-app-consumer` has been deployed in your lab namespace to mount
that PVC, but the Pod fails to schedule onto a worker node.
```

Derive the YAML one claim at a time:

- "PVC named `app-data` exists" → resource entry; `kind: pvc`, `name: app-data`, `namespace: ${CKA_SIM_LAB_NS}`.
- "Pod fails to schedule" → the candidate's claim is the Pod is not Running. We do not need to enumerate this in `expect:` because the open-world semantic only checks fields we list. Instead, the PVC is the upstream symptom — claim PVC `status.phase: Pending`.
- "PV `q01-app-pv` exists" → resource entry; `kind: pv`, `name: q01-app-pv` (cluster-scoped, no `namespace:`).
- "Consumer Pod cannot schedule because the PV does not advertise `nodeAffinity` for any worker" → the trap the candidate must fix is the missing `spec.nodeAffinity`. We do **NOT** enumerate `spec.nodeAffinity` under `expect:` — open-world won't fail on a missing field, and `null` is unsupported. The right move is to omit it.

The resulting YAML:

```yaml
question: storage-pvc-binding
namespace: ${CKA_SIM_LAB_NS}
resources:
  - kind: pvc
    name: app-data
    namespace: ${CKA_SIM_LAB_NS}
    expect:
      status.phase: Pending
      spec.storageClassName: manual
  - kind: pv
    name: q01-app-pv
    expect:
      status.phase: Available
      spec.storageClassName: manual
      spec.persistentVolumeReclaimPolicy: Retain
```

### Common pitfalls

- **Don't list every field.** Only encode what the prose claims. Open-world means everything else is silently ignored.
- **Don't claim `null` for missing fields.** Open-world handles them silently. Adding a negative claim for a missing-but-expected field is unsupported.
- **Use `${CKA_SIM_LAB_NS}` for namespaced resources.** Cluster-scoped resources (`pv`, `namespace`, `storageclass`, `clusterrole`, `clusterrolebinding`, `priorityclass`, `volumesnapshotclass`) omit `namespace:` entirely.
- **Schema reference:** see [`../cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md`](../cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md) for the resource-kind allow-list, jsonpath translator details, and the absent_resources block.

## Setup-state baseline (`cka-sim/lib/baseline.sh`)

The runner snapshots the cluster after `setup.sh` runs and before the candidate types `done`. The grader uses this snapshot to distinguish setup-seeded resources from candidate-authored ones (Phase 07.1's grading-honesty contract — without this, an empty submission can score points just because `setup.sh` already created the right shape).

Question authors do **NOT** touch `cka-sim/lib/baseline.sh` — it is runner-managed (`cka-sim/lib/cmd/drill.sh:309-318` is the canonical wiring). For details on the snapshot format, the ownership-gate helpers (`assert_changed_since_setup`, `is_candidate_modified`), and how graders consume the snapshot, see [`../cka-sim/GRADING-HONESTY.md`](../cka-sim/GRADING-HONESTY.md).

## Authoring `grade.sh`

`grade.sh` is the per-question pass/fail logic. It runs after the candidate types `done`. Key conventions:

- **Source the grader library:** `cka-sim/lib/grade.sh` exposes `assert_resource_exists`, `assert_field_equals`, `assert_changed_since_setup`, and `record_trap`. The `tests/cases/*.sh` unit harness exercises these against PATH-shadowed kubectl stubs — keep your `grade.sh` testable by composing helpers, not raw kubectl calls.
- **Fail-soft, accumulate.** Failed assertions accumulate (no `die` on first failure). Each assertion is 1 point. Final stdout block emits `SCORE: <passed>/<total>` followed by `Trap N: <description>` lines.
- **Trap diagnostics use `record_trap "<id>"`.** The canonical id list lives at [`../cka-sim/traps/catalog.yaml`](../cka-sim/traps/catalog.yaml). Don't invent ids — pick from the catalog or add an entry there first (lint-traps.sh enforces id validity).
- **Setup-state-aware checks.** Use `assert_changed_since_setup` (or `is_candidate_modified`) for any resource that `setup.sh` seeded. Without this, an empty submission can score points; the Phase 07.1 grading-honesty rebuild closed that leak.

The grader contract is unit-tested via `cka-sim/scripts/test.sh` (step 6, `tests/run.sh`) — every question's `grade.sh` is exercised against an empty submission (must score 0/N) and against `ref-solution.sh` (must score N/N).

## `cka-sim audit` invocation reference

Three scopes:

```
cka-sim audit                       — all expected-symptom.yaml under packs/
cka-sim audit <pack>                — one pack
cka-sim audit <pack>/<question>     — single question
```

Optional flag:

```
--report path/to.md                 — persist same content as a markdown report
```

Exit codes:

```
0  all PASS
1  at least one FAIL
2  preflight error (no live cluster, missing jq/python3/yaml)
```

Audit requires a live kind+Calico (or kubeadm) cluster reachable via `kubectl`. It is intentionally **NOT** wired to GHA `validate.yml` — the lint variant (`cka-sim/scripts/lint-question-symptom.sh`) is the CI gate; audit is the forensic tool. The exit-2 contract on no-cluster is deliberate: audit is invoked one-shot by an operator who needs a live cluster, so a missing cluster is an environment error rather than a benign skip.

A typical forensic run:

```bash
cka-sim audit --report .planning/forensics/audit-2026-05-19.md
```

This walks all 34 domain-pack questions, runs each `setup.sh` against a clean kind+Calico cluster, diffs against the committed `expected-symptom.yaml`, and persists a markdown report under `.planning/forensics/` for review.

## Cross-links

- Schema reference — [`../cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md`](../cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md)
- Candidate-state baseline doc — [`../cka-sim/GRADING-HONESTY.md`](../cka-sim/GRADING-HONESTY.md)
- cka-sim runtime overview — [`../cka-sim/README.md`](../cka-sim/README.md)
- Trap catalog (canonical id list) — [`../cka-sim/traps/catalog.yaml`](../cka-sim/traps/catalog.yaml)
- Phase 16 design context (locked decisions) — [`../.planning/phases/16-question-intent-baseline-harness/16-CONTEXT.md`](../.planning/phases/16-question-intent-baseline-harness/16-CONTEXT.md)

# cka-sim YAML Schemas

Reference for all YAML schemas used in cka-sim. Each schema is enforced by lint-packs.sh during CI and local validation.

## Question `metadata.yaml`

Enforced by: lint-packs.sh pass E

```yaml
id: storage-pvc-binding          # RFC 1123, unique within pack
domain: storage                   # enum: storage|workloads-scheduling|services-networking|cluster-architecture|troubleshooting
estimatedMinutes: 8               # integer, 4-12
verified_against: "1.35"          # k8s version string
traps:                            # ≥1 trap IDs from catalog; each must have
                                  # a matching cka_sim::grade::record_trap call
                                  # in the sibling grade.sh (LINT-01 Phase 12).
                                  # Orphan-trap trimming permitted — declare
                                  # only what your grader detects.
  - trap-wrong-access-mode
references:                       # related resources
  - kind: doc
    target: "https://kubernetes.io/docs/concepts/storage/persistent-volumes/"
    note: "PV/PVC lifecycle"
```

## Pack `manifest.yaml`

Enforced by: lint-packs.sh pass D

```yaml
pack:
  id: storage
  domain: storage
  weight: 10
  description: "Storage 10% domain pack"
questions:
  - id: storage-pvc-binding
    path: 01-pvc-binding
    estimatedMinutes: 8
```

## Exam `manifest.yaml`

Enforced by: lint-packs.sh pass F

```yaml
exam:
  id: blueprint-alpha
  version: "1.0"
  durationMinutes: 120
  estimatedMinutesBudget: [120, 130]
  disclaimer: "Not real CKA exam content; independently authored. Targets v1.35 CKA blueprint."
  weighting:
    storage: 10
    workloads-scheduling: 15
    services-networking: 20
    cluster-architecture: 25
    troubleshooting: 30
questions:
  - pack: storage
    slug: 01-pvc-binding
```

## Trap `catalog.yaml`

Enforced by: lint-packs.sh pass E (trap ID registration)

```yaml
- id: trap-wrong-access-mode
  name: "Wrong access mode"
  description: "PVC requests ReadWriteMany but PV only supports ReadWriteOnce"
  remediation_hint: "Check PV's spec.accessModes matches PVC request"
  references:
    - kind: doc
      target: "https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes"
      note: "Access mode compatibility"
  severity: common
  domain: storage
  source: "CONCERNS.md D-13"
```

## Runtime State Layout

`cka-sim bootstrap` creates `~/.cka-sim/` with three subdirectories. They are
**not** interchangeable — each command writes to a fixed location:

| Path | Written by | Read by | Contents |
|------|-----------|---------|----------|
| `~/.cka-sim/sessions/` | `cka-sim exam` (`exam-state.sh`) | `cka-sim score`, `cka-sim list history` | Exam session records: `<ts>.json` + rendered `<ts>.md` report |
| `~/.cka-sim/reports/` | `cka-sim drill` (`drill.sh`) | — (read manually) | Single-question drill reports: `<ts>-<pack>-<qid>.md` |
| `~/.cka-sim/logs/` | reserved | — | Reserved for future command logging |

**Exam reports live under `sessions/`, not `reports/`.** `cka-sim score` and
`cka-sim list history` operate only on exam sessions. Drill output is written to
`reports/` for manual review and is not surfaced by `score` or `list`.

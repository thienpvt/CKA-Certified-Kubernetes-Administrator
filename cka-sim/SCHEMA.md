# cka-sim YAML Schemas

Reference for all YAML schemas used in cka-sim. Each schema is enforced by lint-packs.sh during CI and local validation.

## Question `metadata.yaml`

Enforced by: lint-packs.sh pass E

```yaml
id: storage-pvc-binding          # RFC 1123, unique within pack
domain: storage                   # enum: storage|workloads-scheduling|services-networking|cluster-architecture|troubleshooting
estimatedMinutes: 8               # integer, 4-12
verified_against: "1.35"          # k8s version string
traps:                            # ≥3 trap IDs from catalog
  - trap-wrong-access-mode
  - trap-missing-storageclass
  - trap-pvc-pending-no-pv
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

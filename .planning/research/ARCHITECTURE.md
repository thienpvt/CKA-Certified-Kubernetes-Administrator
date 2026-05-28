# Architecture Research: v1.1 Dump Cooloo9871 Pack

**Date:** 2026-05-28

## Integration Shape

The new pack should live at:

```text
cka-sim/packs/dump-cooloo9871/
```

Pack files:

```text
README.md
manifest.yaml
coverage.yaml
NN-topic-slug/
  question.md
  metadata.yaml
  setup.sh
  grade.sh
  reset.sh
  ref-solution.sh
  expected-symptom.yaml
```

## Existing Runtime Contracts

- `manifest.yaml` is the source of pack/question discovery.
- `metadata.yaml` declares `id`, `domain`, `estimatedMinutes`, `verified_against`, `traps`, and references.
- `setup.sh` seeds only lab state.
- `grade.sh` reports score through `cka-sim/lib/grade.sh`.
- `reset.sh` is idempotent and cleans namespaced plus cluster-scoped resources safely.
- `expected-symptom.yaml` supports symptom-diff lint and audit tooling.

## Suggested Phase Architecture

### Phase A: Pack Scaffold + Low-Risk Command/API Questions

Build pack shell and questions that mostly grade generated files, commands, and basic Kubernetes objects:

- Q01 contexts/current context
- Q05 pod sorting command
- Q07 resource usage commands
- Q14 cluster info
- Q15 events command
- Q16 namespace/API resources
- Q22 certificate validity
- Q23 kubelet certificate inspection
- Q28 etcd certificate/key inspection

### Phase B: Core Object Authoring Questions

Build standard namespace/object tasks:

- Q03 StatefulSet scale-down
- Q06 PV/PVC/pod volume
- Q10 RBAC
- Q11 DaemonSet
- Q12 Deployment/topology
- Q13 multi-container shared volume
- Q19 secret mount
- Q24 NetworkPolicy
- Q29 kube-proxy service traffic
- Q30 pod/service IP output

### Phase C: Scheduling + Node/Control-Plane Tasks

Build high-risk operational tasks:

- Q02 control-plane scheduling
- Q04 readiness depends on service reachability
- Q09 scheduler disabled/manual binding
- Q17 pod container detail extraction
- Q18 kubelet repair
- Q20 node upgrade/join adaptation
- Q21 static pod and service
- Q25 etcd snapshot save/restore
- Q26 eviction-priority analysis
- Q27 manual API access from pod

### Phase D: Verification + Audit Closure

Run static lint, targeted unit fixtures, and live drill UAT. Fix any setup drift or grading honesty leaks.

## Adaptation Decisions

- Use one pack domain id `dump-cooloo9871`; preserve original source order in manifest.
- Metadata references should point to the source page as prior-art-topic, not copied exercise text.
- Where source requires unavailable multi-cluster state, simulate with generated namespaces, labels, config files, or lab-local control-plane/worker state.
- Where source requires dangerous host changes, follow existing safe patterns from `cluster-architecture` and `troubleshooting`, and mark unsupported-in-audit-mode only if necessary.

## Build Order Rationale

Start with pack shell and file-output/object questions because they prove discovery, naming, lint, and grading shape quickly. Do node/control-plane tasks after shared conventions are stable; they carry most risk for live UAT drift.

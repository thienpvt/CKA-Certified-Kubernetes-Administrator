# Plan 15-05 SUMMARY

**Phase:** 15-live-cluster-symptom-diff-ci
**Plan:** 05 — Cluster-architecture pack expected-symptom YAMLs (8 files)
**Status:** Complete (structural acceptance).

## Files shipped (8)

- `01-rbac-viewer/expected-symptom.yaml` — viewer SA + pod-viewer Role + viewer-binding RoleBinding all present (rules wrong, presence-only check).
- `02-etcd-backup-restore/expected-symptom.yaml` — lab ns Active (filesystem-only sandbox).
- `03-kubeadm-upgrade/expected-symptom.yaml` — lab ns Active (filesystem-only sandbox).
- `04-pss-enforce/expected-symptom.yaml` — lab ns Active + PSS labels (`pod-security.kubernetes.io/enforce=restricted`, `enforce-version=v1.35`); exercises the dotted-key-labels translator branch.
- `05-audit-policy/expected-symptom.yaml` — lab ns Active (filesystem-only sandbox).
- `06-crd-basics/expected-symptom.yaml` — lab ns Active (CRD outside the 21-kind allow-list).
- `07-cri-dockerd-endpoint/expected-symptom.yaml` — lab ns Active (filesystem-only sandbox).
- `08-priorityclass/expected-symptom.yaml` — q08-critical + q08-batch PriorityClasses both `globalDefault: "false"`.

## Verification

- All 8 files parse via `python -c 'import yaml; yaml.safe_load(...)'`.
- All derive from question.md, not setup.sh.
- Plan 04 PSS labels ship with both metadata.labels.* assertions in place
  (no defensive fallback needed — translator already covers dotted-key form
  from plan 01); Plan 07 will verify the translator handles them in the
  live cluster run.

Cluster-architecture pack total: 8/8.

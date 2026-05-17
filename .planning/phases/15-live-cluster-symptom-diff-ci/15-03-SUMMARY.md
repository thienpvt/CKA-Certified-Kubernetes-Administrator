# Plan 15-03 SUMMARY

**Phase:** 15-live-cluster-symptom-diff-ci
**Plan:** 03 — Workloads-scheduling pack expected-symptom YAMLs (8 files)
**Status:** Complete (structural acceptance).

## Files shipped (8)

- `01-deployment-requests/expected-symptom.yaml` — load-app Deployment Available with nginx:1.27; load-app-sa absent.
- `02-rolling-update-rollback/expected-symptom.yaml` — web Deployment Available on nginx:1.25 (pre-update).
- `03-configmap-secret-env-volume/expected-symptom.yaml` — q03-app-config + q03-app-secret present; Pod q03-app absent.
- `04-hpa-metrics-server/expected-symptom.yaml` — q04-load Deployment Available; HPA q04-load absent.
- `05-daemonset/expected-symptom.yaml` — lab ns Active; DaemonSet q05-node-agent absent.
- `06-static-pod/expected-symptom.yaml` — lab ns Active; mirror Pod q06-static-nginx-node-01 absent in default ns.
- `07-native-sidecar/expected-symptom.yaml` — q07-app Deployment Available with both containers (nginx + busybox) in spec.containers (pre-fix shape).
- `08-nodeselector-affinity-taints/expected-symptom.yaml` — q08-gpu-sim Deployment Available=False (replicas blocked by NoSchedule taint).

## Verification

- All 8 files parse via `python -c 'import yaml; yaml.safe_load(...)'`.
- All derive from question.md, not setup.sh.
- Live-cluster end-to-end deferred to plan 07's GHA run.

Workloads-scheduling pack total: 8/8.

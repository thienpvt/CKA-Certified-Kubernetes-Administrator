# Plan 15-06 SUMMARY

**Phase:** 15-live-cluster-symptom-diff-ci
**Plan:** 06 — Troubleshooting pack expected-symptom YAMLs (5 files: 01, 02, 04, 05, 06)
**Status:** Complete (structural acceptance).

## Files shipped (5)

- `01-deploy-svc-mismatch/expected-symptom.yaml` — web Deployment Available; web-svc Service present (selector mismatch -> 0 endpoints, open-world).
- `02-netpol-dns-egress/expected-symptom.yaml` — web + api Deployments both Available.
- `04-debug-node/expected-symptom.yaml` — lab ns Active (filesystem-only sandbox).
- `05-static-pod-manifest/expected-symptom.yaml` — lab ns Active (post-Phase-11 YAML-repair + dry-run framing).
- `06-broken-kubelet/expected-symptom.yaml` — lab ns Active (filesystem-only sandbox).

(troubleshooting/03-coredns-resolution shipped in plan 15-01 as the BUG-M08 motivator.)

## Verification

- All 5 files parse via `python -c 'import yaml; yaml.safe_load(...)'`.
- All derive from question.md, not setup.sh.

Troubleshooting pack total: 6/6 (03 from plan 15-01).
**Repo total now 34/34 expected-symptom.yaml files** — ready for plan 07 CI wire-up.

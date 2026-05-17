# Plan 15-04 SUMMARY

**Phase:** 15-live-cluster-symptom-diff-ci
**Plan:** 04 — Services-networking pack expected-symptom YAMLs (6 files)
**Status:** Complete (structural acceptance).

## Files shipped (6)

- `01-networkpolicy-egress/expected-symptom.yaml` — probe Pod Running; egress-restrict NetworkPolicy present.
- `02-service-core/expected-symptom.yaml` — q02-web Deployment Available; q02-web Service present (selector mismatch is open-world).
- `03-coredns-resolution/expected-symptom.yaml` — q03-dnsclient Pod Running with dnsPolicy=None.
- `04-ingress-path-host/expected-symptom.yaml` — q04-web Service present; Ingress q04-web absent (candidate-authored).
- `05-kube-proxy-mode/expected-symptom.yaml` — lab ns Active (filesystem-only candidate work).
- `06-netpol-endport/expected-symptom.yaml` — q06-server + q06-client Pods Running; q06-allow-range NetworkPolicy absent.

## Verification

- All 6 files parse via `python -c 'import yaml; yaml.safe_load(...)'`.
- All derive from question.md, not setup.sh.

Services-networking pack total: 6/6.

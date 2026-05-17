# Plan 15-07 SUMMARY

**Phase:** 15-live-cluster-symptom-diff-ci
**Plan:** 07 — CI wire-up + synthetic regression test
**Status:** Complete (structural acceptance); live-cluster end-to-end deferred to GHA's first PR run.

## Files created (1) + modified (3)

Created:
- `cka-sim/tests/cases/symptom-diff-regression.sh` (mode 0755) — synthetic regression test. Mutates storage/01 PVC claim from Pending to Bound, runs the lint, asserts exit 1 + the citation pattern `expected 'Bound', got 'Pending'`, restores via trap. Cluster-info gated.

Modified:
- `.github/workflows/validate.yml` — appended a 4th job `symptom-diff` after `shellcheck`. Pinned versions: kind v0.23.0, Calico v3.27.3, kubectl v1.30.0. Steps: install tools -> create kind cluster (CNI disabled) -> apply Calico manifests -> wait nodes Ready + Calico DS rollout -> count gate (must be 34) -> run lint -> diagnostics-on-failure step.
- `cka-sim/scripts/lint-question-symptom.sh` — already shipped the dotted-key labels translator branch in plan 01; no further translator work was needed in plan 07. Verified `metadata.labels.<dotted-key>` form parses and the translator produces a quoted-key jq expression. Acceptance grep `metadata\\.labels\\.` returns 1.
- `cka-sim/tests/run.sh` — added a one-line comment near the cases discovery loop noting Phase 15's regression case is auto-picked up via the existing `find ... -name '*.sh'` walk. Run-time behaviour unchanged (shape A: auto-discovery).

## CI shape

`symptom-diff` job alongside the existing `yamllint`, `bash-tests`, `shellcheck`. ~5-7 min CI overhead acceptable per CONTEXT decision. Failure capture step prints `kubectl get nodes -o wide`, `pods -A`, and recent events to aid PR diagnosis without breaking the existing 3 jobs.

## Synthetic regression

The case proves end-to-end: with a live cluster + the lint script, mutating storage/01's PVC claim must trip exit 1 with the expected file:line citation. Without a cluster, the case warn-skips with rc=0 so local runs continue to pass.

## Verification

- 34 expected-symptom.yaml files (count gate passes).
- All 34 parse via `python -c 'import yaml; yaml.safe_load(...)'`.
- `.github/workflows/validate.yml` parses; 4 jobs present.
- bash syntax clean: lint-question-symptom.sh, symptom-diff-regression.sh, run.sh, test.sh.
- shellcheck not available in the local Windows mingw environment — will be enforced by the existing `shellcheck` GHA job in the same PR.
- Local UAT (no cluster): regression case prints "no live cluster — SKIP" + exit 0, confirmed via direct invocation.
- Live-cluster end-to-end proof deferred to GHA's first run on the PR opened to merge Phase 15.

## ROADMAP success-criteria mapping

1. Every domain-pack question ships an `expected-symptom.yaml` -> 34/34 (storage 6 + workloads-scheduling 8 + services-networking 6 + cluster-architecture 8 + troubleshooting 6).
2. `cka-sim/scripts/lint-question-symptom.sh` runs setup.sh against a kind+Calico cluster, captures kubectl JSON, jsonpath-diffs, exits 1 on divergence with file:line citations -> shipped in plan 15-01.
3. Diff against current HEAD passes for all questions whose setup matches their question.md after Phases 10-14 -> deferred to GHA's first run on the PR; static gates pass.
4. Synthetic regression (revert storage/01 fix or mutate the YAML) makes the diff fail with file:line evidence -> shipped in `symptom-diff-regression.sh`.

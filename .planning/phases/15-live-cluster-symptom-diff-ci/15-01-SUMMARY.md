# Plan 15-01 SUMMARY

**Phase:** 15-live-cluster-symptom-diff-ci
**Plan:** 01 — Engine + schema doc + 2 motivator YAMLs
**Status:** Complete (structural acceptance); live-cluster end-to-end deferred to plan 07 CI run.

## Files created (4) + modified (1)

Created:
- `cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md` — schema reference, allow-list, open-world clause, authoring guidance, worked example.
- `cka-sim/scripts/lint-question-symptom.sh` (mode 0755) — diff engine.
- `cka-sim/packs/storage/01-pvc-binding/expected-symptom.yaml` — BUG-H01 motivator (PVC Pending + PV Available).
- `cka-sim/packs/troubleshooting/03-coredns-resolution/expected-symptom.yaml` — BUG-M08 motivator (q03-coredns Available=False, q03-dnsclient Running).

Modified:
- `cka-sim/scripts/test.sh` — appended a new step (numbered 7, since the file already has steps 1-6 from earlier phases) that invokes the new lint after the unit-cases step. Plan PLAN.md said "step 6"; the actual file has steps 1-6 occupied by earlier phases (lint-traps, lint-packs, lint-coverage, lint-trap-coverage, lint-deprecated-strings, run.sh), so the new invocation is step 7. Functional shape (after unit cases, before `ok "test.sh complete"`) matches the plan.

## Diff engine shape

- bash + jq + python3 (yaml). Pure CLI tools; no Go/Node/Python CLIs.
- Per-question CKA_SIM_LAB_NS isolation: `cka-sim-lint-<pack>-<question>` truncated to 63 chars.
- Cluster-info preflight gate: no live cluster -> warn + exit 0.
- Tool preflight: jq + python3 + python3-yaml; missing tool -> die.
- Resource-kind allow-list of 21 kinds (CONTEXT specifics) mapped from short alias to canonical kubectl kind.
- Three passes per question: (1) capture JSON for each declared resource, (2) jsonpath-evaluate each `expect:` entry against jq, (3) confirm `absent_resources:` are absent.
- Cluster-scoped kinds (pv, namespace, clusterrole, clusterrolebinding, priorityclass, storageclass, volumesnapshotclass) skip `-n` flag automatically.
- Reset is invoked per question regardless of diff outcome.
- File:line citations: emitted via `grep -n` against the YAML (best-effort line resolution; falls back to `?` if the resource/field isn't grep-locatable).

## Schema decisions

- Open-world: only fields under `expect:` are diffed; extra cluster fields don't fail; `absent_resources:` covers negative claims.
- `${CKA_SIM_LAB_NS}` is the only env-var substitution; performed in the python3 yaml parser.
- jsonpath dot-form translator handles two special cases:
  1. `status.conditions[?(@.type=="X")].field` -> `.status.conditions[] | select(.type=="X") | .field`
  2. `metadata.labels.<dotted-key-with-slashes>` -> `.metadata.labels."<unescaped-key>"`
  All other paths fall through as `.<literal-dot-path>` (jq accepts `.spec.template.spec.containers[0].image` natively).

## Sample drift detectors

- `storage/01-pvc-binding/expected-symptom.yaml` — encodes the post-Phase-10 state question.md claims: PVC `app-data` Pending, PV `q01-app-pv` Available with reclaim Retain. A future regression that lets the PVC bind too early or seeds a different storage class trips the diff.
- `troubleshooting/03-coredns-resolution/expected-symptom.yaml` — encodes post-Phase-14 framing: q03-coredns Deployment Available=False, q03-dnsclient Pod Running, ConfigMap and Service present (presence-only). Exercises the conditions-jsonpath translator special case.

## Verification status

- Structural acceptance (always-runnable):
  - `bash -n cka-sim/scripts/lint-question-symptom.sh` -> 0.
  - `python -c 'import yaml; yaml.safe_load(open(...))'` -> 0 for both YAMLs.
  - `bash cka-sim/scripts/lint-question-symptom.sh` (no cluster) -> warn-skip + exit 0 (verified locally).
  - All `<acceptance_criteria>` greps pass (KIND_ALIAS x21 entries, cluster-info gate, jq+python preflight, find/walk pattern, reset invocation, target_arg filter, file:line citation).
  - shellcheck not available in this Windows mingw environment; will be enforced by GHA's `shellcheck` job in plan 07's CI run.
- Live-cluster with-cluster proof: deferred to plan 07's GHA `symptom-diff` job. No local kind/kubeadm cluster available in this executor environment.
- Synthetic regression rehearsal: deferred to plan 07's `cka-sim/tests/cases/symptom-diff-regression.sh`.

## test.sh impact

`bash cka-sim/scripts/test.sh` exits 1 due to 6 pre-existing baseline failures (4 from Phases 10/11 + 2 from Phase 13 — all live-cluster drill regressions tracked separately, NOT introduced by this plan). The new step 7 (symptom-diff lint) is reached only when prior steps succeed; on a no-cluster machine without the baseline failures it would warn-skip cleanly. Phase 15's CI job will verify this end-to-end.

## Wave 2 hand-off

Plans 02-06 author the remaining 32 expected-symptom.yaml files, one per pack. After they land, plan 07 wires the lint into GHA + ships the synthetic regression test, bringing total expected-symptom.yaml count to 34.

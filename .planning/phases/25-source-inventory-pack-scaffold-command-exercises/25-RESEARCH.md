# Phase 25 Research: Source Inventory + Pack Scaffold + Command Exercises

**Researched:** 2026-05-28
**Scope:** Phase 25 implementation planning for `dump-cooloo9871`

## Existing Contracts To Preserve

- Pack root is `cka-sim/packs/<pack-id>/` with `README.md`, `manifest.yaml`, and `coverage.yaml`.
- Question directories currently use the runtime files `question.md`, `metadata.yaml`, `setup.sh`, `grade.sh`, `reset.sh`, `ref-solution.sh`, and often `expected-symptom.yaml`. Phase 25 must create all seven files because `PACK-04` requires the symptom file.
- `metadata.yaml` lint requires `id`, `domain`, `estimatedMinutes`, `verified_against: "1.35"`, `traps`, and `references`.
- Known metadata domain enum is `storage|workloads-scheduling|services-networking|cluster-architecture|troubleshooting`; `dump-cooloo9871` is a pack id, not a new metadata domain unless lint is extended.
- `manifest.yaml` has `pack.id`, `pack.domain`, `pack.weight`, `pack.description`, and ordered `questions` entries with `id`, `path`, and `estimatedMinutes`.
- `coverage.yaml` maps tracker slugs to labels and question ids. `lint-coverage.sh` checks manifest/coverage consistency.
- `setup.sh` uses `#!/bin/bash`, `set -euo pipefail`, requires `CKA_SIM_LAB_NS`, applies resources idempotently, avoids deleting namespace at top, and seeds broken or baseline state.
- `grade.sh` uses `set -uo pipefail`, requires `CKA_SIM_LAB_NS` when cluster resources are read and `CKA_SIM_ROOT`, sources `lib/grade.sh` and usually `lib/traps.sh`, avoids mutating verbs and `kubectl get -A`, accumulates assertions, records traps, and ends with `cka_sim::grade::emit_result`.
- `reset.sh` is non-strict (`set -uo pipefail`), deletes namespace with `--ignore-not-found --wait=false`, cleans cluster-scoped resources if any, and exits 0.
- `ref-solution.sh` uses `set -euo pipefail`, requires `CKA_SIM_LAB_NS`, and applies the smallest passing fix.

## Closest Existing Analogs

- Command/file-output task analog: `cka-sim/packs/services-networking/05-kube-proxy-mode` writes and grades a sandbox file under `/tmp`. Phase 25 user decision rejects this pattern for command-output tasks in favor of live cluster-state grading.
- Read-only control-plane inspection analogs: `cluster-architecture/02-etcd-backup-restore`, `03-kubeadm-upgrade`, and `07-cri-dockerd-endpoint` show how existing host/control-plane tasks document audit limits and use filesystem assertions where Kubernetes API state is insufficient.
- Namespace resource authoring analogs: `storage/01-pvc-binding`, `services-networking/02-service-core`, and `workloads-scheduling/*` show grading helpers, trap use, and setup/reset structure.
- Pack-level analogs: existing domain pack `manifest.yaml` and `coverage.yaml` files are the templates for `dump-cooloo9871`.

## Phase 25 Content Shape

Phase 25 should create the full 30-entry pack scaffold but implement only these 10 command/inspection exercise directories:

- Q01 context/current-context exercise (`CMD-01`)
- Q05 pod sorting command exercise (`CMD-02`)
- Q07 node and pod resource usage command exercise (`CMD-03`)
- Q08 control-plane component inspection exercise (`CMD-04`)
- Q14 cluster node and version reporting exercise (`CMD-05`)
- Q15 cluster events command exercise (`CMD-06`)
- Q16 namespace and namespaced API resources exercise (`CMD-07`)
- Q22 kube-apiserver certificate validity exercise (`CMD-08`)
- Q23 kubelet certificate issuer and extended-key-usage exercise (`CMD-09`)
- Preview Q01 etcd certificate/key inspection exercise (`CMD-10`)

The manifest should list all 30 planned questions in source-derived order. Later phases can replace placeholder directories or fill runtime files for object/operational questions. If `lint-packs.sh` requires every manifest path to exist with full files, Phase 25 plans must either create placeholder seven-file directories for all 30 or defer adding non-Phase-25 entries to `manifest.yaml` until their phase. `PACK-01` success criteria requires 30 planned entries, so preferred path is 30 manifest entries plus placeholder metadata/question files only if lint accepts placeholders; otherwise extend lint or mark later entries as planned in a separate inventory.

## Source Inventory + Adaptation Ledger

Create a maintainer-facing inventory under the pack root, likely `SOURCE-INVENTORY.md`, with:

- Source ordinal (`source-q01`, `source-q02`, `extra-q01`, `preview-q01`)
- Phase assignment (25/26/27)
- Requirement id (`CMD-*`, `OBJ-*`, `OPS-*`)
- Proposed simulator slug
- Metadata domain enum
- v1.35 adaptation note
- Prior-art citation note
- Runtime status (`implemented`, `planned-phase-26`, `planned-phase-27`)

This separates all-30 planning from lintable runtime content if needed.

## Verification Strategy

Phase 25 can run:

- `bash cka-sim/scripts/lint-packs.sh`
- `bash cka-sim/scripts/lint-coverage.sh`
- `bash cka-sim/scripts/lint-traps.sh`
- `bash cka-sim/scripts/lint-trap-coverage.sh`
- `bash cka-sim/scripts/lint-question-symptom.sh`
- `bash cka-sim/scripts/test.sh`

If command/inspection graders rely on live cluster state that the fixture harness cannot fully stub, plans should add focused unit fixtures only where practical and document remaining live proof for Phase 28.

## Risks And Plan Implications

- User chose closer paraphrase for source Q1, but project requirement still forbids verbatim source wording/answers. Plan must include a wording review step for Q1.
- User rejected file-output grading for command-output tasks. Plans need live-state substitutes: resource labels/annotations, ConfigMaps, namespaced resources, or other cluster state that candidate can author and graders can read without mutating.
- User chose broader seeded scenarios. Plans must keep setups idempotent and reset-clean, with RFC 1123 names and no hard-coded node names where avoidable.
- User chose namespace-simulated certificate/key artifacts for Phase 25. Plans should avoid touching host cert paths directly and clearly mark simulation in README/inventory.
- New pack id may not match metadata domain enum. Use existing metadata domains per question unless lint is intentionally extended.

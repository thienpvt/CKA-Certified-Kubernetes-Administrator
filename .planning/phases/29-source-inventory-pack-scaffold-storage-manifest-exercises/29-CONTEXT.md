# Phase 29: Source Inventory + Pack Scaffold + Storage/Manifest Exercises - Context

**Gathered:** 2026-05-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the `cka-prep-2025-v2` pack scaffold, source inventory, adaptation ledger, README, manifest, coverage map, and the Phase 29 storage/manifest exercise batch for source questions 1, 2, 6, and 14. This phase establishes all 17 planned pack entries and delivers complete seven-file runtime directories for MariaDB/PV restore, Argo CD manifest rendering without CRDs, cert-manager CRD inspection, and StorageClass defaulting. Workloads, scheduling, networking, runtime, control-plane, and full live UAT work remains in later phases.

</domain>

<decisions>
## Implementation Decisions

### Source Traceability and Adaptation
- Preserve the exact source topic intent and stable `source-qNN` ordering across manifest, coverage, README, and source inventory, but do not copy source question wording, source solution text, or any real-exam content verbatim.
- Record source clone path `D:\git\CKA-PREP-2025-v2`, pinned commit `38c2a0e3ed3eb93baac4fc7423f082b136a2141f`, and every `Question-*` folder in `SOURCE-INVENTORY.md`.
- Use source material only as prior-art topic context in inventory and metadata; task wording, setup state, grading, reset behavior, and reference solutions belong to this repo.
- Maintain adaptation notes for unsafe or environment-specific assumptions, including Helm, Gateway API, CNI install, cri-dockerd, etcd, TLS host edits, node taints, control-plane mutation, and persistent host edits.

### Pack Scaffold and Discovery
- Add a new pack at `cka-sim/packs/cka-prep-2025-v2` without replacing existing domain packs or the completed `dump-cooloo9871` pack.
- Use traceable question directory names in `NN-source-qNN-kebab-topic` style for all 17 planned entries.
- Keep pack-facing docs concise: source-derived nature, v1.35 adaptations, lab-safety boundaries, drill usage, and seven-file runtime contract.
- Wire manifest and coverage data so existing pack listing, drill selection, and static lint gates discover the scaffold and Phase 29 exercises.

### Runtime Grading and Honesty
- Every implemented question uses the standard seven-file shape: `question.md`, `metadata.yaml`, `setup.sh`, `grade.sh`, `reset.sh`, `ref-solution.sh`, and `expected-symptom.yaml`.
- Setup and reset scripts must be idempotent, namespace-scoped or otherwise reset-safe, and safe to replay on a 1-control-plane plus 2-worker kubeadm lab.
- Graders must score zero when the candidate makes no relevant change; setup state alone must not score.
- Prefer existing shared simulator helpers, trap catalog entries, baseline ownership checks, and live Kubernetes API state over answer files unless a task is explicitly an inspection/write-down exercise.

### Phase 29 Exercise Adaptations
- MariaDB/PV restore should model retained persistent state with lab-safe Kubernetes storage resources and grade the candidate's PVC/workload restoration without deleting retained data.
- Argo CD Helm rendering should be deterministic without requiring live internet, a running Argo CD installation, or cluster CRD installation; grade rendered manifest intent and explicit CRD exclusion.
- cert-manager CRD inspection should not require cert-manager to be installed on the learner cluster; seed deterministic CRD-like resources or docs and require grader-visible captured Certificate subject information.
- StorageClass defaulting should validate `local-storage` as the only default class while reset restores any pre-existing default-class state.

### the agent's Discretion
Plan and implementation may choose exact slugs, namespaces, seeded resource names, trap mappings, fixture scope, and adaptation mechanics so long as they satisfy v1.2 requirements, the decisions above, and existing `cka-sim` contracts.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- Existing pack directories under `cka-sim/packs/{storage,workloads-scheduling,services-networking,cluster-architecture,troubleshooting,dump-cooloo9871}` show the target runtime shape and metadata conventions.
- The completed `dump-cooloo9871` pack provides the closest scaffold pattern: `manifest.yaml`, `coverage.yaml`, `README.md`, `SOURCE-INVENTORY.md`, traceable question directories, and source-derived adaptation notes.
- Shared libraries under `cka-sim/lib/` provide setup helpers, grading helpers, trap recording, baseline ownership checks, and symptom-diff support.
- Validation scripts under `cka-sim/scripts/` include pack, coverage, trap, trap-coverage, question-symptom, deprecated-string, and unit-test gates.

### Established Patterns
- The simulator is bash-only and targets Kubernetes v1.35 on a single learner kubeadm cluster.
- Pack manifests and coverage files are the discovery and traceability surfaces; question metadata carries domain, objective, difficulty, and source/context fields.
- Setup/reset must be idempotent and lab-safe; graders must separate setup state from candidate-authored state and emit named trap diagnostics.
- Static lint and unit fixtures run during phases; full empty-submission, reference-solution, and live UAT proof is batched at milestone close.

### Integration Points
- New content integrates under `cka-sim/packs/cka-prep-2025-v2` with `manifest.yaml`, `coverage.yaml`, `README.md`, `SOURCE-INVENTORY.md`, and per-question directories.
- Pack discovery goes through existing `cka-sim list` and drill/runtime loading code.
- Verification routes through `bash cka-sim/scripts/lint-packs.sh`, `lint-coverage.sh`, `lint-traps.sh`, `lint-trap-coverage.sh`, `lint-question-symptom.sh`, and `bash cka-sim/scripts/test.sh`.

</code_context>

<specifics>
## Specific Ideas

- User requested exact copying of source question content for Q1 during smart discuss; this is not accepted because `SRC-05` and the milestone Out of Scope section explicitly forbid copied source wording or copied answer text. The closest valid implementation is exact topic intent with independently authored wording.
- The source clone exists locally at `D:\git\CKA-PREP-2025-v2` and is pinned at commit `38c2a0e3ed3eb93baac4fc7423f082b136a2141f`.
- Phase 29 should mirror the successful v1.1 source-derived pack approach while adapting to the smaller 17-question v1.2 source set.

</specifics>

<deferred>
## Deferred Ideas

- Workload and scheduling exercises are deferred to Phase 30.
- Networking and add-on-adjacent exercises are deferred to Phase 31.
- Runtime and control-plane safety exercises are deferred to Phase 32.
- Full static-gate, empty-submission, reference-solution, and live UAT proof is deferred to Phase 33.

</deferred>

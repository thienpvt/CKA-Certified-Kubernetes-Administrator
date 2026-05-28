# Phase 25: Source Inventory + Pack Scaffold + Command Exercises - Context

**Gathered:** 2026-05-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the `dump-cooloo9871` pack scaffold, source inventory, adaptation ledger, README, manifest, coverage map, and the Phase 25 command/inspection exercise batch for source Q01/Q05/Q07/Q08/Q14/Q15/Q16/Q22/Q23 and preview Q01. This phase delivers runnable seven-file question directories for the command/inspection slice only; core object, operational, and full live UAT work remains in later phases.

</domain>

<decisions>
## Implementation Decisions

### Source Adaptation + Scaffold
- Use closer paraphrase for source-derived task framing than a fully independent topic rewrite, while still avoiding verbatim source prose, source answers, and any real-exam content.
- Keep all 30 planned entries in stable source-derived order so source Q numbers remain traceable across manifest, coverage, README, and adaptation ledger.
- Cite the cooloo9871 page only as prior-art topic context in metadata; authored wording, setup, grading, and reference solutions belong to this repo.
- Maintain an adaptation ledger covering stale multi-cluster, hard-coded node-name, stale image, and Kubernetes-version assumptions plus v1.35 replacements.

### Command Exercise Runtime
- Grade live cluster state only for command-output tasks; avoid requiring candidate-saved answer files under `/tmp/cka-sim` for Phase 25.
- Seed broader scenario resources where needed so command/inspection tasks feel realistic and can be validated by existing pack runtime behavior.
- Simulate certificate/key inspection artifacts in namespace-scoped resources when direct host certificate access would make Phase 25 live-only.
- Every grader must score 0 when candidate writes nothing or makes no relevant cluster-state change.

### Verification + Boundaries
- Use static lint plus unit fixtures where command-output or state grading can be stubbed without a live cluster.
- Document live-only checks as Phase 28 UAT limitations; do not block Phase 25 on local `kubectl` or live-cluster access.
- Use traceable question directory names in `NN-source-qXX-kebab-topic` style.
- Keep the pack README direct: scope, source-derived nature, v1.35 adaptations, and drill usage.

### the agent's Discretion
Plan and implementation may choose exact slugs, seeded resource shapes, trap mappings, fixture coverage, and wording details so long as they satisfy the decisions above, v1.1 requirements, and existing `cka-sim` contracts.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- Existing pack directories under `cka-sim/packs/{storage,workloads-scheduling,services-networking,cluster-architecture,troubleshooting}` show the target seven-file runtime shape: `question.md`, `metadata.yaml`, `setup.sh`, `grade.sh`, `reset.sh`, `ref-solution.sh`, and `expected-symptom.yaml`.
- Existing shared libraries in `cka-sim/lib/` provide setup helpers, grading helpers, trap recording, baseline ownership checks, and symptom-diff support.
- Existing validation scripts in `cka-sim/scripts/` include pack, coverage, trap, trap-coverage, question-symptom, deprecated-string, and unit-test gates.

### Established Patterns
- The simulator is bash-only and targets Kubernetes v1.35 on a single learner kubeadm cluster.
- Pack manifests and coverage files are the discovery and traceability surfaces; question metadata carries domain, objective, difficulty, and source/context fields.
- Setup and reset scripts must be idempotent and lab-safe; graders must separate setup state from candidate-authored state and emit named trap diagnostics.
- Existing live UAT is batched near milestone close, while static lint and unit fixtures run during phase execution.

### Integration Points
- New content integrates under `cka-sim/packs/dump-cooloo9871` with `manifest.yaml`, `coverage.yaml`, `README.md`, and per-question directories.
- Pack discovery goes through existing `cka-sim list` and drill/runtime loading code.
- Verification routes through `bash cka-sim/scripts/lint-packs.sh`, `lint-coverage.sh`, `lint-traps.sh`, `lint-trap-coverage.sh`, `lint-question-symptom.sh`, and `bash cka-sim/scripts/test.sh`.

</code_context>

<specifics>
## Specific Ideas

- User explicitly chose closer paraphrase for source Q1 framing instead of the recommended fully original topic-only adaptation.
- User chose live cluster state grading, broader seeded scenarios, and namespace-simulated certificate/key artifacts for Phase 25 command/inspection work.

</specifics>

<deferred>
## Deferred Ideas

- Core object exercises are deferred to Phase 26.
- Operational host/control-plane exercises are deferred to Phase 27.
- Full empty-submission, reference-solution, static-gate, and live UAT proof is deferred to Phase 28.

</deferred>

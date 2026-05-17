# Phase 15 Discussion Log

**Discussed:** 2026-05-17
**Mode:** Autonomous --interactive

## Areas Discussed

### Cluster runtime
- Options: kind in GHA / k3s in GHA / local-only
- **User selection:** kind cluster in GHA
- Notes: matches kubeadm topology more faithfully; ROADMAP success criterion 2 explicitly names kind/k3s.

### Symptom YAML format
- Options: per-question / single repo-wide / auto-generated
- **User selection:** Per-question expected-symptom.yaml
- Notes: per-question authoring catches the question.md-vs-setup drift this CI is meant to surface.

### Diff implementation
- Options: pure bash + jq + python yaml / kubectl-neat-based
- **User selection:** Pure bash + jq + python yaml
- Notes: matches project tech-stack constraint; sibling lints already use this toolchain.

### Question coverage
- Options: all 38 / pilot subset / pilot-then-expand
- **User selection:** All 38 questions
- Notes: ROADMAP success criterion 1 demands full coverage. Phase 15 work spans multiple parallel waves to ship the YAML files efficiently.

## Counted vs claimed

- "38 questions" cited in PROJECT.md = domain-pack questions (34) + mock-exam-pack references (4). Domain-pack-only count is 34.
- ROADMAP success criterion 1: "every question in all 5 domain packs" → 34 expected-symptom.yaml files.
- Resolved during planning; no user decision needed.

## Deferred Ideas

- Multi-CNI test matrix — overkill for v1.0.1.
- Auto-generation from question taxonomy — defeats drift-detection purpose.
- Mock-exam-pack symptom diffs — covered transitively via domain-pack diffs.

## Claude's Discretion

- Wave layout (1 schema-and-script wave + 5 per-pack authoring waves + 1 regression-and-CI-wire wave) deferred to planner.
- Specific kind cluster version, calico version, image cache strategy deferred to executor.
- Resource kind allow-list deferred to executor (will read pack content during authoring).

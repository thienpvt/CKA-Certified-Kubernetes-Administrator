# Phase 6: Troubleshooting Pack - Context

**Gathered:** 2026-05-12
**Status:** Ready for planning
**Mode:** Interactive discuss (`--chain`)

<domain>
## Phase Boundary

Author the Troubleshooting domain pack end-to-end — the largest-weight CKA domain (30%) — using the runtime contract, trap framework, helper library, pack lints, and pack authoring patterns already shipped in Phases 2-5. The pack must include troubleshooting questions for CoreDNS, `kubectl debug node`, NetworkPolicy troubleshooting, broken kubelet, static-pod scenarios, and a service/endpoints mismatch scenario. Every question must keep the established six-file shape, meet PACK-06 metadata requirements, reference at least one prior pack question as related prior-art context, and close PACK-07 by bringing the coverage-matrix lint to 100% across all v1.35 Study Progress Tracker checkboxes.

</domain>

<decisions>
## Implementation Decisions

### Question Set and Learning Shape
- **D-01:** Troubleshooting pack total = 6 questions. Required topics: CoreDNS, `kubectl debug node`, NetworkPolicy troubleshooting, broken kubelet, static pod, and service/endpoints mismatch.
- **D-02:** The sixth topic is service/endpoints mismatch. Reuse the Phase 3 troubleshooting reference concept (`01-deploy-svc-mismatch`) as the safe namespace-only app-layer diagnosis question.
- **D-03:** Question order should use a progressive difficulty ramp: service mismatch -> NetworkPolicy -> CoreDNS -> `kubectl debug node` -> static pod -> broken kubelet.
- **D-04:** Prompts are symptoms-only. `question.md` should describe observed failure and desired target behavior, not name the suspected root cause or topic. Candidate must diagnose like real CKA troubleshooting.

### Cross-Pack References
- **D-05:** Each troubleshooting question must include at least one `metadata.yaml.references[]` entry pointing to a prior pack question as related prior-art context.
- **D-06:** Cross-pack references are metadata-only during Phase 6. Do not show them in `question.md` before grading; keep drill experience exam-realistic and avoid root-cause hints.
- **D-07:** Reference targets should use local pack question paths, e.g. `cka-sim/packs/services-networking/03-coredns-resolution/`, not opaque question IDs or old `exercises/` paths.
- **D-08:** References mean "related prior-art," not mandatory prerequisites and not remediation-path UI. Phase 7 reporting can derive remediation later.

### Cluster Impact and Safety
- **D-09:** Broken kubelet and static-pod tasks must use sandbox file copies under `/tmp/qNN-*` or equivalent per-question paths. Candidate fixes the sandboxed manifest/config/flag file; grader validates content and repair reasoning. Do not mutate live `/etc/kubernetes/manifests/`, `/var/lib/kubelet/`, or systemd service files.
- **D-10:** `kubectl debug node` question should require real `kubectl debug node/...` execution for read-only inspection of host state/logs/files, but setup must not modify host state. The candidate practices node-debug workflow without live repair blast radius.
- **D-11:** NetworkPolicy and CoreDNS troubleshooting should be lab-namespace-first. Use per-question app-level DNS/connectivity checks; avoid patching live `kube-system` CoreDNS unless represented by a sandbox ConfigMap/file copy.
- **D-12:** Reset scripts must not restart kubelet or other system services. Reset cleans lab namespaces, debug pods, and per-question `/tmp/qNN-*` artifacts only.

### Trap Catalog
- **D-13:** Troubleshooting trap IDs should emphasize root cause, not only symptom or command mistake. Examples: `service-selector-label-mismatch`, `coredns-forward-invalid-upstream`, `static-pod-manifest-bad-yaml`.
- **D-14:** Add approximately 10 new trap entries in Phase 6: usually 1-2 troubleshooting-specific root-cause traps per question, while reusing prior pack traps when they exactly match.
- **D-15:** Reuse existing trap IDs first. Do not duplicate concepts already present in `cka-sim/traps/catalog.yaml`; add new IDs only for troubleshooting-specific root causes or alternate failure modes.
- **D-16:** Severity policy: root-cause traps that explain failed repair are `error`; secondary command-hygiene or diagnostic-path traps are `warn`. Match prior catalog style and 8-field schema.

### Claude's Discretion
- Exact broken-state YAML, prompt wording, trap wording, and ref-solution mechanics are Claude's discretion within the decisions above.
- Exact mapping of each question to prior pack references is Claude's discretion, as long as every troubleshooting question has at least one strong local pack question path reference.
- Exact `estimatedMinutes` per question is Claude's discretion within PACK-06 `[4,12]`, with harder node/control-plane scenarios expected near the upper end.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap
- `.planning/ROADMAP.md` §"Phase 6: Troubleshooting Pack" — phase goal, requirements PACK-05/PACK-06/PACK-07, success criteria, dependency on Phase 5.
- `.planning/REQUIREMENTS.md` §"Domain packs" — PACK-05 troubleshooting minimum topics, PACK-06 metadata schema, PACK-07 coverage matrix.
- `.planning/REQUIREMENTS.md` §"Runtime contract" — TRIP-01..07 question triplet shape, idempotency, namespace naming, reset semantics, RFC 1123 naming.
- `.planning/REQUIREMENTS.md` §"Grader" — GRADE-02 behavioural assertions, GRADE-03 SCORE/Trap output, GRADE-04 ≥3 registered traps, GRADE-06 round-trip self-check.

### Prior phase contracts
- `.planning/phases/03-runtime-contract-drill-mode/03-CONTEXT.md` — six-file question shape, `cka-sim drill` contract, reference troubleshooting question `01-deploy-svc-mismatch`, metadata schema/lint contract.
- `.planning/phases/04-storage-workloads-scheduling-packs/04-CONTEXT.md` — pack authoring workflow, `coverage.yaml`, `lint-coverage.sh`, `lib/setup.sh` helper pattern, live verification pattern.
- `.planning/phases/05-services-networking-cluster-architecture-packs/05-CONTEXT.md` — cross-pack reference deferral to Phase 6, safe sandbox-path convention for host-level mutations, Services/Networking and Cluster-Architecture question paths Phase 6 should reference.
- `.planning/phases/02-trap-framework-assertion-library/02-CONTEXT.md` — trap catalog schema, detector/finalizer contract, trap ID validation.

### Code and content anchors
- `cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/` — Phase 3 reference question to retrofit or extend into the 6-question pack.
- `cka-sim/packs/services-networking/03-coredns-resolution/` — likely prior-art reference for CoreDNS troubleshooting question.
- `cka-sim/packs/services-networking/06-netpol-endport/` and `cka-sim/packs/services-networking/01-networkpolicy-egress/` — likely prior-art references for NetworkPolicy troubleshooting question.
- `cka-sim/packs/services-networking/02-service-core/` — likely prior-art reference for service/endpoints mismatch question.
- `cka-sim/packs/cluster-architecture/02-etcd-backup-restore/`, `03-kubeadm-upgrade/`, and `07-cri-dockerd-endpoint/` — likely prior-art references for node/control-plane troubleshooting patterns where relevant.
- `exercises/11-troubleshoot-cluster/` — old superseded prior art for troubleshooting style; link-only if useful, never copy or execute.
- `exercises/17-kubectl-debug/` — old superseded prior art for `kubectl debug node`; link-only if useful, never copy or execute.
- `troubleshooting/README.md` — symptom-indexed playbook; use for scenario inspiration, not as executable source.
- `.planning/codebase/CONCERNS.md` — content-accuracy and safety concerns, especially CoreDNS/networking drift, kubelet flag-file accuracy, and live-cluster safety.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `cka-sim/lib/grade.sh` + `cka-sim/lib/traps.sh` — every `grade.sh` composes assertion helpers and explicit trap recording from these libraries.
- `cka-sim/lib/setup.sh` — existing setup helpers (`ensure_lab_ns`, `wait_for_ns_active`, `seed_pv_hostpath`, `seed_deployment`) plus Phase 5 helper additions (`seed_netpol_skeleton`, `read_node_worker`) should be reused where available.
- `cka-sim/traps/catalog.yaml` — existing catalog must be reused first before adding troubleshooting-specific traps.
- `cka-sim/scripts/lint-packs.sh`, `lint-traps.sh`, and `lint-coverage.sh` — Phase 6 extends existing validation; do not invent separate lint surfaces.
- `cka-sim/packs/*/*/metadata.yaml` — established metadata shape, including `references: []`, `verified_against: "1.35"`, and ≥3 traps.

### Established Patterns
- Every question directory has exactly: `metadata.yaml`, `question.md`, `setup.sh`, `grade.sh`, `reset.sh`, `ref-solution.sh`.
- Pack root has `manifest.yaml`, `README.md`, and `coverage.yaml`.
- Per-question lab namespace format is `cka-sim-<pack>-NN` or the already-established equivalent used by runner/env vars.
- `setup.sh` is idempotent and fail-fast; `reset.sh` is cleanup-tolerant and uses `--ignore-not-found`.
- Graders use behavioural/structural assertions (`kubectl auth can-i`, `kubectl exec` probes, jsonpath) and avoid `kubectl get | grep` / `kubectl get -A`.
- Host-level mutation simulations use sandbox paths under `/tmp/qNN-*` with reset cleanup, per Phase 5.

### Integration Points
- `cka-sim drill troubleshooting` already follows the runner triplet contract once pack manifest/questions exist.
- `scripts/lint-coverage.sh` must include troubleshooting and report full milestone coverage 100%.
- Phase 7 exam blueprints depend on troubleshooting pack question IDs, `estimatedMinutes`, and pack manifest entries.
- Phase 6 metadata references become inputs for future report/remediation routing, even though they stay invisible in `question.md` now.

</code_context>

<specifics>
## Specific Ideas

- Proposed 6-question sequence:
  1. `01-deploy-svc-mismatch` — app is unreachable because Service selector does not match Deployment labels; safe namespace-only.
  2. `02-netpol-deny-egress` or `02-netpol-troubleshooting` — app cannot reach DNS/API/backend because policy misses required egress/selector semantics.
  3. `03-coredns-resolution` — DNS symptom diagnosed through app-level checks and sandboxed CoreDNS config/copy, not live kube-system patch.
  4. `04-debug-node` — use real `kubectl debug node/...` for read-only inspection; no host mutation.
  5. `05-static-pod-manifest` — repair sandboxed static Pod manifest/config, validate YAML/root cause without touching `/etc/kubernetes/manifests/`.
  6. `06-broken-kubelet` — repair sandboxed kubelet flags/config/log-root-cause file, validate no removed flags or wrong file path.
- Candidate-facing prompts should state symptoms like "DNS lookup from pod fails" or "control-plane component never becomes healthy," not "fix CoreDNS" or "fix static pod YAML."
- Cross-pack refs should be strong and local: e.g. CoreDNS troubleshooting references Phase 5 CoreDNS question; service mismatch references Phase 5 service-core; NetworkPolicy references Phase 3/5 NetworkPolicy questions; node/control-plane tasks reference Cluster-Architecture questions where concepts overlap.

</specifics>

<deferred>
## Deferred Ideas

- Showing remediation links after grading belongs in Phase 7 reporting / score UX, not Phase 6 question authoring.
- Real live kubelet/static-pod break/fix drills are out of scope for v1 safety; consider v1.x only if runner gains explicit destructive-lab confirmation and robust rollback.
- Hint reveal remains DF-08 and stays out of Phase 6; no `hint.md` files.

</deferred>

---

*Phase: 6-Troubleshooting Pack*
*Context gathered: 2026-05-12*

# Milestones

## v1.0 CKA Exam Simulator MVP (Shipped: 2026-05-16)

**Phases completed:** 9 phases, 88 plans, 51 tasks

**Key accomplishments:**

- Phase:
- Shipped the two sourceable bash libraries every Phase 3+ grader will consume: `grade.sh` with 7 named assertion helpers + a record_trap/emit_result state machine (GRADE-01), and `traps.sh` with the RFC 1123 validator, pure-bash catalog parser, and runtime lookup helpers (TRIP-07).
- Filled the 8-entry trap catalog (`cka-sim/traps/catalog.yaml`) with all GRADE-05 CONCERNS-derived content-bug IDs and wired 8 matching detector functions into `cka-sim/lib/traps.sh` — 3 kubectl-backed, 5 text-input — so every Phase 3+ grader can resolve a known trap at runtime and get back a stable RFC 1123 trap-id.
- `cka-sim/tests/bin/kubectl` (PATH-shadow stub, D-09).
- Detector fixtures (9 JSON, D-12 coverage).
- Plan:
- 5 new trap entries extend cka-sim/traps/catalog.yaml from 8 to 13 — unblocks Wave 3 per-question metadata.yaml files and adds a state-detectable RBAC trap for D-10's revised cluster-architecture/01-rbac-viewer mapping.
- Full `cka-sim drill <pack> [<n>]` orchestrator replacing the Phase 1 stub — pure-bash YAML parser, EXIT-trap cleanup, mktemp+atomic-mv report file, 4 offline unit tests covering parser, index selection, namespace format, and orchestration order.
- 1. [Rule 3 - Blocking] Acceptance-criterion substring collision
- question.md acceptance-criteria conflict.
- Ships a drillable Service-endpoints-empty troubleshooting question where the trap is a Deployment pod label set that doesn't match the Service selector, graded by `assert_endpoints_nonempty` + `detect_service_label_mismatch` wired to the catalog id `service-selector-empty-endpoints`.
- 4-function shared setup library (`cka-sim/lib/setup.sh`) with 120s ns-Active wait extracted verbatim from Phase 3 commit 5c421c1, plus 4 unit cases proving each helper's observable contract.
- PACK-07 coverage-matrix lint — per-pack coverage.yaml mapping Tracker checkboxes to question-ids, enforced by a pure-bash linter with 4-path fixture coverage (good / missing-ref / empty-tracker / orphan).
- storage/01-pvc-binding/setup.sh now delegates ns create + 120s Active wait to lib/setup.sh helpers; 32-line inline loop removed, trap semantics byte-identical, 29/29 test.sh cases green.
- workloads-scheduling/01-deployment-requests/setup.sh now sources cka-sim/lib/setup.sh; 24-line inline ns-Active wait replaced with two helper calls; Deployment trap heredoc preserved byte-for-byte.
- Shipped the six-file StorageClass + dynamic provisioning pack question (PVC `app-cache` + missing StorageClass `fast-ssd` scenario), three-assertion behavioural grader, rancher.io/local-path ref-solution, and round-trip fixture triplet — test.sh + lint-packs.sh green at 18 pack-lint checks + 29/29 unit cases.
- Bundled access-modes + reclaim-policy Tracker coverage via one scenario: 2 PVs + 2 PVCs where fixing the RWX PVC's Pending state requires patching PV accessModes, and a separate business-rule change requires flipping the Retain PV's reclaim policy to Delete. Six-file question + three fixtures + full lint-packs.sh and test.sh green.
- CSI + VolumeSnapshot question (CG-01) self-installs hostpath-csi v1.14.0 + external-snapshotter v7.0.2 behind idempotent sentinels, seeds a WFFC PVC + marker writer pod, grades via `kubectl wait --for=jsonpath readyToUse=true`, and refcounts the driver on reset via `cka-sim/uses=csi-hostpath` labels.
- Storage Q05 `05-wait-for-first-consumer` ships: StorageClass `q05-wffc` + manual hostPath PV `q05-wffc-pv` + Pending PVC `q05-claim`; candidate writes Pod `q05-consumer` to trigger the WFFC binder; three behavioural assertions + three trap IDs covered.
- Storage pack Q06 `storage-pvc-mount-pod`: candidate mounts a pre-seeded Bound PVC read-only in a Deployment; grader verifies via `kubectl exec ... cat /data/marker` behavioural probe.
- Ships Deployment `web` at `nginx:1.25` with RollingUpdate strategy (`maxUnavailable:0`, `maxSurge:1`) and pre-seeded revision history so `kubectl rollout undo` has a prior state to return to. Grade uses `kubectl rollout status` exit-code behavioural check plus `.metadata.generation >= 3` to prove candidate rolled forward AND back.
- Workloads & Scheduling pack Q03 `workloads-configmap-secret-env-volume`: candidate builds a Pod that reads a ConfigMap key into an env var via `valueFrom.configMapKeyRef` AND mounts a Secret read-only at `/etc/app-secrets/api-key`; grader verifies via jsonpath plus `kubectl exec printenv` + `kubectl exec cat /etc/app-secrets/api-key` behavioural probes.
- Workloads pack Q04 `workloads-hpa-metrics-server`: candidate installs metrics-server v0.7.2 with the kubeadm `--kubelet-insecure-tls` patch and creates an HPA v2 (1→5 replicas @ 50% CPU) on a pre-seeded Deployment `q04-load`; reset keeps the scraper resident (RESEARCH §6.2 policy).
- Workloads & Scheduling pack Q05 `workloads-daemonset`: candidate authors a DaemonSet `q05-node-agent` that schedules on every Ready node (incl. control-plane) via an operator=Exists toleration; grader computes node count dynamically and enforces parity with `status.desiredNumberScheduled`.
- Three Workloads & Scheduling questions shipped as one plan: kubelet-mirrored static pod on node-01, v1.35 native sidecar via initContainers[].restartPolicy=Always, and bundled nodeSelector/nodeAffinity/taints with cluster-scoped label+taint cleanup in reset.
- Task 1 — Pack manifests (commit `90c395f`)
- 8dc3c82
- 1. [Rule 1 - Bug] Comment in setup.sh contained literal `node-02`
- 1. [Rule 3 - Blocking Issue] lint-packs pass F exposed pre-existing static-pod node literals
- Retrofitted `01-networkpolicy-egress/setup.sh` to source `lib/setup.sh` helpers (24-line ns-wait poll collapsed to 2 lines) and scaffolded `services-networking` pack shell with parallel-safe sentinel blocks in `manifest.yaml`, `coverage.yaml`, and `README.md` so Wave 2 plans P03-P07 can idempotently append their rows without line-level merge conflicts.
- Cluster-architecture pack shell ready for 8 questions (Q01 filled via narrow lib/setup.sh retrofit; Q02-Q08 slots declared via sentinel blocks for parallel Wave 2 appends)
- Admission capture owner.
- 1. [Rule 1 - Bug] Fixed pre-existing GRADE-02 false positive in PriorityClass grader
- Troubleshooting trap catalog expanded with 11 Phase 6 root-cause IDs for downstream metadata validation
- 1. [Rule 2 - Missing critical catalog dependency] Registered `imagepullbackoff-wrong-tag`
- 1. [Rule 3 - Blocking] Python launcher unavailable as `python3` on Windows
- 1. [Rule 3 - Blocking] Allow dry-run kubectl apply in grade lint
- 1. [Rule 2 - Critical safety] Scrubbed live path mention from seeded placeholder
- 1. [Rule 2 - Critical verification hygiene] Avoided forbidden command literals in VERIFICATION.md prose
- UAT Test 2 — PASS (re-run #4, 2026-05-15).
- 1. [Rule 3 - Blocking] detect_pvc_wrong_storageclass does not exist
- Found during:
- Found during:
- 7 W&S graders audited + fixed using Wave 2 playbook (assert_changed_since_setup / assert_resource_candidate_authored); 7 regression tests + 28 hand-authored fixtures bring all 8 W&S questions under grading-honesty CI.
- 1. [Rule 1 - Bug] Q03 dnsPolicy gate tightened
- Found during:
- 1. [Rule 1 - Bug] Q02 assert_pod_ready was not initially demoted
- 1. [Rule 3 - Blocking] All 34 reset.sh files missing /tmp/cka-sim/ cleanup

---

## v1.0 CKA Exam Simulator MVP (Shipped: 2026-05-16)

**Phases completed:** 9 phases, 88 plans, 51 tasks

**Key accomplishments:**

- Phase:
- Shipped the two sourceable bash libraries every Phase 3+ grader will consume: `grade.sh` with 7 named assertion helpers + a record_trap/emit_result state machine (GRADE-01), and `traps.sh` with the RFC 1123 validator, pure-bash catalog parser, and runtime lookup helpers (TRIP-07).
- Filled the 8-entry trap catalog (`cka-sim/traps/catalog.yaml`) with all GRADE-05 CONCERNS-derived content-bug IDs and wired 8 matching detector functions into `cka-sim/lib/traps.sh` — 3 kubectl-backed, 5 text-input — so every Phase 3+ grader can resolve a known trap at runtime and get back a stable RFC 1123 trap-id.
- `cka-sim/tests/bin/kubectl` (PATH-shadow stub, D-09).
- Detector fixtures (9 JSON, D-12 coverage).
- Plan:
- 5 new trap entries extend cka-sim/traps/catalog.yaml from 8 to 13 — unblocks Wave 3 per-question metadata.yaml files and adds a state-detectable RBAC trap for D-10's revised cluster-architecture/01-rbac-viewer mapping.
- Full `cka-sim drill <pack> [<n>]` orchestrator replacing the Phase 1 stub — pure-bash YAML parser, EXIT-trap cleanup, mktemp+atomic-mv report file, 4 offline unit tests covering parser, index selection, namespace format, and orchestration order.
- 1. [Rule 3 - Blocking] Acceptance-criterion substring collision
- question.md acceptance-criteria conflict.
- Ships a drillable Service-endpoints-empty troubleshooting question where the trap is a Deployment pod label set that doesn't match the Service selector, graded by `assert_endpoints_nonempty` + `detect_service_label_mismatch` wired to the catalog id `service-selector-empty-endpoints`.
- 4-function shared setup library (`cka-sim/lib/setup.sh`) with 120s ns-Active wait extracted verbatim from Phase 3 commit 5c421c1, plus 4 unit cases proving each helper's observable contract.
- PACK-07 coverage-matrix lint — per-pack coverage.yaml mapping Tracker checkboxes to question-ids, enforced by a pure-bash linter with 4-path fixture coverage (good / missing-ref / empty-tracker / orphan).
- storage/01-pvc-binding/setup.sh now delegates ns create + 120s Active wait to lib/setup.sh helpers; 32-line inline loop removed, trap semantics byte-identical, 29/29 test.sh cases green.
- workloads-scheduling/01-deployment-requests/setup.sh now sources cka-sim/lib/setup.sh; 24-line inline ns-Active wait replaced with two helper calls; Deployment trap heredoc preserved byte-for-byte.
- Shipped the six-file StorageClass + dynamic provisioning pack question (PVC `app-cache` + missing StorageClass `fast-ssd` scenario), three-assertion behavioural grader, rancher.io/local-path ref-solution, and round-trip fixture triplet — test.sh + lint-packs.sh green at 18 pack-lint checks + 29/29 unit cases.
- Bundled access-modes + reclaim-policy Tracker coverage via one scenario: 2 PVs + 2 PVCs where fixing the RWX PVC's Pending state requires patching PV accessModes, and a separate business-rule change requires flipping the Retain PV's reclaim policy to Delete. Six-file question + three fixtures + full lint-packs.sh and test.sh green.
- CSI + VolumeSnapshot question (CG-01) self-installs hostpath-csi v1.14.0 + external-snapshotter v7.0.2 behind idempotent sentinels, seeds a WFFC PVC + marker writer pod, grades via `kubectl wait --for=jsonpath readyToUse=true`, and refcounts the driver on reset via `cka-sim/uses=csi-hostpath` labels.
- Storage Q05 `05-wait-for-first-consumer` ships: StorageClass `q05-wffc` + manual hostPath PV `q05-wffc-pv` + Pending PVC `q05-claim`; candidate writes Pod `q05-consumer` to trigger the WFFC binder; three behavioural assertions + three trap IDs covered.
- Storage pack Q06 `storage-pvc-mount-pod`: candidate mounts a pre-seeded Bound PVC read-only in a Deployment; grader verifies via `kubectl exec ... cat /data/marker` behavioural probe.
- Ships Deployment `web` at `nginx:1.25` with RollingUpdate strategy (`maxUnavailable:0`, `maxSurge:1`) and pre-seeded revision history so `kubectl rollout undo` has a prior state to return to. Grade uses `kubectl rollout status` exit-code behavioural check plus `.metadata.generation >= 3` to prove candidate rolled forward AND back.
- Workloads & Scheduling pack Q03 `workloads-configmap-secret-env-volume`: candidate builds a Pod that reads a ConfigMap key into an env var via `valueFrom.configMapKeyRef` AND mounts a Secret read-only at `/etc/app-secrets/api-key`; grader verifies via jsonpath plus `kubectl exec printenv` + `kubectl exec cat /etc/app-secrets/api-key` behavioural probes.
- Workloads pack Q04 `workloads-hpa-metrics-server`: candidate installs metrics-server v0.7.2 with the kubeadm `--kubelet-insecure-tls` patch and creates an HPA v2 (1→5 replicas @ 50% CPU) on a pre-seeded Deployment `q04-load`; reset keeps the scraper resident (RESEARCH §6.2 policy).
- Workloads & Scheduling pack Q05 `workloads-daemonset`: candidate authors a DaemonSet `q05-node-agent` that schedules on every Ready node (incl. control-plane) via an operator=Exists toleration; grader computes node count dynamically and enforces parity with `status.desiredNumberScheduled`.
- Three Workloads & Scheduling questions shipped as one plan: kubelet-mirrored static pod on node-01, v1.35 native sidecar via initContainers[].restartPolicy=Always, and bundled nodeSelector/nodeAffinity/taints with cluster-scoped label+taint cleanup in reset.
- Task 1 — Pack manifests (commit `90c395f`)
- 8dc3c82
- 1. [Rule 1 - Bug] Comment in setup.sh contained literal `node-02`
- 1. [Rule 3 - Blocking Issue] lint-packs pass F exposed pre-existing static-pod node literals
- Retrofitted `01-networkpolicy-egress/setup.sh` to source `lib/setup.sh` helpers (24-line ns-wait poll collapsed to 2 lines) and scaffolded `services-networking` pack shell with parallel-safe sentinel blocks in `manifest.yaml`, `coverage.yaml`, and `README.md` so Wave 2 plans P03-P07 can idempotently append their rows without line-level merge conflicts.
- Cluster-architecture pack shell ready for 8 questions (Q01 filled via narrow lib/setup.sh retrofit; Q02-Q08 slots declared via sentinel blocks for parallel Wave 2 appends)
- Admission capture owner.
- 1. [Rule 1 - Bug] Fixed pre-existing GRADE-02 false positive in PriorityClass grader
- Troubleshooting trap catalog expanded with 11 Phase 6 root-cause IDs for downstream metadata validation
- 1. [Rule 2 - Missing critical catalog dependency] Registered `imagepullbackoff-wrong-tag`
- 1. [Rule 3 - Blocking] Python launcher unavailable as `python3` on Windows
- 1. [Rule 3 - Blocking] Allow dry-run kubectl apply in grade lint
- 1. [Rule 2 - Critical safety] Scrubbed live path mention from seeded placeholder
- 1. [Rule 2 - Critical verification hygiene] Avoided forbidden command literals in VERIFICATION.md prose
- UAT Test 2 — PASS (re-run #4, 2026-05-15).
- 1. [Rule 3 - Blocking] detect_pvc_wrong_storageclass does not exist
- Found during:
- Found during:
- 7 W&S graders audited + fixed using Wave 2 playbook (assert_changed_since_setup / assert_resource_candidate_authored); 7 regression tests + 28 hand-authored fixtures bring all 8 W&S questions under grading-honesty CI.
- 1. [Rule 1 - Bug] Q03 dnsPolicy gate tightened
- Found during:
- 1. [Rule 1 - Bug] Q02 assert_pod_ready was not initially demoted
- 1. [Rule 3 - Blocking] All 34 reset.sh files missing /tmp/cka-sim/ cleanup

---

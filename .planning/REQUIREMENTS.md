# Requirements: CKA Exam Simulator v1.2

**Defined:** 2026-05-29
**Core Value:** A candidate can take a 2-hour timed mock exam against their own cluster and get an honest, trap-aware score telling them exactly which CKA domains and which classes of mistake they need to drill before sitting the real exam.

## v1.2 Requirements

Requirements for the `cka-prep-2025-v2` source-derived drill pack. Each requirement maps to exactly one roadmap phase.

### Source Inventory

- [ ] **SRC-04**: Maintainer can see the cloned `vj2201/CKA-PREP-2025-v2` source commit, local path, and all included `Question-*` folders in a pack source inventory.
- [ ] **SRC-05**: Maintainer can trace each of the 17 source topics to one new simulator question without relying on copied source wording or copied answer text.
- [ ] **SRC-06**: Maintainer can see adaptation notes for unsafe or environment-specific source assumptions, including Helm, Gateway API, CNI install, cri-dockerd, etcd, TLS host edits, node taints, and control-plane mutation.

### Pack Scaffold

- [ ] **PACK-05**: User can discover a new `cka-prep-2025-v2` pack through existing pack listing and drill selection behavior.
- [ ] **PACK-06**: Maintainer can inspect `cka-sim/packs/cka-prep-2025-v2/manifest.yaml`, `coverage.yaml`, `README.md`, and `SOURCE-INVENTORY.md`.
- [ ] **PACK-07**: Every new question directory follows the standard seven-file shape: `question.md`, `metadata.yaml`, `setup.sh`, `grade.sh`, `reset.sh`, `ref-solution.sh`, and `expected-symptom.yaml`.
- [ ] **PACK-08**: New pack content does not modify existing domain packs or the completed `dump-cooloo9871` pack.

### Source-Derived Exercises

- [ ] **VJQ-01**: User can restore a MariaDB Deployment using a retained PersistentVolume and a newly created PVC without losing persistent state.
- [ ] **VJQ-02**: User can produce an Argo CD Helm-rendered manifest with CRDs excluded, adapted so grading remains deterministic in this simulator.
- [ ] **VJQ-03**: User can add a sidecar container to an existing WordPress Deployment with a shared log volume.
- [ ] **VJQ-04**: User can rebalance resource requests and limits across a scaled WordPress Deployment and restore the intended replica count.
- [ ] **VJQ-05**: User can create an HPA targeting an existing Deployment with CPU utilization, replica bounds, and downscale stabilization settings.
- [ ] **VJQ-06**: User can inspect cert-manager CRDs and capture the requested Certificate subject documentation in a grader-visible resource.
- [ ] **VJQ-07**: User can create a PriorityClass one less than the highest existing user-defined PriorityClass and patch a Deployment to use it.
- [ ] **VJQ-08**: User can validate or model CNI capabilities needed for pod connectivity and NetworkPolicy enforcement without unsafe cluster CNI replacement during drill execution.
- [ ] **VJQ-09**: User can repair a simulated cri-dockerd/runtime configuration and sysctl state without mutating the host operating system.
- [ ] **VJQ-10**: User can taint a discovered worker node and schedule a tolerated pod onto that node with reset-safe cleanup.
- [ ] **VJQ-11**: User can migrate an existing Ingress-shaped route to Gateway API resources while handling clusters that may not ship Gateway CRDs by default.
- [ ] **VJQ-12**: User can expose an existing Deployment with a NodePort Service and an Ingress resource without requiring persistent `/etc/hosts` changes.
- [ ] **VJQ-13**: User can choose and apply the least-permissive NetworkPolicy that permits frontend-to-backend traffic.
- [ ] **VJQ-14**: User can create, patch, and verify a `local-storage` StorageClass as the only default class.
- [ ] **VJQ-15**: User can repair a simulated kube-apiserver etcd endpoint misconfiguration without breaking the real control plane.
- [ ] **VJQ-16**: User can expose a Deployment through a fixed NodePort Service on port 30080.
- [ ] **VJQ-17**: User can restrict an nginx TLS ConfigMap to TLSv1.3 and verify the service path through simulator-safe checks.

### Verification

- [ ] **VER-06**: Static gates pass for the new pack: pack lint, coverage lint, trap lint, trap-coverage lint, question-symptom lint, and bash unit tests.
- [ ] **VER-07**: Empty-submission verification records zero scored points for every new `cka-prep-2025-v2` exercise.
- [ ] **VER-08**: Reference-solution verification records max score and no unexpected traps for every new `cka-prep-2025-v2` exercise.
- [ ] **VER-09**: Live drill UAT covers high-risk host/control-plane/networking exercises and records setup, grade, reference, reset, and cleanup evidence.
- [ ] **VER-10**: Milestone audit records requirement coverage, verification evidence, known limitations, and readiness for milestone completion.

## Future Requirements

Deferred to future releases. Tracked but not in current roadmap.

### Source-Derived Packs

- **FUT-01**: User can combine source-derived packs into a timed mixed exam blueprint.
- **FUT-02**: Maintainer can auto-generate a source inventory skeleton from cloned `Question-*` folders.
- **FUT-03**: Maintainer can tag non-CKA-adjacent source topics with a stable adaptation taxonomy across packs.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Replacing existing domain packs | v1.2 adds a separate pack; existing packs remain validated baseline content. |
| Copying source question text or solution text verbatim | Source repo is topic inventory only; simulator content must be original and v1.35-adapted. |
| Mutating the learner host permanently | Drills must reset cleanly and avoid persistent host edits such as `/etc/hosts`, runtime service changes, or CNI replacement. |
| Requiring live internet during drill execution | Runtime should work from the repo and cluster; source clone is for authoring context, not learner execution. |
| Guaranteeing external add-ons are installed | Helm, Gateway API, ingress controllers, and metrics-server must be handled through deterministic adaptation or explicit live-only limits. |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SRC-04 | Phase 29 | Pending |
| SRC-05 | Phase 29 | Pending |
| SRC-06 | Phase 29 | Pending |
| PACK-05 | Phase 29 | Pending |
| PACK-06 | Phase 29 | Pending |
| PACK-07 | Phase 29 | Pending |
| PACK-08 | Phase 29 | Pending |
| VJQ-01 | Phase 29 | Pending |
| VJQ-02 | Phase 29 | Pending |
| VJQ-06 | Phase 29 | Pending |
| VJQ-14 | Phase 29 | Pending |
| VJQ-03 | Phase 30 | Pending |
| VJQ-04 | Phase 30 | Pending |
| VJQ-05 | Phase 30 | Pending |
| VJQ-07 | Phase 30 | Pending |
| VJQ-10 | Phase 30 | Pending |
| VJQ-08 | Phase 31 | Pending |
| VJQ-11 | Phase 31 | Pending |
| VJQ-12 | Phase 31 | Pending |
| VJQ-13 | Phase 31 | Pending |
| VJQ-16 | Phase 31 | Pending |
| VJQ-17 | Phase 31 | Pending |
| VJQ-09 | Phase 32 | Pending |
| VJQ-15 | Phase 32 | Pending |
| VER-06 | Phase 33 | Pending |
| VER-07 | Phase 33 | Pending |
| VER-08 | Phase 33 | Pending |
| VER-09 | Phase 33 | Pending |
| VER-10 | Phase 33 | Pending |

**Coverage:**
- v1.2 requirements: 29 total
- Mapped to phases: 29
- Unmapped: 0

---
*Requirements defined: 2026-05-29*
*Last updated: 2026-05-29 after v1.2 milestone definition*

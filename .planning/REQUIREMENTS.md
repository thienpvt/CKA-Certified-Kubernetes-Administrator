# Requirements: CKA Exam Simulator v1.1 Dump Cooloo9871 Pack

**Defined:** 2026-05-28
**Core Value:** A candidate can take a 2-hour timed mock exam against their own cluster and get an honest, trap-aware score telling them exactly which CKA domains and which classes of mistake they need to drill before sitting the real exam.

## v1.1 Requirements

### Source Adaptation

- [ ] **SRC-01**: Maintainer can review an inventory covering all 30 approved source topics from the cooloo9871 CKA page: 25 main, 2 extra, and 3 preview questions.
- [ ] **SRC-02**: Maintainer can see v1.35 adaptation notes for every source-derived topic, including any replacement for stale multi-cluster, node-name, image, or Kubernetes-version assumptions.
- [ ] **SRC-03**: Maintainer can verify that `dump-cooloo9871` uses original exercise wording, setup, grading, and reference solutions while metadata cites the source page only as prior-art topic context.

### Pack Scaffold

- [ ] **PACK-01**: Candidate can list a new `dump-cooloo9871` pack whose `manifest.yaml` contains all 30 questions in stable source-derived order.
- [ ] **PACK-02**: Maintainer can run coverage lint and see every `dump-cooloo9871` question mapped in `coverage.yaml`.
- [ ] **PACK-03**: Candidate can read the pack README and understand scope, source-derived nature, v1.35 adaptations, and drill usage.
- [ ] **PACK-04**: Maintainer can inspect each `dump-cooloo9871` question directory and find the full runtime set: `question.md`, `metadata.yaml`, `setup.sh`, `grade.sh`, `reset.sh`, `ref-solution.sh`, and `expected-symptom.yaml`.

### Command And Inspection Exercises

- [ ] **CMD-01**: Candidate can complete a context/current-context exercise derived from source Q01.
- [ ] **CMD-02**: Candidate can complete a pod sorting command exercise derived from source Q05.
- [ ] **CMD-03**: Candidate can complete a node and pod resource usage command exercise derived from source Q07.
- [ ] **CMD-04**: Candidate can complete a control-plane component inspection exercise derived from source Q08.
- [ ] **CMD-05**: Candidate can complete a cluster node and version reporting exercise derived from source Q14.
- [ ] **CMD-06**: Candidate can complete a cluster events command exercise derived from source Q15.
- [ ] **CMD-07**: Candidate can complete a namespace and namespaced API resources exercise derived from source Q16.
- [ ] **CMD-08**: Candidate can complete a kube-apiserver certificate validity exercise derived from source Q22.
- [ ] **CMD-09**: Candidate can complete a kubelet certificate issuer and extended-key-usage exercise derived from source Q23.
- [ ] **CMD-10**: Candidate can complete an etcd certificate/key inspection exercise derived from preview Q01.

### Core Object Exercises

- [ ] **OBJ-01**: Candidate can complete a StatefulSet scale-down exercise derived from source Q03.
- [ ] **OBJ-02**: Candidate can complete a PV, PVC, and pod volume exercise derived from source Q06.
- [ ] **OBJ-03**: Candidate can complete a ServiceAccount, Role, and RoleBinding exercise derived from source Q10.
- [ ] **OBJ-04**: Candidate can complete a DaemonSet-on-all-nodes exercise derived from source Q11.
- [ ] **OBJ-05**: Candidate can complete a Deployment topology and scheduling exercise derived from source Q12.
- [ ] **OBJ-06**: Candidate can complete a multi-container pod with shared volume exercise derived from source Q13.
- [ ] **OBJ-07**: Candidate can complete a Secret creation and pod mount exercise derived from source Q19.
- [ ] **OBJ-08**: Candidate can complete a NetworkPolicy containment exercise derived from source Q24.
- [ ] **OBJ-09**: Candidate can complete a kube-proxy service traffic exercise derived from preview Q02.
- [ ] **OBJ-10**: Candidate can complete a pod/service IP output exercise derived from preview Q03.

### Operational Exercises

- [ ] **OPS-01**: Candidate can complete a control-plane scheduling exercise derived from source Q02 without relying on hard-coded node names.
- [ ] **OPS-02**: Candidate can complete a readiness-dependent-on-service-reachability exercise derived from source Q04.
- [ ] **OPS-03**: Candidate can complete a scheduler stop and manual pod binding exercise derived from source Q09 using reversible lab-safe setup and reset.
- [ ] **OPS-04**: Candidate can complete a pod container detail extraction exercise derived from source Q17.
- [ ] **OPS-05**: Candidate can complete a kubelet repair exercise derived from source Q18 using the existing lab SSH/topology assumptions.
- [ ] **OPS-06**: Candidate can complete a node upgrade/join adaptation exercise derived from source Q20 without requiring an extra real cluster.
- [ ] **OPS-07**: Candidate can complete a static pod plus service exercise derived from source Q21.
- [ ] **OPS-08**: Candidate can complete an etcd snapshot save/restore exercise derived from source Q25.
- [ ] **OPS-09**: Candidate can complete an eviction-priority analysis exercise derived from extra Q01.
- [ ] **OPS-10**: Candidate can complete a manual Kubernetes API access exercise from a pod using a ServiceAccount token, derived from extra Q02.

### Verification

- [ ] **VER-01**: Maintainer can verify every scored `dump-cooloo9871` grader gives empty submission 0 scored points.
- [ ] **VER-02**: Maintainer can verify every `dump-cooloo9871` reference solution reaches max score.
- [ ] **VER-03**: Maintainer can run pack, coverage, trap, trap-coverage, question-symptom, and unit lint gates successfully after the pack lands.
- [ ] **VER-04**: Maintainer can run live drill UAT for high-risk host/control-plane exercises and see setup, empty-submission, reference-solution, and reset behavior recorded.
- [ ] **VER-05**: Maintainer can inspect a v1.1 milestone audit that records requirement coverage, verification evidence, and any deferred limitations.

## Future Requirements

### Exam Blueprints

- **EXAM-01**: Candidate can take a timed blueprint that draws from `dump-cooloo9871`.

### Cross-Pack Analytics

- **ANALYTICS-01**: Candidate can compare performance between curated domain packs and the source-derived dump pack.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Copying source question prose or answers verbatim | Source repo exposes no visible license file; v1.1 uses source topics only. |
| Adding extra real clusters or contexts | Project runtime is a single learner cluster with existing kubeadm topology. |
| Replacing existing five domain packs | `dump-cooloo9871` is additive drill content. |
| New runtime language or new simulator CLI surface | Existing bash and pack contracts are sufficient. |
| CKAD/CKS content | Project scope remains CKA. |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SRC-01 | TBD | Pending |
| SRC-02 | TBD | Pending |
| SRC-03 | TBD | Pending |
| PACK-01 | TBD | Pending |
| PACK-02 | TBD | Pending |
| PACK-03 | TBD | Pending |
| PACK-04 | TBD | Pending |
| CMD-01 | TBD | Pending |
| CMD-02 | TBD | Pending |
| CMD-03 | TBD | Pending |
| CMD-04 | TBD | Pending |
| CMD-05 | TBD | Pending |
| CMD-06 | TBD | Pending |
| CMD-07 | TBD | Pending |
| CMD-08 | TBD | Pending |
| CMD-09 | TBD | Pending |
| CMD-10 | TBD | Pending |
| OBJ-01 | TBD | Pending |
| OBJ-02 | TBD | Pending |
| OBJ-03 | TBD | Pending |
| OBJ-04 | TBD | Pending |
| OBJ-05 | TBD | Pending |
| OBJ-06 | TBD | Pending |
| OBJ-07 | TBD | Pending |
| OBJ-08 | TBD | Pending |
| OBJ-09 | TBD | Pending |
| OBJ-10 | TBD | Pending |
| OPS-01 | TBD | Pending |
| OPS-02 | TBD | Pending |
| OPS-03 | TBD | Pending |
| OPS-04 | TBD | Pending |
| OPS-05 | TBD | Pending |
| OPS-06 | TBD | Pending |
| OPS-07 | TBD | Pending |
| OPS-08 | TBD | Pending |
| OPS-09 | TBD | Pending |
| OPS-10 | TBD | Pending |
| VER-01 | TBD | Pending |
| VER-02 | TBD | Pending |
| VER-03 | TBD | Pending |
| VER-04 | TBD | Pending |
| VER-05 | TBD | Pending |

**Coverage:**
- v1.1 requirements: 42 total
- Mapped to phases: 0
- Unmapped: 42

---
*Requirements defined: 2026-05-28*
*Last updated: 2026-05-28 after v1.1 requirements definition*

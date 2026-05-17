# Requirements: CKA Exam Simulator — v1.0.1 Full Audit Remediation

**Defined:** 2026-05-17
**Core Value:** A candidate can take a 2-hour timed mock exam against their own cluster and get an honest, trap-aware score telling them exactly which CKA domains and which classes of mistake they need to drill before sitting the real exam.

**Driven by:** `.planning/forensics/report-20260517-091657-full-audit.md` (15 question bugs surfaced across 5 packs).

## v1.0.1 Requirements

### High-Severity Question Bugs

Each is a candidate-blocking defect: question describes a K8s-impossible symptom, or grader contradicts the question, or correct answer fails the grader.

- [ ] **BUG-H01**: storage/01-pvc-binding — Candidate sees a question whose claimed symptom (PVC stuck `Pending`) matches what `setup.sh` actually produces; trap is observable to the candidate.
- [ ] **BUG-H02**: services-networking/05-kube-proxy-mode — Candidate (and ref-solution) submitting the correct kube-proxy mode passes the grader regardless of whether the live cluster runs `iptables`, `ipvs`, or `nftables`.
- [ ] **BUG-H03**: cluster-architecture/04-pss-enforce — Candidate following `question.md` literally (file edit, no `kubectl apply`) scores full marks; question and grader agree on what's tested.
- [ ] **BUG-H04**: cluster-architecture/08-priorityclass — Candidate who sets either `q08-critical` OR `q08-batch` as `globalDefault: true` (and the other as false) passes the grader; question wording matches grader behavior.
- [ ] **BUG-H05**: troubleshooting/04-debug-node — Grader can distinguish a genuine `kubectl debug node/<name>` invocation from a hand-rolled privileged pod carrying a forged debug-source label. Ref-solution uses the same path the candidate is expected to use.
- [ ] **BUG-H06**: troubleshooting/05-static-pod-manifest — Question framing matches grader scope. Either question is rescoped to "YAML repair + dry-run" OR grader verifies actual static-pod semantics (mirror pod present, Running).

### Medium-Severity Question Bugs

Lower severity but each is a candidate-confusing or grader-leaking defect.

- [ ] **BUG-M01**: storage/02-storageclass-dynamic — `metadata.yaml` lists only traps that have a `record_trap` call in `grade.sh`.
- [ ] **BUG-M02**: storage/03-access-modes-reclaim — `metadata.yaml` lists only traps that have a `record_trap` call in `grade.sh`.
- [ ] **BUG-M03**: storage/04-csi-volumesnapshot — `metadata.yaml` lists only traps that have a `record_trap` call in `grade.sh` (drop or implement `reclaim-policy-delete-data-loss`).
- [ ] **BUG-M04**: services-networking/06-netpol-endport — Grader proves port 8095 is excluded by NetworkPolicy (not by absence of listener); over-permissive NP fails. CNI enforcement is detected at setup time and grader gates accordingly.
- [ ] **BUG-M05**: cluster-architecture/05-audit-policy — Grader validates per-resource level mapping (Secrets→Metadata, ConfigMaps→Request, Events→None) and presence of `omitStages: [RequestReceived]`, not just structural shape.
- [ ] **BUG-M06**: workloads-scheduling/04-hpa-metrics-server — Grader validates `target.averageUtilization == 50` and `target.type == Utilization`, not just `metric.name == cpu`.
- [ ] **BUG-M07**: troubleshooting/02-netpol-dns-egress — `question.md` documents the kube-system namespace label conventions the candidate must rely on, OR ref-solution uses conventions the question already provides.
- [ ] **BUG-M08**: troubleshooting/03-coredns-resolution — `question.md` framing matches what `setup.sh` actually produces (CoreDNS deploy is unhealthy, not just misconfigured), OR setup is fixed so the deploy reaches Available and only DNS resolution fails.
- [ ] **BUG-M09**: troubleshooting/06-broken-kubelet — Grader `grep` for `container-runtime-endpoint` excludes comment lines (`^#` or inline `#`); candidate keeping clarifying comments is not penalized.

### Systemic / Library

- [ ] **LINT-01**: `scripts/lint-traps.sh` (or a new `scripts/lint-trap-coverage.sh`) fails CI if any `metadata.yaml` trap entry has no matching `cka_sim::grade::record_trap` call in the same question's `grade.sh`. Catches BUG-M01/M02/M03 today and prevents future drift.
- [ ] **CI-01**: A new CI step (`scripts/lint-question-symptom.sh` or similar) runs `setup.sh` against a kind/k3s cluster and diffs the resulting `kubectl get pvc,pv,pod,svc,deploy,...` state against a per-question `expected-symptom.yaml` — would have caught BUG-H01 and BUG-M08 at ship time.
- [ ] **LIB-01**: `cka-sim/lib/setup.sh:218` `kubernetes.io\metadata.name` typo fixed to `kubernetes.io/metadata.name` in `seed_netpol_skeleton`. All call sites pass shellcheck and lint-packs.

## Future Requirements

Carried from PROJECT.md v2.0 candidate ideas — not in v1.0.1 scope.

### Domain Coverage Gaps
- Domain coverage gap closure — file-baseline support for etcd snapshot, audit-policy YAML, node-level files
- Quality-of-life: aliases, kubectl-neat integration, time-tracking per question

## Out of Scope

| Feature | Reason |
|---------|--------|
| Re-running grader on every existing reference solution across all 34 questions | Out of scope for hotfix; covered by CI-01 once that infra lands |
| Migrating from `lint-packs.sh` bash linter to a unified Go/Python framework | Tech stack constraint (pure bash); deferred to v2.0+ |
| Adding more questions to fill audit-escape gaps in the Tracker | Different milestone — coverage expansion, not bug-fix |
| Re-rendering all `metadata.yaml` files from a shared trap taxonomy | Larger refactor; v1.0.1 trims orphans in-place to avoid churn |
| Reworking the 47-entry trap catalog itself | Catalog is correct; only the per-question metadata pointers drift |
| Real-cluster CI for full ref-solution UAT (kind/k3s + score=max round-trip on every question) | v2.0 scope per PROJECT.md; v1.0.1 ships only the symptom-diff step (CI-01) |

## Traceability

Empty initially. Populated by `gsd-roadmapper`.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUG-H01 | TBD | Pending |
| BUG-H02 | TBD | Pending |
| BUG-H03 | TBD | Pending |
| BUG-H04 | TBD | Pending |
| BUG-H05 | TBD | Pending |
| BUG-H06 | TBD | Pending |
| BUG-M01 | TBD | Pending |
| BUG-M02 | TBD | Pending |
| BUG-M03 | TBD | Pending |
| BUG-M04 | TBD | Pending |
| BUG-M05 | TBD | Pending |
| BUG-M06 | TBD | Pending |
| BUG-M07 | TBD | Pending |
| BUG-M08 | TBD | Pending |
| BUG-M09 | TBD | Pending |
| LINT-01 | TBD | Pending |
| CI-01 | TBD | Pending |
| LIB-01 | TBD | Pending |

**Coverage:**
- v1.0.1 requirements: 18 total
- Mapped to phases: 0 (pending roadmap)
- Unmapped: 18 ⚠ (resolved at roadmap step)

---
*Requirements defined: 2026-05-17*
*Last updated: 2026-05-17 at milestone v1.0.1 opening*

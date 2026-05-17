# Roadmap: CKA Certified Kubernetes Administrator

## Milestones

- ✅ **v1.0 CKA Exam Simulator MVP** — Phases 1-8 + 07.1 (shipped 2026-05-17)
- 🚧 **v1.0.1 Full Audit Remediation** — Phases 10-15 (in progress)
- 📋 **v2.0** — Not yet planned (`/gsd-new-milestone` to start)

## Phases

<details>
<summary>✅ v1.0 CKA Exam Simulator MVP (Phases 1-8 + 07.1) — SHIPPED 2026-05-17</summary>

- [x] Phase 1: Cluster Bootstrap + Runner Skeleton (2/2 plans) — bootstrap, doctor, SSH topology
- [x] Phase 2: Trap Framework + Assertion Library (5/5 plans) — grade.sh, traps.sh, catalog
- [x] Phase 3: Runtime Contract + Drill Mode (9/9 plans) — `cka-sim drill`, 5 reference questions
- [x] Phase 4: Storage + Workloads-Scheduling Packs (18/18 plans) — 14 questions across 2 packs
- [x] Phase 5: Services-Networking + Cluster-Architecture Packs (20/20 plans) — 14 questions across 2 packs
- [x] Phase 6: Troubleshooting Pack (9/9 plans) — 6 troubleshooting questions
- [x] Phase 7: Exam Mode + Blueprint Alpha + Reporting (7/7 plans) — `cka-sim exam`, timer, signals, reports
- [x] Phase 07.1: Grading Honesty Rebuild (INSERTED — URGENT) (13/13 plans) — empty submission = 0/100
- [x] Phase 8: Blueprint Bravo + Banners + Docs + CI (5/5 plans) — second exam, docs, shellcheck CI

Full archive: [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md)

</details>

### 🚧 v1.0.1 Full Audit Remediation (In Progress)

**Milestone Goal:** Fix all 15 question bugs (6 HIGH + 9 MED) surfaced by full pack audit `forensics/report-20260517-091657-full-audit.md`, plus add CI lints (LINT-01, CI-01) and library fix (LIB-01) to prevent recurrence. Drive every fix from per-bug evidence in the forensic report.

- [~] **Phase 10: HIGH Single-Question Edits** — Fix 4 HIGH bugs that are 1-2 file edits per question (no design rework needed) (Awaiting UAT — live-cluster drills required)
- [~] **Phase 11: HIGH Grader/Question Rework** — Fix 2 HIGH bugs requiring design decision (strengthen evidence vs loosen question; rescope vs expand grader) (Awaiting UAT — live-cluster drills required)
- [x] **Phase 12: Trap-Coverage Lint + Orphan Cleanup** — Land trap-coverage lint, then trim 3 orphan trap entries it flags
- [~] **Phase 13: Grader-Strengthening** — Add precise assertions to 3 graders that currently rubber-stamp structural shape (Awaiting UAT — live-cluster drills required)
- [ ] **Phase 14: Question Framing + Library Fixes** — Fix 3 candidate-confusing question framings + grep-comment-leak + library typo
- [ ] **Phase 15: Live-Cluster Symptom-Diff CI** — Build per-question expected-symptom YAMLs + CI step that runs `setup.sh` and diffs cluster state

### 📋 v2.0 (Not yet planned)

Use `/gsd-new-milestone` to scope and plan the next milestone.

## Phase Details

### Phase 10: HIGH Single-Question Edits
**Goal**: Candidate following each of 4 audit-flagged HIGH-severity questions literally scores max marks via ref-solution and the question+grader contract holds.
**Depends on**: Phase 8 (v1.0 shipped)
**Requirements**: BUG-H01, BUG-H02, BUG-H03, BUG-H04
**Success Criteria** (what must be TRUE):
  1. `cka-sim drill storage 01-pvc-binding` then candidate observes PVC actually Pending (matches `question.md` claim) and ref-solution scores 3/3.
  2. `cka-sim drill services-networking 05-kube-proxy-mode` ref-solution scores 3/3 on a cluster running kube-proxy in `ipvs` mode (i.e. seed token is no longer one of `{iptables, ipvs, nftables}`).
  3. `cka-sim drill cluster-architecture 04-pss-enforce` candidate doing only the file edit (no `kubectl apply`) scores 1/1 — or question.md is updated to mandate `kubectl apply` and ref-solution exercises that path.
  4. `cka-sim drill cluster-architecture 08-priorityclass` candidate flipping EITHER `q08-critical` OR `q08-batch` to `globalDefault: true` scores 2/2.
**Plans**: TBD

### Phase 11: HIGH Grader/Question Rework
**Goal**: Two HIGH-severity troubleshooting questions (04-debug-node, 05-static-pod-manifest) have a coherent question-grader-ref-solution triangle where the skill being tested matches the skill being graded.
**Depends on**: Phase 10
**Requirements**: BUG-H05, BUG-H06
**Success Criteria** (what must be TRUE):
  1. `troubleshooting/04-debug-node` grader rejects a hand-rolled privileged pod carrying only a forged `kubectl.kubernetes.io/debug-source` label (OR question is loosened to allow any privileged-pod approach and grades only `answer.txt`); ref-solution uses the same path the candidate is told to use.
  2. `troubleshooting/05-static-pod-manifest` question framing and grader scope agree: either question rewrites as "YAML repair + dry-run" exercise matching the existing `kubectl apply --dry-run=client` grader, OR grader verifies actual static-pod semantics (file under `/etc/kubernetes/manifests/`, mirror pod present, Running).
  3. Both questions' ref-solutions score max/max under the reworked grader and an empty submission scores 0.
**Plans**: TBD

### Phase 12: Trap-Coverage Lint + Orphan Cleanup
**Goal**: CI enforces that every trap declared in a question's `metadata.yaml` has a matching `cka_sim::grade::record_trap` call site in the same question's `grade.sh`, and the 3 known orphans are trimmed.
**Depends on**: Phase 11
**Requirements**: LINT-01, BUG-M01, BUG-M02, BUG-M03
**Success Criteria** (what must be TRUE):
  1. New script (`scripts/lint-trap-coverage.sh` or extension of `scripts/lint-traps.sh`) exits 0 on the full pack tree only when every `metadata.yaml` trap entry has a matching `record_trap` call in its sibling `grade.sh`.
  2. Lint added to existing CI job graph (alongside `lint-packs`, `lint-traps`, `lint-coverage`); fails the build when a regression metadata-orphan is introduced.
  3. `storage/02-storageclass-dynamic/metadata.yaml`, `storage/03-access-modes-reclaim/metadata.yaml`, `storage/04-csi-volumesnapshot/metadata.yaml` no longer declare traps without a `record_trap` call (orphans dropped OR detectors implemented).
  4. Running the new lint on HEAD passes cleanly across all 38 questions; running it against a synthetic regression (re-add one orphan) fails with a clear file:line citation.
**Plans**: TBD

### Phase 13: Grader-Strengthening
**Goal**: Three MED-severity graders that currently rubber-stamp structural shape now enforce the precise values the question demands.
**Depends on**: Phase 12
**Requirements**: BUG-M04, BUG-M05, BUG-M06
**Success Criteria** (what must be TRUE):
  1. `services-networking/06-netpol-endport` grader proves port 8095 is excluded by NetworkPolicy enforcement (not by absence of a listener); an over-permissive NP fails grading; setup detects whether the live CNI enforces NetworkPolicy and gates the assertion accordingly.
  2. `cluster-architecture/05-audit-policy` grader validates per-resource level mapping (Secrets→Metadata, ConfigMaps→Request, Events→None) AND presence of `omitStages: [RequestReceived]` — not just structural shape; an audit-policy.yaml that flips any of those mappings fails.
  3. `workloads-scheduling/04-hpa-metrics-server` grader asserts `spec.metrics[*].resource.target.type == Utilization` AND `target.averageUtilization == 50`; a candidate-submitted HPA with `averageUtilization: 80` fails grading.
  4. Ref-solutions for all three questions still score max/max under the strengthened graders.
**Plans**: TBD

### Phase 14: Question Framing + Library Fixes
**Goal**: Three candidate-confusing question framings reconcile with what setup actually produces (or what ref-solution actually relies on), one grader stops penalizing harmless candidate comments, and the `seed_netpol_skeleton` backslash typo is fixed.
**Depends on**: Phase 13
**Requirements**: BUG-M07, BUG-M08, BUG-M09, LIB-01
**Success Criteria** (what must be TRUE):
  1. `troubleshooting/02-netpol-dns-egress` question.md documents the kube-system namespace label conventions the candidate must rely on (OR ref-solution is rewritten to use only conventions question already provides) so the ref-solution path is reproducible from the question alone.
  2. `troubleshooting/03-coredns-resolution` question framing matches setup output: either question.md acknowledges CoreDNS deploy is unhealthy (not just misconfigured), OR `setup.sh` is fixed so the deploy reaches Available and only DNS resolution fails.
  3. `troubleshooting/06-broken-kubelet` grader `grep` for `container-runtime-endpoint` excludes lines starting with `#` and inline `# …`; a candidate-edited kubelet config with explanatory comments above/beside the flag scores full marks.
  4. `cka-sim/lib/setup.sh:218` contains `kubernetes.io/metadata.name` (forward slash); `seed_netpol_skeleton` callers pass `shellcheck` and `scripts/lint-packs.sh` cleanly; no remaining backslash variants found by repo-wide grep.
**Plans**: TBD

### Phase 15: Live-Cluster Symptom-Diff CI
**Goal**: A per-question `expected-symptom.yaml` plus a CI step that runs `setup.sh` against a live cluster and diffs the resulting `kubectl get pvc,pv,pod,svc,deploy,...` state against that expectation — the durable safety net that would have caught BUG-H01 and BUG-M08 at ship time.
**Depends on**: Phase 14
**Requirements**: CI-01
**Success Criteria** (what must be TRUE):
  1. Every question in all 5 domain packs ships an `expected-symptom.yaml` (or equivalent) describing the post-`setup.sh` cluster state the question text claims.
  2. New script (`scripts/lint-question-symptom.sh` or similar) runs `setup.sh` against a kind/k3s cluster, captures `kubectl get` output for the question's namespace(s), and diffs against `expected-symptom.yaml`; exits non-zero on divergence with a clear per-question report.
  3. Running the symptom-diff against current HEAD passes for all questions whose setup matches their question.md after Phases 10-14 fixes.
  4. A synthetic regression (e.g. revert the storage/01 fix from Phase 10) makes the symptom-diff fail at PR time with file:line evidence.
**Plans**: TBD

## Progress

**Execution Order:** Phases execute in numeric order: 10 → 11 → 12 → 13 → 14 → 15

| Phase                                              | Milestone | Plans | Status      | Completed   |
| -------------------------------------------------- | --------- | ----- | ----------- | ----------- |
| 1. Cluster Bootstrap + Runner Skeleton             | v1.0      | 2/2   | Complete    | 2026-05     |
| 2. Trap Framework + Assertion Library              | v1.0      | 5/5   | Complete    | 2026-05     |
| 3. Runtime Contract + Drill Mode                   | v1.0      | 9/9   | Complete    | 2026-05     |
| 4. Storage + Workloads-Scheduling Packs            | v1.0      | 18/18 | Complete    | 2026-05     |
| 5. Services-Networking + Cluster-Architecture      | v1.0      | 20/20 | Complete    | 2026-05     |
| 6. Troubleshooting Pack                            | v1.0      | 9/9   | Complete    | 2026-05-13  |
| 7. Exam Mode + Blueprint Alpha + Reporting         | v1.0      | 7/7   | Complete    | 2026-05-15  |
| 07.1. Grading Honesty Rebuild                      | v1.0      | 13/13 | Complete    | 2026-05-17  |
| 8. Blueprint Bravo + Banners + Docs + CI           | v1.0      | 5/5   | Complete    | 2026-05-14  |
| 10. HIGH Single-Question Edits                     | v1.0.1    | 0/TBD | Not started | -           |
| 11. HIGH Grader/Question Rework                    | v1.0.1    | 2/2   | Awaiting UAT | -           |
| 12. Trap-Coverage Lint + Orphan Cleanup            | v1.0.1    | 5/5   | Complete    | 2026-05-17  |
| 13. Grader-Strengthening                           | v1.0.1    | 3/3   | Awaiting UAT | -           |
| 14. Question Framing + Library Fixes               | v1.0.1    | 0/TBD | Not started | -           |
| 15. Live-Cluster Symptom-Diff CI                   | v1.0.1    | 0/TBD | Not started | -           |

# Roadmap — Milestone v1.0 CKA Exam Simulator MVP

**Milestone:** v1.0
**Created:** 2026-05-07
**Phases:** 8
**Requirements covered:** 48 / 48 (100%)

---

## Phase 1: Cluster Bootstrap + Runner Skeleton

**Goal:** The candidate can run `cka-sim bootstrap` on their control-plane node and end up with a working simulator skeleton — SSH to `node-01`/`node-02` works passwordless, environment is set up, and `cka-sim doctor` reports green against the 1+2 cluster.

**Requirements:** BOOT-01, BOOT-02, BOOT-03, BOOT-04, BOOT-05, BOOT-06, BOOT-07, RUN-01

**Success criteria:**
1. After running `cka-sim bootstrap` on a fresh control-plane, `ssh -o BatchMode=yes node-01 hostname` returns the node hostname without any prompt
2. Running `cka-sim bootstrap` a second time produces no duplicates (no extra `Host node-*` blocks, no duplicated env exports)
3. `cka-sim doctor` exits 0 on a healthy 1+2 cluster; exits non-zero with a clear error when `kubectl get nodes` shows <3 nodes or any worker is unreachable via SSH
4. `cka-sim --help`, `cka-sim doctor`, `cka-sim list`, `cka-sim version` all dispatch correctly from a single entry-point script

**Depends on:** Nothing (foundation phase).

---

## Phase 2: Trap Framework + Assertion Library

**Goal:** Ship the shared trap-detection library (`lib/traps.sh`), the assertion helpers (`lib/grade.sh`), and the trap catalog seeded with the 8 CONCERNS.md-derived content-bug traps — so every grader from phase 3 onward can compose assertions and emit trap IDs without reinventing the wheel.

**Requirements:** GRADE-01, GRADE-05, TRIP-07

**Success criteria:**
1. `lib/traps.sh` exports at least 8 functions (one per seeded trap), each returning a stable trap ID string on detection and empty string otherwise
2. `lib/grade.sh` exports at least 7 assertion helpers (`assert_resource_exists`, `assert_field_eq`, `assert_pod_ready`, `assert_pvc_bound`, `assert_can_i`, `assert_egress_allowed`, `assert_endpoints_nonempty`) and a `emit_result` finalizer
3. `traps/catalog.yaml` has entries for all 8 seeded traps with `id`, `name`, `description`, `remediation_hint`, `references`, and passes a schema lint
4. Unit tests (`tests/`) execute a known-bad fixture and confirm each seeded trap detector fires correctly
5. All trap IDs, assertion helper names, and catalog keys conform to the RFC 1123 naming rule (TRIP-07)

**Depends on:** Phase 1 (runner skeleton and `cka-sim` dispatch must exist to run the test harness).

**Plans:** 5 plans

Plans:
- [x] 02-01-PLAN.md — Library scaffold: `lib/grade.sh` (7 assertion helpers + record_trap + emit_result + 5 accumulator globals) and `lib/traps.sh` (catalog parser scaffolding + RFC 1123 validator)
- [x] 02-02-PLAN.md — Catalog + 8 detectors: `traps/catalog.yaml` seeded with all 8 GRADE-05 entries (D-13/D-14 schema), 8 `detect_<id>` functions appended to `lib/traps.sh`
- [x] 02-03-PLAN.md — Test harness skeleton: PATH-shadowed `kubectl` stub, `expect_*` helpers, `tests/run.sh`, `scripts/test.sh` orchestrator, `scripts/lint-traps.sh` (D-15 schema/naming/path/seed lint), `.gitattributes` extension
- [x] 02-04-PLAN.md — Fixtures + cases: 22 fixture files (9 detector hit/miss/benign + 13 helper pass/fail) + 15 test cases (8 `traps_*` + 7 `grade_*`); end-to-end `test.sh` runs green with all 15 cases passing
- [x] 02-05-PLAN.md — CI integration: extend `.github/workflows/validate.yml` `paths:` filter (`cka-sim/**`, `**.sh`) and add `bash-tests` job invoking `cka-sim/scripts/test.sh`

---

## Phase 3: Runtime Contract + Drill Mode

**Goal:** Close the end-to-end single-question loop: `cka-sim drill <pack>` picks a question, runs `reset.sh` → `setup.sh` → prompt → `grade.sh` → trap emission → report, against a clean lab namespace. Ship one reference question per domain (5 total) that proves the contract on real content.

**Requirements:** TRIP-01, TRIP-02, TRIP-03, TRIP-04, TRIP-05, TRIP-06, GRADE-02, GRADE-03, GRADE-04, GRADE-06, RUN-02

**Success criteria:**
1. Running `cka-sim drill storage` with no prior state creates `cka-sim-storage-01` namespace, presents `question.md`, and on completion emits `SCORE: N/M` and at least 1 `Trap N:` line when graded against a wrong solution
2. Running `cka-sim drill storage` twice in a row never produces `AlreadyExists` errors (TRIP-02 idempotency verified)
3. All 5 reference questions (one per CKA domain) round-trip correctly: setup + grade emits FAIL with ≥1 trap; setup + reference-solution + grade emits PASS (GRADE-06)
4. Authoring template for the triplet is documented and lives under `cka-sim/AUTHORING.md` (even partially — the full doc lands in phase 8)
5. CI lint fails any `grade.sh` containing `kubectl get | grep` or `kubectl get -A` (GRADE-02 enforcement)

**Depends on:** Phase 2 (traps + assertions), Phase 1 (runner dispatch).

---

## Phase 4: Storage + Workloads-Scheduling Packs

**Goal:** Complete the two smaller-weight domain packs (Storage 10%, Workloads & Scheduling 15%). These are picked first because they are smaller and let us exercise the content-authoring process before tackling the large Troubleshooting domain.

**Requirements:** PACK-01, PACK-02, PACK-06 (Storage + Workloads subset), PACK-07 (Storage + Workloads subset)

**Success criteria:**
1. `packs/storage/` contains at least one question per Study Progress Tracker checkbox in the Storage domain, including a CSI/VolumeSnapshot question and a WaitForFirstConsumer question
2. `packs/workloads-scheduling/` contains at least one question per Tracker checkbox in the Workloads domain, including a native-sidecar question and a metrics-server bootstrap question (HPA prereq)
3. Every question under both packs has `metadata.yaml` with `id`, `domain`, `estimatedMinutes ∈ [4, 12]`, `verified_against: "1.35"`, `traps: []` (≥3 IDs), `references: []`
4. Every trap ID referenced in any question exists in `traps/catalog.yaml`
5. `cka-sim drill storage` and `cka-sim drill workloads-scheduling` can run every question in those packs without error

**Depends on:** Phase 3 (runtime contract and drill mode must work).

**Plans:** 16 plans

Plans:
- [x] 04-01-PLAN.md — Shared setup helper library (`cka-sim/lib/setup.sh`) + 4 unit test cases (Wave 1)
- [x] 04-02-PLAN.md — Trap catalog extension (6 new entries) + 18 fixture files (Wave 1)
- [x] 04-03-PLAN.md — Per-pack `coverage.yaml` + `scripts/lint-coverage.sh` + 2 unit test cases (Wave 1)
- [x] 04-04-PLAN.md — Retrofit `storage/01-pvc-binding` to source `lib/setup.sh` (Wave 2)
- [x] 04-05-PLAN.md — Retrofit `workloads-scheduling/01-deployment-requests` to source `lib/setup.sh` (Wave 2)
- [x] 04-06-PLAN.md — Storage Q02 `02-storageclass-dynamic` (Wave 3)
- [x] 04-07-PLAN.md — Storage Q03 `03-access-modes-reclaim` (Wave 3)
- [x] 04-08-PLAN.md — Storage Q04 `04-csi-volumesnapshot` with hostpath-csi install (Wave 3)
- [x] 04-09-PLAN.md — Storage Q05 `05-wait-for-first-consumer` (Wave 3)
- [x] 04-10-PLAN.md — Storage Q06 `06-pvc-mount-pod` (Wave 3)
- [x] 04-11-PLAN.md — Workloads Q02 `02-rolling-update-rollback` (Wave 3)
- [x] 04-12-PLAN.md — Workloads Q03 `03-configmap-secret-env-volume` (Wave 3)
- [x] 04-13-PLAN.md — Workloads Q04 `04-hpa-metrics-server` with metrics-server install (Wave 3)
- [x] 04-14-PLAN.md — Workloads Q05 `05-daemonset` (Wave 3)
- [x] 04-15-PLAN.md — Workloads Q06+Q07+Q08 (`static-pod`, `native-sidecar`, `nodeselector-affinity-taints`) (Wave 3)
- [x] 04-16-PLAN.md — Final integration: pack manifests + `test.sh` chain + `validate-local.sh` coverage lint wiring (Wave 4)

---

## Phase 5: Services-Networking + Cluster-Architecture Packs

**Goal:** Complete the two mid-weight domain packs (Services & Networking 20%, Cluster Architecture 25%). Includes the questions that replace the CONCERNS.md-flagged content bugs (PSS replacement with correct error wording, CRI-dockerd with correct endpoint flag).

**Requirements:** PACK-03, PACK-04, PACK-06 (Networking + Cluster-Arch subset), PACK-07 (Networking + Cluster-Arch subset), CI-02 (initial: deprecated-strings lint lands in Phase 5; Phase 8 finalizes CI wiring)

**Success criteria:**
1. `packs/services-networking/` includes a kube-proxy mode inspection question and a NetworkPolicy `endPort` question, plus coverage of the remaining Networking Tracker checkboxes
2. `packs/cluster-architecture/` includes the PSS replacement question using the correct v1.25+ error wording (`violates PodSecurity "<level>:<version>"`), an audit-policy question, a CRI-dockerd endpoint question editing `/var/lib/kubelet/kubeadm-flags.env` (never `/etc/kubernetes/kubelet.conf`), and a CRD basics question
3. Every question in both packs meets the PACK-06 front-matter schema and PACK-07 coverage mapping
4. CI deprecated-strings lint fails any content containing `PodSecurityPolicy`, `--container-runtime=remote`, `policy/v1beta1`, `gitRepo:`, or `dockershim` as Kubernetes API strings (comment references outside manifest blocks are allowed)

**Depends on:** Phase 4 (authoring workflow proven on the smaller packs first).

**Plans:** 16 plans

Plans:
**Wave 1**
- [ ] 05-01-PLAN.md -- Library extensions + catalog + lint-packs pass F + lint-deprecated-strings.sh (Wave 1)
- [ ] 05-02-PLAN.md -- Services-Networking retrofit + pack shell (manifest/coverage/README) (Wave 1)
- [ ] 05-08-PLAN.md -- Cluster-Architecture retrofit + pack shell (Wave 1)

**Wave 2** *(blocked on Wave 1 completion)*
- [ ] 05-03-PLAN.md -- S&N Q02 02-service-core (Wave 2)
- [ ] 05-04-PLAN.md -- S&N Q03 03-coredns-resolution (Wave 2)
- [ ] 05-05-PLAN.md -- S&N Q04 04-ingress-path-host (Wave 2)
- [ ] 05-06-PLAN.md -- S&N Q05 05-kube-proxy-mode (Wave 2)
- [ ] 05-07-PLAN.md -- S&N Q06 06-netpol-endport (Wave 2)
- [ ] 05-09-PLAN.md -- Cluster-Arch Q02 02-etcd-backup-restore (Wave 2)
- [ ] 05-10-PLAN.md -- Cluster-Arch Q03 03-kubeadm-upgrade (Wave 2)
- [ ] 05-11-PLAN.md -- Cluster-Arch Q04 04-pss-enforce (Wave 2)
- [ ] 05-12-PLAN.md -- Cluster-Arch Q05 05-audit-policy (Wave 2)
- [ ] 05-13-PLAN.md -- Cluster-Arch Q06 06-crd-basics (Wave 2)
- [ ] 05-14-PLAN.md -- Cluster-Arch Q07 07-cri-dockerd-endpoint (Wave 2)
- [ ] 05-15-PLAN.md -- Cluster-Arch Q08 08-priorityclass (Wave 2)

**Wave 3** *(blocked on Wave 2 completion)*
- [ ] 05-16-PLAN.md -- Phase 5 VERIFICATION.md (Wave 3)

---

## Phase 6: Troubleshooting Pack

**Goal:** Complete the largest-weight domain pack (Troubleshooting 30%). Cross-references questions in the other four packs as teaching material. Closes out PACK-07's 100% coverage-matrix requirement.

**Requirements:** PACK-05, PACK-06 (Troubleshooting subset), PACK-07 (final 100% coverage)

**Success criteria:**
1. `packs/troubleshooting/` contains at least one question each for CoreDNS, `kubectl debug node`, NetworkPolicy troubleshooting, and broken kubelet / static-pod scenarios
2. Coverage-matrix lint reports 100% — every Study Progress Tracker checkbox in the v1.35 syllabus maps to at least one question in a pack
3. Each troubleshooting question references at least one other pack's question via `metadata.yaml.references[]` as related prior-art context
4. `cka-sim drill troubleshooting` runs every question in the pack without error
5. Every trap ID referenced is registered in `traps/catalog.yaml` (catalog grows with domain-specific traps but no orphans)

**Depends on:** Phase 5 (references into other packs require those packs to exist first).

**Plans:** 9 plans

Plans:
**Wave 1**
- [x] 06-01-PLAN.md — lint-packs.sh forbidden-command guard (pass G) + 3 negative fixture families + 1 test case (Wave 1)
- [x] 06-02-PLAN.md — traps/catalog.yaml +11 entries for Phase 6 question metadata (Wave 1)
- [x] 06-03-PLAN.md — Q01 `01-deploy-svc-mismatch` retrofit: lib/setup.sh sourcing + web-canary ImagePullBackOff trap (Wave 1)

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 06-04-PLAN.md — Q02 `02-netpol-dns-egress` (label-key drift + DNS egress missing; two-stage fix) (Wave 2)
- [x] 06-05-PLAN.md — Q03 `03-coredns-resolution` (lab-ns CoreDNS; forward upstream + Corefile mount subPath key-case fix) (Wave 2)
- [x] 06-06-PLAN.md — Q04 `04-debug-node` (Node-API oracle; sandbox answer.txt; debug-pod leak sweep in reset) (Wave 2)
- [x] 06-07-PLAN.md — Q05 `05-static-pod-manifest` (two broken manifest variants; python3 yaml.safe_load + kubectl dry-run oracle; sandbox only) (Wave 2)
- [x] 06-08-PLAN.md — Q06 `06-broken-kubelet` (4 encoded defects in sandbox kubeadm-flags.env; subshell source check) (Wave 2)

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 06-09-PLAN.md — Pack finalization (manifest + coverage + README) + 06-VERIFICATION.md + live 6-drill human checkpoint (Wave 3)

---

## Phase 7: Exam Mode + Blueprint Alpha + Reporting

**Goal:** Ship the Core Value experience. `cka-sim exam blueprint-alpha` runs a 2-hour 17-question mock end-to-end against the candidate's cluster with flag/skip/pause/resume, then renders a Markdown score report with per-domain breakdown and trap frequencies.

**Requirements:** RUN-03, RUN-04, RUN-05, RUN-06, MOCK-01, MOCK-03, REPORT-01, REPORT-02

**Success criteria:**
1. `cka-sim exam blueprint-alpha` displays a visible countdown timer that updates every second without blocking input; the timer survives Ctrl-Z pause and `cka-sim exam --resume <ts>` rehydration
2. During an exam, Ctrl-C flags the current question and persists state (does NOT kill the exam); Ctrl-Z pauses; normal exit and `kill` both persist via the EXIT trap
3. `exams/blueprint-alpha/manifest.yaml` composes exactly 17 questions by `pack/slug` reference (no duplicated question content), weighted 10/30/15/25/20 to the v1.35 CKA blueprint, with `estimatedMinutes` summing to 110–120
4. At exam end, a Markdown report lands at `~/.cka-sim/sessions/<ts>.md` containing total score / 100, pass/fail vs 66%, per-domain percentage table sorted lowest first, top-5 trap frequencies, and a "Suggested next drills" section
5. `cka-sim score <ts>` re-displays the report; `cka-sim list history` enumerates all completed sessions
6. Blueprint-alpha's README has the mandatory "Not real CKA exam content; independently authored" disclaimer

**Depends on:** Phase 6 (all 5 packs must exist before a 17-question blueprint can reference them).

**Plans:** 7 plans

Plans:
- [x] 07-01-PLAN.md — Foundation: exam-state.sh + exam-blueprint.sh + Wave-0 test fixtures + 4 unit tests
- [x] 07-02-PLAN.md — exam-report.sh Markdown score report renderer + golden-file test
- [x] 07-03-PLAN.md — Full exam orchestrator (lib/cmd/exam.sh) + exam-timer.sh: question loop, signal handling, batch grading, --resume
- [x] 07-04-PLAN.md — cka-sim score + list history subcommands
- [x] 07-05-PLAN.md — blueprint-alpha exam content: manifest.yaml (17 questions) + README
- [x] 07-06-PLAN.md — lint-packs.sh pass H: blueprint manifest validation + test fixtures
- [x] 07-07-PLAN.md — Gap closure: harden exam signal handling (restartable read, re-entrant-safe TSTP/CONT, stty hygiene, interrupt-contained setup)

---

### Phase 07.1: Grading Honesty Rebuild (INSERTED — URGENT)

**Goal:** Make graders score candidate work, not setup state. Empty exam submissions must score 0/100 across all 17 blueprint-alpha questions; currently they score 10/100 (7 raw points) because `grade.sh` checks absolute end-state that `setup.sh` already satisfies.

**Spec input:** `.planning/phases/07-exam-mode-blueprint-alpha-reporting/07-UAT.md` (Test 12 Gaps section — full per-question artifact list + missing-pieces inventory).

**Requirements (derived from Test 12 diagnosis):**
1. **Baselining primitives** in `cka-sim/lib/grade.sh`: capture post-setup snapshot (generation, labels, resource list, hash); expose delta helpers (`assert_changed_since_setup`, `assert_generation_delta_ge N`, `assert_resource_candidate_authored`).
2. **Per-question fixes** — confirmed offenders:
   - `workloads-scheduling/02-rolling-update-rollback` (4/4 free): grader checks `generation >= 3` but `setup.sh` already bumps generation to >=3.
   - `storage/02-storageclass-dynamic` (1/3 free): grader asserts `pvc.spec.storageClassName == fast-ssd` but setup writes that field verbatim.
   - `services-networking/06-netpol-endport` (1/6 free): reachability assertion passes via default-allow with no candidate NetworkPolicy.
   - `cluster-architecture/04-pss-enforce` (1/5 free): setup-created ns label or admission log matches one assertion.
3. **Full audit** of remaining 13 questions: run empty-submission test on each, classify every passing assertion (setup-collision / default-allow / trap-on-setup), fix.
4. **Trap-detector ownership check** in `cka-sim/lib/traps.sh`: detector must confirm the resource was modified after `setup.sh` completed before recording the trap (e.g., Q3 `default-sa-used` currently fires on setup's Deployment).
5. **CI regression**: per-question "empty submission scores 0" test in `cka-sim/scripts/test.sh` (or a new `lint-grading-honesty.sh`); runs in `.github/workflows/validate.yml`.
6. **README caveat removal**: once rebuild lands and CI passes, remove the scoring-honesty caveat the Phase 7 ship added.

**Success criteria:**
1. Empty exam submission of `blueprint-alpha` scores 0/100, 0 raw points, 0 traps across all 17 questions on a live cluster.
2. CI gate fails the build if any question's empty-submission score is non-zero.
3. Reference-solution round-trip still passes for every question (fixes do not regress the happy path).
4. Documentation: `cka-sim/AUTHORING.md` (or new `GRADING-HONESTY.md`) documents the baselining contract authors must follow.

**Depends on:** Phase 7 (signal-handling fixes in 07-07 must remain green).
**Plans:** 13 plans

Plans:
- [x] 07.1-01-PLAN.md -- TDD: lib/baseline.sh + 3 grade helpers + catalog ownership schema (Wave 1)
- [x] 07.1-02-PLAN.md -- TDD: traps.sh ownership refactor + drill.sh/exam.sh baseline hooks (Wave 2)
- [x] 07.1-03-PLAN.md -- Fix: workloads-scheduling/02 generation-delta assertion (Wave 3)
- [x] 07.1-04-PLAN.md -- Fix: storage/02 candidate-authored StorageClass (Wave 3)
- [x] 07.1-05-PLAN.md -- Fix: services-networking/06 NP authorship gate (Wave 3)
- [x] 07.1-06-PLAN.md -- Fix: cluster-architecture/04 audit-escape + candidate Pod (Wave 3)
- [x] 07.1-07-PLAN.md -- CI: kubectl stub extension + 4 offender test cases (Wave 4)
- [x] 07.1-08-PLAN.md -- Audit: storage pack (5 Qs) + fixtures + tests (Wave 5)
- [x] 07.1-09-PLAN.md -- Audit: workloads-scheduling pack (7 Qs) + fixtures + tests (Wave 5)
- [x] 07.1-10-PLAN.md -- Audit: services-networking pack (5 Qs) + fixtures + tests (Wave 5)
- [x] 07.1-11-PLAN.md -- Audit: cluster-architecture pack (7 Qs) + fixtures + tests (Wave 5)
- [x] 07.1-12-PLAN.md -- Audit: troubleshooting pack (6 Qs) + fixtures + tests (Wave 5)
- [x] 07.1-13-PLAN.md -- Docs: GRADING-HONESTY.md + README caveat removal + VERIFICATION.md (Wave 6)

## Phase 8: Blueprint Bravo + Banners + Docs + CI

**Goal:** Ship the second mock-exam pack so the candidate can retake without repetition, add the superseded-content banners, deliver full documentation (README/AUTHORING/SCHEMA/CONTRIBUTING), and wire the CI extension that gates all the invariants the earlier phases established.

**Requirements:** MOCK-02, BANNER-01, BANNER-02, DOC-01, DOC-02, DOC-03, DOC-04, CI-01, CI-02, CI-03

**Success criteria:**
1. `exams/blueprint-bravo/manifest.yaml` composes a different 17-question draw (zero slug overlap with blueprint-alpha where possible, ≤30% overlap otherwise), same weighting and time budget, same disclaimer
2. `exercises/README.md`, `mock-exams/README.md`, and the root `README.md` each carry a 6-line banner block at the top pointing at `cka-sim/`; no existing content below those banners is modified
3. `cka-sim/README.md` documents the quickstart (`bootstrap` → `doctor` → `drill` → `exam`); `cka-sim/AUTHORING.md` documents the triplet template + trap-registration flow; `cka-sim/SCHEMA.md` gives YAML schemas for `metadata.yaml`, pack `manifest.yaml`, exam `manifest.yaml`, and `traps/catalog.yaml`; `CONTRIBUTING.md` gains an "Authoring exam-sim questions" section
4. `scripts/validate-local.sh` walks `cka-sim/**/*.yaml` with yamllint and `cka-sim/**/*.sh` with shellcheck
5. `.github/workflows/validate.yml` extends `paths:` to include `cka-sim/**`, adds a shellcheck job, and enforces the deprecated-strings lint
6. Pack lint (in CI) fails PRs with any of: `kubectl get | grep`, `kubectl get -A`, missing `verified_against: 1.35`, fewer than 3 traps per question, unregistered trap IDs, cluster-scoped-name collisions inside a pack, RFC 1123 violations in resource names

**Depends on:** Phase 7 (exam mode must work before the second blueprint is meaningful; docs assume all prior phases landed).

**Plans:** 5 plans

Plans:
- [x] 08-01-PLAN.md — Blueprint Bravo manifest + README (Wave 1)
- [x] 08-02-PLAN.md — Superseded-content banners (Wave 1)
- [x] 08-03-PLAN.md — Full documentation: README, AUTHORING, SCHEMA, CONTRIBUTING (Wave 2)
- [x] 08-04-PLAN.md — validate-local.sh + CI shellcheck job (Wave 3)
- [x] 08-05-PLAN.md — Phase verification (Wave 3)

---

## Requirement Traceability (all 48 REQ-IDs)

| REQ-ID | Phase | REQ-ID | Phase |
|--------|-------|--------|-------|
| BOOT-01 | 1 | PACK-01 | 4 |
| BOOT-02 | 1 | PACK-02 | 4 |
| BOOT-03 | 1 | PACK-03 | 5 |
| BOOT-04 | 1 | PACK-04 | 5 |
| BOOT-05 | 1 | PACK-05 | 6 |
| BOOT-06 | 1 | PACK-06 | 4, 5, 6 (split) |
| BOOT-07 | 1 | PACK-07 | 4, 5, 6 (split) |
| RUN-01 | 1 | MOCK-01 | 7 |
| RUN-02 | 3 | MOCK-02 | 8 |
| RUN-03 | 7 | MOCK-03 | 7 |
| RUN-04 | 7 | REPORT-01 | 7 |
| RUN-05 | 7 | REPORT-02 | 7 |
| RUN-06 | 7 | BANNER-01 | 8 |
| TRIP-01 | 3 | BANNER-02 | 8 |
| TRIP-02 | 3 | DOC-01 | 8 |
| TRIP-03 | 3 | DOC-02 | 8 |
| TRIP-04 | 3 | DOC-03 | 8 |
| TRIP-05 | 3 | DOC-04 | 8 |
| TRIP-06 | 3 | CI-01 | 8 |
| TRIP-07 | 2 | CI-02 | 5, 8 (split) |
| GRADE-01 | 2 | CI-03 | 8 |
| GRADE-02 | 3 |  |  |
| GRADE-03 | 3 |  |  |
| GRADE-04 | 3 |  |  |
| GRADE-05 | 2 |  |  |
| GRADE-06 | 3 |  |  |

**Coverage:** 48/48 REQ-IDs mapped to exactly one phase (with PACK-06 and PACK-07 split across phases 4/5/6 because the pack set grows progressively — each phase delivers its subset).

---

*Roadmap for milestone v1.0 — 2026-05-07*

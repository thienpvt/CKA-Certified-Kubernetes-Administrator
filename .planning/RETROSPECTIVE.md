# Project Retrospective

Living document of milestone lessons learned. Each new milestone appends a section above the "Cross-Milestone Trends" section.

## Milestone: v1.0 — CKA Exam Simulator MVP

**Shipped:** 2026-05-17
**Phases:** 9 (1-8 + 07.1) | **Plans:** 88 | **SUMMARYs:** 89 | **Commits:** 501 | **Duration:** ~11.5 months (2025-06-04 → 2026-05-17)

### What Was Built
- Bash-only CKA exam simulator running on live 1+2 kubeadm cluster
- 38 questions across 5 domain packs (Storage, W&S, S&N, CA, Troubleshooting)
- 2 mock exam blueprints (alpha, bravo) — 17 questions / 130 min each
- Trap-aware grading framework — 47 catalog entries, ownership-gated detectors
- CLI subcommands: `bootstrap`, `doctor`, `drill`, `exam`, `score`, `list`
- CI: shellcheck, lint-packs (298 checks), lint-traps, test.sh (78 cases)
- Documentation: README, AUTHORING, SCHEMA, CONTRIBUTING, GRADING-HONESTY

### What Worked
- **Per-question runtime triplet (`setup.sh` / `grade.sh` / `reset.sh`)** held across all 38 questions — clean separation, easy to test in isolation.
- **Trap catalog as authoritative source** — 47 entries with RFC 1123 IDs, lint-enforced, prevented graders from inventing one-off trap names.
- **Cherry-pick recovery from missing merge commits** — when Wave 3/5 merges silently disappeared, cherry-picking individual plan commits restored 20 commits cleanly.
- **Live cluster UAT round-trip pattern** (reset → setup → baseline → empty grade → ref-solution → grade) caught real issues that CI fixtures missed.
- **Decimal phase insertion (07.1)** — kept original 8-phase plan intact while urgent grading-honesty work proceeded without renumbering.

### What Was Inefficient
- **Wave 3 and Wave 5 merge commits disappeared** between user sessions — the worktree branches were deleted before merges were verified in git log. Cost ~6 hours of debugging during 07.1 UAT to realize the implementation was missing.
- **CI fixture data drift** — 5+ test fixtures captured against old graders became stale once graders were rewritten. Pattern: capture fixtures AFTER finalizing grader logic, not during iteration.
- **`assert_changed_since_setup` shipped with rv-fallback bug** — passed CI tests because fixtures simulated clean rv comparisons, failed on live cluster where controllers update status. Lesson: rv-based equality is unreliable; use generation-first comparison.
- **11 SUMMARY.md files missing at milestone close** — atomic feat commits skipped SUMMARYs for Phase 07 plans 01-06 and Phase 08 plans 01-05. Backfilled from commit messages.

### Patterns Established
- **Honest scoring contract**: setup-state assertions get `weight=0`; only candidate-modified or candidate-authored state scores points.
- **Baseline capture**: runner exports `CKA_SIM_QUESTION_ID` + `CKA_SIM_BASELINE_PATH`, calls `cka_sim::baseline::capture` between setup and grade.
- **Generation-first authority**: when both baseline and current have `metadata.generation`, compare generation only; rv-fallback only when generation absent.
- **Kind normalization helper**: kubectl short names (`pv`, `svc`, `sa`) normalize to canonical singular (`persistentvolume`, `service`, `serviceaccount`) before baseline lookup.
- **Topology-independent assertions**: prefer comparing controller-computed status fields (DS `numberReady` vs `desiredNumberScheduled`) over external counts (`kubectl get nodes | wc -l`).

### Key Lessons
- **Verify git state before declaring "done"**: orchestrator merge-output success doesn't mean commits are reachable from HEAD. Always `git log --oneline -5` post-merge.
- **CI tests with fixture stubs can mask live-cluster bugs**: when grading logic depends on cluster state, the only authoritative validation is round-trip on a real cluster.
- **Status-vs-spec distinction matters for change detection**: rv increments on any field change (status, annotations); generation only increments on `.spec` changes.
- **Reset.sh label-gated deletion** caused stale resources to persist across runs; for cluster-scoped resources with generic names, unconditional cleanup is safer than label-gated cleanup.
- **The Phase 7→07.1 gap was a real bug, not a hypothesis**: original graders scored 10/100 on empty submission. Catching this required actually running the exam on a live cluster — automated test suites couldn't reveal it.

### Cost Observations
- Model mix: predominantly Opus 4.7 for orchestration + plan execution
- Sessions: ~30-40 across the milestone
- Notable: Phase 07.1 alone consumed ~6 sessions due to repeated UAT iteration cycles, partly due to missing baseline-mechanism rigor in initial design

## Cross-Milestone Trends

_(populated after v1.1 ships)_

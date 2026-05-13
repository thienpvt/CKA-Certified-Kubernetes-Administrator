---
phase: 7
slug: exam-mode-blueprint-alpha-reporting
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-13
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash unit harness (cka-sim/tests/run.sh + PATH-shadowed kubectl/jq stubs) |
| **Config file** | none — established in Phases 2-3 |
| **Quick run command** | `bash cka-sim/tests/run.sh` |
| **Full suite command** | `bash cka-sim/scripts/test.sh` (lint-traps + lint-packs + lint-coverage + lint-deprecated-strings + tests/run.sh) |
| **Estimated runtime** | ~30-45 seconds (bash unit cases, no live cluster) |

---

## Sampling Rate

- **After every task commit:** Run `bash cka-sim/tests/run.sh`
- **After every plan wave:** Run `bash cka-sim/scripts/test.sh`
- **Before `/gsd-verify-work`:** Full suite green + golden-file report test passes
- **Max feedback latency:** 45 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 07-NN-01 | exam-state | 1 | RUN-05 | — | atomic JSON write — never overwrites with partial content on Ctrl-C | unit | `bash cka-sim/tests/exam/state_atomic_write.sh` | ❌ W0 | ⬜ pending |
| 07-NN-02 | exam-state | 1 | RUN-05 | — | jq -e fails fast on schema mismatch | unit | `bash cka-sim/tests/exam/state_schema.sh` | ❌ W0 | ⬜ pending |
| 07-NN-03 | exam-blueprint | 1 | MOCK-01 | — | manifest parser populates 17 question entries from blueprint manifest | unit | `bash cka-sim/tests/exam/blueprint_load.sh` | ❌ W0 | ⬜ pending |
| 07-NN-04 | exam-blueprint | 1 | MOCK-01 | — | validate() rejects manifests with !=17 questions, missing weights, duplicate slugs | unit | `bash cka-sim/tests/exam/blueprint_validate.sh` | ❌ W0 | ⬜ pending |
| 07-NN-05 | exam-report | 2 | REPORT-01 | — | render() of fixture session.json byte-equals expected-report.md | golden | `bash cka-sim/tests/exam/report_golden.sh` | ❌ W0 | ⬜ pending |
| 07-NN-06 | exam-timer | 2 | RUN-04 | — | timer subshell emits HH:MM:SS strings that monotonically decrement | unit | `bash cka-sim/tests/exam/timer_render.sh` | ❌ W0 | ⬜ pending |
| 07-NN-07 | exam-cmd | 3 | RUN-06 | — | SIGINT during read flags current question, persists JSON, returns to prompt | unit | `bash cka-sim/tests/exam/signal_handlers.sh` | ❌ W0 | ⬜ pending |
| 07-NN-08 | exam-cmd | 3 | RUN-05 | — | --resume after SIGINT re-loads state, recomputes deadline, runs reset+setup for current question | integration | `bash cka-sim/tests/exam/exam_resume_after_int.sh` | ❌ W0 | ⬜ pending |
| 07-NN-09 | exam-cmd | 3 | RUN-03 | — | end-to-end exam against mock pack produces session.json + report.md with 17 graded entries | integration | `bash cka-sim/tests/exam/exam_end_to_end.sh` | ❌ W0 | ⬜ pending |
| 07-NN-10 | exam-cmd | 3 | RUN-06 | — | SIGTERM fires EXIT trap, persists status=killed | unit | covered by `signal_handlers.sh` | ❌ W0 | ⬜ pending |
| 07-NN-11 | score-cmd | 4 | REPORT-02 | — | `cka-sim score <ts>` re-renders if .md missing, prints to stdout otherwise | unit | `bash cka-sim/tests/exam/score_command.sh` | ❌ W0 | ⬜ pending |
| 07-NN-12 | list-cmd | 4 | REPORT-02 | — | `cka-sim list history` walks fixture sessions dir, returns table sorted desc | unit | `bash cka-sim/tests/exam/list_history.sh` | ❌ W0 | ⬜ pending |
| 07-NN-13 | blueprint-content | 5 | MOCK-01 | — | exams/blueprint-alpha/manifest.yaml passes pass H lint (count, weights, no dupes, sum 120-130) | lint | `bash cka-sim/scripts/lint-packs.sh` | ❌ W0 | ⬜ pending |
| 07-NN-14 | blueprint-content | 5 | MOCK-03 | — | manifest.yaml `exam.disclaimer` AND README.md contain "Not real CKA exam content; independently authored" | lint | covered by lint-packs pass H | — | ⬜ pending |
| 07-NN-15 | lint-extension | 5 | MOCK-01 | — | lint-packs.sh pass H validates blueprint manifests under exams/ | unit | `bash cka-sim/tests/exam/lint_blueprint.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Task ID format `07-NN-MM` is a placeholder — planner assigns real plan numbers (e.g., 07-01-01).*

---

## Wave 0 Requirements

- [ ] `cka-sim/tests/exam/` directory created
- [ ] `cka-sim/tests/fixtures/exam/mock-pack-alpha/` — 17-question synthetic pack with deterministic graders
- [ ] `cka-sim/tests/fixtures/exam/blueprint-mock-alpha.yaml` — manifest referencing mock-pack-alpha
- [ ] `cka-sim/tests/fixtures/exam/session-fixture.json` — fully-populated post-exam session for golden test
- [ ] `cka-sim/tests/fixtures/exam/expected-report.md` — golden output for report_golden.sh
- [ ] `cka-sim/tests/fixtures/exam/traps-mock-catalog.yaml` — trap IDs referenced by mock graders
- [ ] `cka-sim/tests/run.sh` extended (or already walks all `tests/<dir>/` files) to include `tests/exam/`

*Existing infrastructure (PATH-shadowed kubectl, jq stub, colors/log libs, fixture-based setup) covers everything else.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live 2-hour exam end-to-end on real 1+2 cluster | RUN-03..06 + MOCK-01 | A live full-mock against real packs is the only way to confirm the blueprint composition + signal handling + timer + resume all work together with real graders. Auto-tests use mocks. | Candidate runs `cka-sim exam blueprint-alpha`, exercises Ctrl-C/Ctrl-Z/--resume mid-exam, completes or expires, reads report. Recorded in `07-HUMAN-UAT.md`. |
| Visible countdown timer rendered correctly on real terminal | RUN-04 | tput sc/rc rendering is environment-dependent (TERM, terminal size, font). Auto-tests verify data, not pixels. | Candidate visually confirms timer is on its own status line, decrements every second, doesn't interfere with question text or kubectl output. |
| Pause via Ctrl-Z + `fg` resumes correctly | RUN-06 | bash job-control behavior in real interactive shell differs from scripted environments. | Candidate Ctrl-Zs mid-question, verifies prompt returns, runs other commands, types `fg`, verifies timer + question state restored. |
| Score report readability and usefulness | REPORT-01 | "Suggested next drills" relevance is judgment call. | Candidate completes a real exam, reviews report, confirms domain rankings + drill suggestions match their perceived weak areas. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (mock pack, fixtures, golden output)
- [ ] No watch-mode flags
- [ ] Feedback latency < 45s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

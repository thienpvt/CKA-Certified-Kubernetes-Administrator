---
phase: 14-question-framing-library-fixes
status: passed
plans_completed: 4
requirements_resolved: [BUG-M07, BUG-M08, BUG-M09, LIB-01]
date: 2026-05-17
---

# Phase 14 Verification — Question Framing + Library Fixes

## Plan-by-plan status

| Plan | Requirement | Status | Files modified |
| ---- | ----------- | ------ | -------------- |
| 14-01 | BUG-M07 | passed | `troubleshooting/02-netpol-dns-egress/question.md` |
| 14-02 | BUG-M08 | passed | `troubleshooting/03-coredns-resolution/question.md` |
| 14-03 | BUG-M09 | passed | `troubleshooting/06-broken-kubelet/grade.sh` |
| 14-04 | LIB-01 | passed | (verification-only, no edit) |

## Commits

- `d411c05` — fix(14-01): add Conventions block to troubleshooting/02 question.md (BUG-M07)
- `9f308a3` — fix(14-02): rewrite troubleshooting/03 question to match two-trap setup (BUG-M08)
- `fdf5cf7` — fix(14-03): add _strip_comments_from helper to troubleshooting/06 grade.sh (BUG-M09)
- `ef11f08` — docs(14-04): record LIB-01 verification — line 218 already forward-slash

## Static check gates (all green)

- `bash cka-sim/scripts/lint-packs.sh` → exit 0
- `bash -n cka-sim/packs/troubleshooting/06-broken-kubelet/grade.sh` → exit 0
- Acceptance-criteria greps for all 4 plans → all green per per-plan SUMMARY
- Synthetic test matrix for 14-03 helper → 3/3 PASS (commented-out / clean / uncommented bad flag)
- shellcheck not in environment (informational only; lint-packs is the authoritative gate)

## test.sh case status

`bash cka-sim/scripts/test.sh` → 6 of 79 cases failed (matches established baseline).

Failures (none introduced by Phase 14):

1. `cluster-architecture__04-pss-enforce` — Phase 10 awaiting UAT
2. `services-networking__06-netpol-endport` — Phase 13 (strengthened grader, fixture needs regen)
3. `storage__01-pvc-binding` — Phase 10 awaiting UAT
4. `storage__02-storageclass-dynamic` — Phase 10 awaiting UAT (live storage required)
5. `workloads-scheduling__04-hpa-metrics-server` — Phase 13 (strengthened grader, fixture needs regen)
6. `workloads-scheduling__05-daemonset` — Phase 10 awaiting UAT (live multi-node taint required)

Phase 14 cases all PASS:

- `troubleshooting__02-netpol-dns-egress` — ref-solution SCORE 3/3
- `troubleshooting__03-coredns-resolution` — ref-solution SCORE 4/4
- `troubleshooting__06-broken-kubelet` — ref-solution SCORE 2/2

## Why static checks are sufficient (no human UAT required)

- **BUG-M07 (14-01)** — pure additive question.md text change. No grader, setup, or ref-solution touched. Static check confirms the Conventions block is well-formed and the rest of the file is byte-for-byte unchanged. Live drill would test what was already tested in test.sh fixtures.

- **BUG-M08 (14-02)** — question.md text rewrite (lead paragraph + Tasks list). No grader, setup, or ref-solution touched. The two traps the question now acknowledges are the same two traps `setup.sh` has always planted; test.sh confirms ref-solution still scores 4/4.

- **BUG-M09 (14-03)** — grader behaviour change but constrained to the comment-stripping path. ref-solution.sh writes the correct flags with no `#` comments, so existing test.sh fixtures continue to pass. The synthetic test matrix exercises the three behavioural axes the helper introduces. A live drill would only re-confirm the synthetic matrix results.

- **LIB-01 (14-04)** — verification-only. No code change; the forensic finding was already addressed in an earlier snapshot.

## Notes

The grader change in 14-03 only matters for candidate files with `#` comments — test.sh fixtures contain no such comments, so the test suite is intentionally blind to this code path. The synthetic test matrix in Plan 14-03 Task 3 provides the direct coverage. If a human wants extra confidence, a one-line live drill of `cka-sim drill troubleshooting 06-broken-kubelet` then writing a candidate file with `# old: --container-runtime=remote` above the live flag and running the grader would confirm zero false trap.

## Phase 14 status

**passed** — all 4 plans complete, all acceptance criteria green, lint-packs clean, no new test.sh regressions, all 4 requirements resolved.

# Phase 24: v1.0.3 Sign-Off + Lab UAT Batch - Context

**Gathered:** 2026-05-21
**Status:** Ready for planning
**Mode:** Smart discuss (autonomous) — close-out phase

<domain>
## Phase Boundary

Final phase of the v1.0.3 milestone. Mirrors v1.0.1's Phase 15 / v1.0.2's Phase 21 sign-off shape:
1. Author a UAT driver `cka-sim/scripts/uat-v103.sh` (or per-phase `uat-phase22.sh` + `uat-phase23.sh`) covering all 5 v1.0.3 REQ closure points.
2. Run the driver on the v1.0.1 lab cluster (1 control-plane + 2 workers, Calico, enforcing CNI).
3. Push to a feature branch and observe GHA `validate.yml` (validate-local + bash-tests jobs) exit 0 — closes the BLG-06/BLG-07 GHA-confirmation boundary deferred from Phase 23.
4. Write `.planning/milestones/v1.0.3-MILESTONE-AUDIT.md` recording final per-requirement status with phase-by-phase commit ranges.
5. Update STATE.md to reflect milestone close.

**Out of scope:** new REQ-IDs (none — Phase 24 has no REQ-IDs by design). New code fixes (Phase 22+23 already shipped). Pre-existing 2 reds (`report_golden`, `services-networking__06-netpol-endport`) — documented out-of-scope baseline.
</domain>

<decisions>
## Implementation Decisions

### UAT driver shape — single `uat-v103.sh` covering all 5 REQs

- Author one driver `cka-sim/scripts/uat-v103.sh` mirroring `uat-phase18-21.sh` shape (PASS/FAIL/SKIP/TOTAL counters, `report` / `skip` / `score_of` / `trap_count` / `reset_q` / `prep_baseline` helpers, ANSI color output via lib/colors.sh).
- Sub-checks (one per REQ):
  - **DRILL-NS-01** — Smoke test: invoke `cka-sim drill storage 1` against the lab cluster; capture rendered prompt; assert (a) literal `cka-sim-storage-01` appears in output, (b) literal `${CKA_SIM_LAB_NS}` does NOT appear. Optionally repeat for 2-3 packs (storage/01, services-networking/01, troubleshooting/05) to widen coverage.
  - **AUDIT-W&S06** — Run `bash bin/cka-sim audit workloads-scheduling/06-static-pod`; assert output contains `SKIPPED` (or whatever the unsupported-in-audit-mode terminology landed on) and exits 0. Drill-mode preservation: `cka-sim drill workloads-scheduling 6` against the lab cluster scores ≥0/N (max via ref-solution.sh round-trip).
  - **LINT-01** — Run `cka-sim/tests/cases/symptom-diff-regression.sh` against a host with live `kubectl cluster-info` available; assert it exits non-zero with `expected 'Bound', got 'Pending'` in stderr. (The local skip-when-no-cluster behavior is already verified; lab UAT is the live confirmation.)
  - **BLG-06** — Push the v1.0.3 close-out commit; observe GHA `validate.yml` `shellcheck` job exits 0 without `continue-on-error: true`; capture run ID + log to `cka-sim/current-tests/step6-results.txt` or commit reference.
  - **BLG-07** — Same GHA push; observe `bash-tests` job exits 0 with `baseline_capture_smoke` 6/6 green and 4 `traps_*` cases green; capture in same step6-results.txt.

- Counters: PASS / FAIL / SKIP / TOTAL — exit 1 if FAIL > 0, exit 0 otherwise. Skips are non-fatal (e.g., DRILL-NS-01 can skip on Windows MSYS where lab cluster isn't reachable; LINT-01 skips when `kubectl cluster-info` not available).

### v1.0.3-MILESTONE-AUDIT.md shape

Mirror `.planning/milestones/v1.0.2-MILESTONE-AUDIT.md` (if exists) and `.planning/milestones/v1.0.1-MILESTONE-AUDIT.md`. Sections:
- **Frontmatter** — milestone version, ship date, audit status (`tech_debt` likely — same as v1.0.1/v1.0.2)
- **Executive Summary** — phase count (3 phases: 22, 23, 24), plan count, REQ count
- **Per-requirement status table** — REQ-ID | Title | Plans | Verification | Status (`satisfied` / `addressed` / `deferred`)
- **Per-phase commit ranges** — Phase 22 commits (79dcdbe..91a258c), Phase 23 commits (TBD), Phase 24 commits (TBD)
- **Lab UAT results** — link to `cka-sim/current-tests/step6-results.txt` (or whatever the v1.0.3 evidence file ends up named)
- **Outstanding items** — anything routed to v1.0.4 (likely none if all 5 REQs close cleanly)

### Driver file location

- `cka-sim/scripts/uat-v103.sh` (single milestone-level driver). The previous pattern was per-phase (`uat-phase18-21.sh`); for a 3-phase milestone with 5 REQs, a single driver is cleaner and matches the README/SUMMARY shape.
- Add the executable bit via `git update-index --chmod=+x` after `git add`.
- Mirror the helper-function shape from `uat-phase18-21.sh` so driver hygiene is consistent.

### STATE.md close-out

- Set frontmatter `status: shipped` and `progress.percent: 100`
- Append a `### v1.0.3 Close-Out` section after the v1.0.2 Close-Out section (preserve existing context)
- Record per-phase commit ranges, UAT result, GHA confirmation evidence
- Route any remaining tech debt to v1.0.4 explicitly (likely empty)

### Claude's Discretion

- Whether to split BLG-06+BLG-07 GHA confirmation into a separate "step6-results.txt" file or fold into uat-v103.sh output
- Whether to add a CI gate that runs uat-v103.sh on a kind-cluster GHA matrix axis (defensive but adds CI time — defer to v1.0.4 if needed)
- Per-phase commit-range git log queries to pull the SHAs for the audit doc

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`cka-sim/scripts/uat-phase18-21.sh`** — v1.0.2 close-out driver. Reference shape: PASS/FAIL/SKIP/TOTAL counters, `report` / `skip` / `score_of` / `trap_count` / `reset_q` / `prep_baseline` helpers. Sources `lib/colors.sh`, `lib/log.sh`, `lib/baseline.sh`. Mirror this exactly.
- **`cka-sim/scripts/uat-phase{10,11,13}.sh`** — v1.0.1 close-out drivers. Same shape.
- **`.planning/milestones/v1.0.1-MILESTONE-AUDIT.md`** — v1.0.1 audit shape reference.
- **`.planning/milestones/v1.0.2-MILESTONE-AUDIT.md`** — v1.0.2 audit shape reference (may or may not exist post-cleanup).

### Established Patterns

- **UAT driver mode** — drivers run on the control-plane node from the repo root. They source `lib/colors.sh`, `lib/log.sh`, `lib/baseline.sh`. They use `prep_baseline` between setup and grade for grading-honesty graders.
- **GHA confirmation** — push to feature branch, observe `validate.yml` exit 0, capture log artifact path / run ID. Pattern from v1.0.1/v1.0.2.
- **MILESTONE-AUDIT.md frontmatter** — `milestone`, `ship_date`, `audit_status` (`tech_debt` / `satisfied` / `mixed`), per-REQ status.

### Integration Points

- **`cka-sim/scripts/`** — uat-v103.sh lives here.
- **`.planning/milestones/`** — v1.0.3-MILESTONE-AUDIT.md lives here.
- **`.planning/STATE.md`** — Close-Out section gets appended.
- **`cka-sim/current-tests/`** — UAT result capture file (step6-results.txt or equivalent).
- **`.github/workflows/validate.yml`** — GHA exit 0 evidence point (run ID + commit SHA after push).

</code_context>

<specifics>
## Specific Ideas

- The driver MUST detect skip-vs-fail at each step. Lab cluster reachability check: `kubectl cluster-info >/dev/null 2>&1 || skip "..." "no live cluster"`. This mirrors `cka-sim/tests/cases/symptom-diff-regression.sh:22-25` pattern.
- Phase 24 explicitly does NOT add new code fixes. If UAT surfaces a new bug, route to v1.0.4 or open a `gaps_found` plan via `/gsd-plan-phase 24 --gaps`.
- The MILESTONE-AUDIT.md must be conservative: only mark a REQ `satisfied` if both in-tree code + UAT evidence are green. `addressed` if code lands but UAT is partial. `deferred` if not closed (none expected — there are no v1.0.3 placeholder phases).

</specifics>

<deferred>
## Deferred Ideas

- **CI gate for uat-v103.sh** — would catch v1.0.4+ regressions but adds GHA time. Defer.
- **Multi-cluster UAT** (run uat-v103.sh against kind + lab cluster matrix) — defensive but heavy. Defer.
- **Auto-archive uat-* drivers** to `cka-sim/scripts/archive/` once milestone is shipped — keeps the active scripts/ dir lean. Consider in v1.0.4 cleanup.

</deferred>

<canonical_refs>
## Canonical References

- `.planning/ROADMAP.md` — Phase 24 goal + 4 success criteria (lines 205-215)
- `.planning/REQUIREMENTS.md` — 5 v1.0.3 requirements + Coverage notes (Phase 24 has no REQ-IDs by design)
- `.planning/STATE.md` — v1.0.2 Close-Out reference shape
- `.planning/phases/22-surgical-tech-debt-fixes/22-VERIFICATION.md` — Phase 22 status
- `.planning/phases/23-gha-environmental-forensics-lint-triage/23-VERIFICATION.md` — Phase 23 status
- `cka-sim/scripts/uat-phase18-21.sh` — v1.0.2 close-out driver (reference shape for uat-v103.sh)
- `cka-sim/scripts/uat-phase{10,11,13}.sh` — v1.0.1 close-out drivers
- `.planning/milestones/v1.0.1-MILESTONE-AUDIT.md` — audit doc reference shape

</canonical_refs>

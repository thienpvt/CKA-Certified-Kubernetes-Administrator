---
plan: 17-05
phase: 17-v1-0-2-backlog-cleanup
requirements: [BLG-06]
status: complete (scaffolding only — full close in follow-up commit)
date: 2026-05-19
---

# Plan 17-05 Summary — BLG-06 CI shellcheck scaffolding

## Outcome

Lands the minimum CI scaffolding to unblock v1.0.2 merge while the per-finding shellcheck triage happens out-of-band. Three changes:

1. **`.github/workflows/validate.yml` shellcheck job** gains `continue-on-error: true` so first-run reds don't block the rest of v1.0.2 from merging.
2. **A new `Print shellcheck findings (BLG-06 triage)` step** runs `if: always()` and groups all findings into the GHA log so an operator can fetch them offline for triage.
3. **`cka-sim/scripts/validate-local.sh`** gains a graceful skip for pass 2 (shellcheck) when either `CKA_SIM_SKIP_SHELLCHECK=1` is set or the `shellcheck` binary is not on PATH. yamllint pass 1 is unchanged.

This plan does NOT close BLG-06 fully. The per-finding remediation (inline `# shellcheck disable=<code>` directives or root-cause fixes) lands in a follow-up commit on this same branch after the first GHA run reveals the actual finding count + codes. The plan is `autonomous: false`.

## Files Modified (2)

- `.github/workflows/validate.yml` — added `continue-on-error: true` (with BLG-06 TODO comment) at the shellcheck job level, plus the triage step.
- `cka-sim/scripts/validate-local.sh` — wrapped pass 2 in a guard honoring `CKA_SIM_SKIP_SHELLCHECK` and gracefully skipping when shellcheck is missing.

## Plan-Time Note

This plan deliberately does not run shellcheck against the corpus locally (Windows host doesn't have shellcheck installed; pass-through to Microsoft Store stub for python3 already burned us in Plan 17-01's case-file). The triage flow:

1. Push the branch; GHA runs.
2. Open the failed `shellcheck` job in the GHA UI.
3. Copy the `Print shellcheck findings (BLG-06 triage)` step output (already grouped via `::group::` markers).
4. Triage offline: real bug → fix in code; over-strict → inline disable with one-line justification.
5. Group fixes by file; commit one per file: `fix(17-05): <file>: <SC-codes>`.
6. After all findings are addressed, remove `continue-on-error: true` and the BLG-06 comment. Commit `refactor(17-05): re-enable shellcheck gate after BLG-06 triage`.

## Acceptance Criteria

| Check | Result |
|-------|--------|
| `continue-on-error: true` present at shellcheck job | ✓ |
| BLG-06 TODO comment | ✓ |
| Triage step with `if: always()` | ✓ |
| Other jobs NOT marked continue-on-error | ✓ (only shellcheck) |
| validate.yml parses | ✓ |
| validate-local.sh honors `CKA_SIM_SKIP_SHELLCHECK` | ✓ |
| validate-local.sh gracefully skips when shellcheck missing | ✓ |
| pass 1 (yamllint) untouched | ✓ |
| `bash -n cka-sim/scripts/validate-local.sh` exits 0 | ✓ |

## Outstanding (full close)

The per-finding remediation commit + the `continue-on-error` removal commit are NOT in this plan. They are tracked as the BLG-06 follow-up. The orchestrator should pause for the operator after this plan lands and the GHA log is fetched.

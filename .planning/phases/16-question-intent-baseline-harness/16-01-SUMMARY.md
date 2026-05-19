---
plan: 16-01
phase: 16-question-intent-baseline-harness
requirements: [BASELINE-01]
status: complete
date: 2026-05-19
---

# Plan 16-01 Summary — `cka-sim audit` subcommand

## Outcome

`cka-sim audit` ships as a forensic question-intent baseline tool. Three scopes (all / pack / single), human-readable per-question output (PASS-suppression on clean, FAIL table + Claim source block on divergence), `--report path/to.md` markdown writer, and the locked exit codes (0 all PASS / 1 ≥1 FAIL / 2 preflight error).

The diff core was extracted from `cka-sim/scripts/lint-question-symptom.sh` into a shared `cka-sim/lib/symptom-diff.sh` library so both the lint variant (CI gate, `ns_prefix='lint'`, exit 0 on no-cluster) and the audit variant (forensic tool, `ns_prefix='audit'`, exit 2 on no-cluster) call the same `cka_sim::symptom_diff::run_one` primitive.

## Files Created (2)

- `cka-sim/lib/symptom-diff.sh` (mode 0644, sourceable, NOT executable). Module guard, 21-entry `KIND_ALIAS`, `_is_cluster_scoped`, `_jsonpath_to_jq`, `cka_sim::symptom_diff::compute_ns` (RFC 1123, ≤63 chars, no trailing dash), `cka_sim::symptom_diff::run_one`. The new TSV-on-fd-3 instrumentation (`_emit_row`) lets audit capture structured rows for table rendering while lint silently drops them (fd 3 closed → write fails harmlessly).
- `cka-sim/lib/cmd/audit.sh` (mode 0755). Three scopes, preflight (cluster-info / jq / python3 / yaml), `cka_sim::audit::_render_question` PASS/FAIL renderer, `cka_sim::audit::_claim_source` extractor (greps question.md for first match of resource name, prints ±1-line excerpt), aggregate summary, atomic mktemp+mv markdown report writer.

## Files Modified (3)

- `cka-sim/scripts/lint-question-symptom.sh` — refactored to source the new lib. Inline `KIND_ALIAS`, `_is_cluster_scoped`, `_jsonpath_to_jq`, and `_diff_one_question` deleted. Driver loop now calls `cka_sim::symptom_diff::run_one "$yaml_file" "$q_dir" "$pack" "$q_name" "lint"`. Behaviour byte-identical pre/post.
- `cka-sim/bin/cka-sim` — case branch updated from `bootstrap|doctor|list|version|drill|exam|score)` to `bootstrap|doctor|list|version|drill|exam|score|audit)`.
- `cka-sim/lib/cmd/help.sh` — added the line `  audit       Question-intent baseline diff (forensic; live-cluster required)` between `score` and `version`.

## UAT Results (no-cluster Windows host)

| Run | Expected | Actual | Verdict |
|-----|----------|--------|---------|
| `bash cka-sim/scripts/lint-question-symptom.sh` | rc=0 + warn-skip | rc=0, "no live cluster reachable — skipping symptom-diff" | ✓ |
| `bash cka-sim/bin/cka-sim audit` | rc=2 + audit-specific err | rc=2, "no live cluster reachable" + "audit requires a live kind+Calico cluster — start one and retry" | ✓ |
| `bash cka-sim/bin/cka-sim help` | one `^  audit ` line | exactly one match | ✓ |
| `bash cka-sim/scripts/test.sh` | rc=0 (suite passes pre/post refactor) | rc=0, 78/80 cases pass (2 reds = pre-existing BLG-05 reds, unchanged) | ✓ |

## Output Design Held

- PASS path: single line `✓ <pack>/<id>: PASS (N/N expectations met)`. Full table suppressed (D-06).
- FAIL path: header + 6-column table (`kind | name | jsonpath | claimed | actual | verdict`) + Claim source block citing question.md prose excerpt.
- Verdict glyphs: ✓ PASS, ✗ FAIL, ? MISSING, ! ERROR.
- Aggregate footer: `─── audit summary ───` + `N/M PASS, K FAIL, L errors`.
- `--report path/to.md` writes the same content via mktemp + atomic mv (drill.sh report-writer pattern).

## Exit-Code Contract Held

- `0` — all PASS
- `1` — at least one FAIL
- `2` — preflight error (no live cluster, missing jq/python3/yaml)

The lint variant intentionally diverges (exit 0 on no-cluster) because it is a CI gate that must pass on machines without a live cluster; audit is a deliberately invoked forensic tool that exits 2 to signal an environment problem.

## Deferred

- Live-cluster end-to-end audit run (run setup.sh against kind+Calico, render an actual FAIL table, extract a real Claim source excerpt) — deferred to Phase 18 forensic re-audit, where the tool gets exercised against all 34 questions for the first time.
- shellcheck verification — `shellcheck` is not installed on this Windows host; lint coverage runs in GHA `validate.yml`'s shellcheck job (currently red per BLG-06; orthogonal to this plan).

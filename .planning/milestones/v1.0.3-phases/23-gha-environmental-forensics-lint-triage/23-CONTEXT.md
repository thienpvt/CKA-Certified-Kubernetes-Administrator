# Phase 23: GHA Environmental Forensics + Lint Triage - Context

**Gathered:** 2026-05-21
**Status:** Ready for planning
**Mode:** Smart discuss (autonomous)

<domain>
## Phase Boundary

Both v1.0.2 carry-overs are closed at the root:
1. **BLG-06** — every shellcheck/yamllint finding emitted by the GHA `validate-local` job has a recorded disposition (fix in code / relax in lint config with rationale / out of scope), and `continue-on-error: true` is lifted off the job.
2. **BLG-07** — the 9 unit-test cases red on `ubuntu-latest` (the `cka_sim::baseline::is_candidate_modified` unchanged-baseline branch reporting `expected 1 got 0` plus the 4 cascading `traps_*` cases — `default-sa-used`, `hostpath-pv-without-nodeaffinity`, `missing-dns-egress`, `ownership_gate`) are root-caused and made green across the full environment matrix (GHA Ubuntu, Docker Ubuntu 22.04, Docker Ubuntu 24.04, Windows MSYS, local kind).

**Out of scope:** Phase 22 surgical fixes (DRILL-NS-01, AUDIT-W&S06, LINT-01) — already shipped. New tests beyond what's needed to close BLG-07. Lab-cluster verification (deferred to Phase 24).
</domain>

<decisions>
## Implementation Decisions

### BLG-06 — per-finding shellcheck/yamllint triage

- Source of findings: GHA `validate.yml` `shellcheck` job (line 81+, `continue-on-error: true` at line 84) runs `bash cka-sim/scripts/validate-local.sh` and prints findings via the "Print shellcheck findings" step at line 96+.
- Approach: run `validate-local.sh` locally to enumerate findings (executor must have shellcheck + yamllint installed). Walk each finding and apply ONE of three dispositions:
  - **fix in code** — the warning is real, edit the source file
  - **relax in lint config** — the warning is intentional/spurious; add a per-rule disable in `.shellcheckrc` / yamllint config OR add a per-line `# shellcheck disable=SC1234` comment with documented rationale
  - **out of scope** — the file is generated, vendored, or 3rd-party; exclude from lint via config
- Record dispositions in `23-01-SUMMARY.md` per finding (table: file:line | rule | disposition | rationale).
- After all findings have a disposition AND `bash cka-sim/scripts/validate-local.sh` exits 0 on Linux, remove `continue-on-error: true` from `.github/workflows/validate.yml:84`.
- The "Print shellcheck findings" step at line 96+ remains as-is (still useful for triage on future PRs); only the `continue-on-error: true` line is removed.

### BLG-07 — GHA bash-tests environmental reds

- Symptom: `bash cka-sim/scripts/test.sh` returns rc=1 on `ubuntu-latest` GHA runner, with `expected 1 got 0` on the unchanged-baseline branch of `cka_sim::baseline::is_candidate_modified` (test case `baseline_capture_smoke`, sub-test "unchanged: returns 1 (gen=3 rv=100 same as baseline)").
- Cascading reds: 4 `traps_*` cases (`default-sa-used`, `hostpath-pv-without-nodeaffinity`, `missing-dns-egress`, `ownership_gate`) — all 4 detectors call `is_candidate_modified` as their ownership gate. When the helper returns 0 (modified) on the unchanged path, the detectors fire when they shouldn't.
- **NOT reproducible on Windows MSYS or local kind** — verified by re-running `bash cka-sim/scripts/test.sh` here: `baseline_capture_smoke` is 5/5 green locally.
- Root-cause hypotheses (ranked by likelihood, from CONTEXT.md analysis of `cka-sim/lib/baseline.sh:264-275` rv-fallback and `cka-sim/tests/bin/kubectl:84-94` jsonpath translator):
  1. **jq output formatting differs across versions** — GHA Ubuntu may ship a jq that emits integers with formatting differences (e.g., `100` vs `"100"`). Test fixture has `"resourceVersion": "100"` (string). Stub passes through `jq -r '... // ""'`. Possible jq-version delta in how `// ""` interacts with the `as $v` binding from BUG-M11's fix.
  2. **bash version delta** — `[[ "$current_rv" != "$baseline_rv" ]]` should compare strings consistently, but bash 5.x quirks around set -u and unbound vars could differ.
  3. **`set -euo pipefail` interaction with `jq | tr | sed | head` pipeline** — on different bash versions, pipeline component failures may propagate differently, leaving `current_rv` empty.
  4. **CRLF/LF line ending differences** in fixture JSONs after git checkout on Linux runner — though `core.autocrlf=true` is unusual on Linux runners.
- Fix shape: investigation-first. Plan 23-02 Task 1 reproduces the failure (either via Docker Ubuntu 22.04 + jq comparison, or via reading captured GHA logs from `cka-sim/current-tests/step1-results.txt`). Plan 23-02 Task 2 applies the fix at the root. Acceptable fix paths:
  - Normalize `current_rv` after capture: `current_rv="${current_rv//$'\r'/}"` (CRLF strip) + ensure trailing newline strip works on all jq versions
  - Add an explicit empty-check: if `current_rv` is empty AND `baseline_rv` is non-empty, return 1 (not modified — current state unreadable, default conservative)
  - Pin the kubectl stub's jsonpath translator to emit a deterministic shape across jq versions
- Post-fix: re-run on the GHA runner via lab UAT (Phase 24) — Phase 23 ships in-tree fixes verified locally + on Docker Ubuntu 22.04 if available; GHA confirmation comes through Phase 24 batch.

### Claude's Discretion

- Whether to ship BLG-06 as one plan or split into shellcheck-vs-yamllint sub-plans — depends on finding counts (executor decides at planning time).
- Whether BLG-07 root-cause is in `lib/baseline.sh` (the helper) or `tests/bin/kubectl` (the stub) — depends on what investigation finds. Both are acceptable fix points.
- Whether to add a Docker Ubuntu 22.04 reproducibility test in `cka-sim/scripts/test.sh` — useful but adds a docker dependency to local tests; defer unless executor sees value.
- Order of plan execution within wave 1 — BLG-06 and BLG-07 are independent and can run in any order.
</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`cka-sim/scripts/validate-local.sh`** — runs shellcheck + yamllint over the cka-sim corpus. BLG-06's source of findings.
- **`.github/workflows/validate.yml:81-100`** — `shellcheck` job with the `continue-on-error: true` scaffolding (line 84, BLG-06 must remove) and the "Print shellcheck findings" triage step (line 96+, keep as-is).
- **`cka-sim/lib/baseline.sh:264-275`** — rv-fallback path; BLG-07 fix point candidate.
- **`cka-sim/tests/bin/kubectl:84-94`** — jsonpath translator; BLG-07 fix point candidate (BUG-M11 fix at line 91-93 added the `as $v` binding).
- **`cka-sim/current-tests/step1-results.txt`** — captured GHA output showing the 9 reds. Investigation evidence.
- **`cka-sim/tests/cases/baseline_capture_smoke.sh`** — the test case that exercises the unchanged-baseline branch (line 41-45).
- **`cka-sim/tests/fixtures/grading-honesty/baseline-stub/deployment-web-unchanged.json`** — the fixture with `"resourceVersion": "100"` that the unchanged branch reads.

### Established Patterns

- **continue-on-error: true scaffolding** — Phase 17 (Plan 17-05, commit `a77712a`) used this pattern to ship BLG-06's per-finding fixes asynchronously. v1.0.3 closes the loop.
- **Environment-matrix testing** — Phase 22 already validated drill render and `_emit_row` on Windows MSYS + lab Linux; v1.0.3's matrix expands to GHA `ubuntu-latest` via Phase 24 UAT.
- **BUG-M11 jq fallback** — `cka-sim/tests/bin/kubectl:91-93` `as $v | $v // ""` shape was a v1.0.2 fix. BLG-07 may be a follow-on environment-specific issue with the same shape.

### Integration Points

- **`.github/workflows/validate.yml:84`** — BLG-06 single-line removal point.
- **`cka-sim/lib/baseline.sh:264-275`** OR **`cka-sim/tests/bin/kubectl:84-94`** — BLG-07 fix point (executor decides based on investigation).
- **`cka-sim/scripts/test.sh`** — runs all unit cases including the affected `baseline_capture_smoke` and 4 `traps_*` cases.

</code_context>

<specifics>
## Specific Ideas

- **BLG-06 must produce a SUMMARY.md table** — file:line, rule (e.g. SC2086), disposition (fix/relax/oos), rationale. This is the audit trail for Phase 23 sign-off.
- **BLG-07 root-cause must be code-level** — not "rerun on a green runner". The fix has to address why Linux runners diverge from MSYS/local kind. Ideally: identify the divergent shell behavior, fix the helper or stub to be deterministic.
- **Both fixes ship in Phase 23** — verification on GHA `ubuntu-latest` is Phase 24 UAT (push to `main` and observe GHA validate.yml exit 0; capture `cka-sim/current-tests/step6-results.txt`).

</specifics>

<deferred>
## Deferred Ideas

- **Add a `linux-shellcheck-only` GHA matrix axis** — useful for catching Ubuntu 24.04 vs 22.04 lint config drift. Not P23; consider for v1.0.4.
- **Vendor jq binary in cka-sim/vendor/** — would eliminate jq-version variance entirely but adds repo size. Defer.
- **Emit per-test-case timing** in `test.sh` to spot environmental hangs. Useful for future BLG-* triage. Defer.
- **Strict mode for kubectl stub** — abort the stub if jsonpath translation hits an unsupported shape rather than returning empty. Defensive but risk of false positives. Defer.

</deferred>

<canonical_refs>
## Canonical References

- `.planning/ROADMAP.md` — Phase 23 goal + 4 success criteria (lines 193-203)
- `.planning/REQUIREMENTS.md` — BLG-06, BLG-07 acceptance criteria
- `.planning/STATE.md` — v1.0.2 Close-Out section; v1.0.2-followups (BLG-06, BLG-07) routed to v1.0.3 scope
- `cka-sim/current-tests/step1-results.txt` — captured GHA bash-tests output (9 reds)
- `.github/workflows/validate.yml` — BLG-06 fix point (line 84 `continue-on-error: true`)
- `cka-sim/scripts/validate-local.sh` — produces shellcheck/yamllint findings
- `cka-sim/lib/baseline.sh` — `is_candidate_modified` definition (BLG-07 fix candidate at lines 264-275)
- `cka-sim/tests/bin/kubectl` — jsonpath translator stub (BLG-07 fix candidate at lines 84-94)
- `cka-sim/tests/cases/baseline_capture_smoke.sh` — failing test case (line 41-45)
- `cka-sim/tests/fixtures/grading-honesty/baseline-stub/deployment-web-unchanged.json` — unchanged-branch fixture

</canonical_refs>

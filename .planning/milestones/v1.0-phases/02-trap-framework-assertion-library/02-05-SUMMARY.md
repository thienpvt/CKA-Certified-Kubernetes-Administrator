# Phase 2, Plan 02-05 Summary — CI Integration

**Plan:** 02-05
**Completed:** 2026-05-10
**Requirements landed:** GRADE-01, GRADE-05, TRIP-07 (CI coverage for all three)
**Executed:** Inline by orchestrator (the original agent worktree was created from stale base `5500f29` and discarded)

## One-liner

Extended `.github/workflows/validate.yml` to trigger on `cka-sim/**` and `**.sh` changes, and added a `bash-tests` job that runs `bash cka-sim/scripts/test.sh` on `ubuntu-latest` — closing the loop so Phase 2's catalog lint + 15 unit cases gate every relevant PR.

## Diff applied

```diff
 on:
   push:
     branches: [main]
     paths:
       - 'skeletons/**'
       - 'exercises/**'
+      - 'cka-sim/**'
       - '**.yaml'
       - '**.yml'
+      - '**.sh'
   pull_request:
     branches: [main]
     paths:
       - 'skeletons/**'
       - 'exercises/**'
+      - 'cka-sim/**'
       - '**.yaml'
       - '**.yml'
+      - '**.sh'
 # ... existing yamllint job unchanged ...
+
+  bash-tests:
+    name: Bash unit tests (traps + grade)
+    runs-on: ubuntu-latest
+    steps:
+      - uses: actions/checkout@v4
+
+      - name: Run cka-sim test suite
+        run: bash cka-sim/scripts/test.sh
```

Existing `yamllint` job bit-for-bit unchanged. No shellcheck / deprecated-strings additions (deferred to Phase 8 CI-02).

## Verification

- `grep -c 'shellcheck' .github/workflows/validate.yml` → 0 ✓ (out-of-scope items not leaked)
- `grep -E '^  (yamllint|bash-tests):$' .github/workflows/validate.yml` → 2 jobs ✓
- `grep -c "cka-sim/\*\*" .github/workflows/validate.yml` → 2 (push + pull_request) ✓
- `bash cka-sim/scripts/test.sh` → `all 15 case(s) passed` ✓ (with jq on PATH)

(`python3 yaml.safe_load` validation skipped locally — Python not available in this shell. YAML indent + structure confirmed via grep and visual review. GitHub's Actions runner parses it before running, so any shape defect fails at push time.)

## Phase 2 close-out — all 5 ROADMAP success criteria green

1. **`lib/traps.sh` exports ≥8 detectors** ✓ (plan 02-02 — 8 `cka_sim::trap::detect_*` functions, each echoing a stable trap-id on hit, empty on miss)
2. **`lib/grade.sh` exports ≥7 helpers + `emit_result`** ✓ (plan 02-01 — `assert_resource_exists`, `assert_field_eq`, `assert_pod_ready`, `assert_pvc_bound`, `assert_can_i`, `assert_egress_allowed`, `assert_endpoints_nonempty`, plus `record_trap` and `emit_result`)
3. **`traps/catalog.yaml` has 8 seeded entries + passes schema lint** ✓ (plan 02-02 catalog, plan 02-03 lint-traps.sh with 8-field schema + enum validation + path existence + seed completeness, runtime verified green)
4. **Unit tests fire correctly on known-bad fixtures** ✓ (plan 02-04 — 9 detector fixtures + 13 helper fixtures + 15 case files, end-to-end `test.sh` exits 0 with `all 15 case(s) passed`)
5. **RFC 1123 naming across trap-ids, helpers, catalog keys** ✓ (plans 02-01 `cka_sim::trap::is_valid_id` + 02-03 `lint-traps.sh` id regex enforcement)

## Fix committed during phase (not originally planned)

- **`3ef2f8a` fix(02-02): capture BASH_REMATCH before _validate_entry in lint-traps.sh** — Root cause: `_validate_entry` internally calls `cka_sim::trap::is_valid_id` which does its own `[[ =~ ]]` regex, clobbering `BASH_REMATCH` before the outer loop could read it. The bug caused catalog ids to be progressively truncated (`pss-error-string-mismatch` → `ss-` → `s-` → `-`) and crashed on the last iteration with `BASH_REMATCH[1]: unbound variable`. Fixed by capturing the id into a local `new_id` var before the `_validate_entry` call.

## Environmental notes for Phase 3+

- **jq is required for the 3 kubectl-using detectors** (default-sa-used, missing-dns-egress, hostpath-pv-without-nodeaffinity). Phase 1's bootstrap installs jq on Ubuntu 22.04; GitHub Actions `ubuntu-latest` has it pre-installed. Windows dev hosts without jq on PATH will see 7/15 pass, 8/15 fail — install jq or skip kubectl-using cases.
- **Test harness is sourceable but case files are non-executable** — `bash cka-sim/tests/run.sh` sources each `cases/*.sh` rather than invoking them.
- **8 seeded trap-ids are now runtime-validated** by `record_trap` — any grader attempting to emit an unregistered id will `die` fast.

## Handoff to Phase 3

Phase 3 graders will:
- `source "$CKA_SIM_ROOT/lib/grade.sh"` for assertions
- `source "$CKA_SIM_ROOT/lib/traps.sh"` for detectors
- Call the 7 assertion helpers with accumulator-style failure semantics (`set -uo pipefail`, no `die` on assertion failure)
- Invoke detectors explicitly per-grader (no auto-fire), record trap-ids via `record_trap`
- Call `emit_result` at the end to print `SCORE: <n>/<max>` + deduped `Trap N:` lines

## Not in scope (Phase 8 territory)

- Shellcheck GitHub Actions step over `cka-sim/**/*.sh` (CI-02)
- Deprecated-strings grep lint (PodSecurityPolicy, `--container-runtime=remote`, etc.) (CI-02)
- Pack lint: `kubectl get | grep` rejection, trap-count minimum, cluster-scoped name collision (CI-03)

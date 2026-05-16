# Phase 2: Trap Framework + Assertion Library — Pattern Map

**Mapped:** 2026-05-09
**Files analyzed:** 11 file groups (some are directories of fixtures/cases)
**Analogs found:** 10 / 11 (only `traps/catalog.yaml` has no exact analog — schema is novel; pattern guidance comes from `skeletons/*.yaml` style + RESEARCH.md)

---

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------------|------|-----------|----------------|---------------|
| `cka-sim/lib/traps.sh` | helper-module (sourceable lib) | request-response (catalog parse + detector echo) | `cka-sim/lib/preflight.sh` | exact (sourceable namespaced helpers, identical contract) |
| `cka-sim/lib/grade.sh` | helper-module (sourceable lib) + state machine | event-driven (assertion events accumulate into arrays) | `cka-sim/lib/cmd/doctor.sh` (aggregate-failures pattern) + `cka-sim/lib/preflight.sh` (helper-module shape) | exact (doctor.sh's `failures=0`, `_pass`/`_fail` pattern is the direct ancestor of `assert_X` + `emit_result`) |
| `cka-sim/traps/catalog.yaml` | yaml-data (schema-validated content file) | static config | `skeletons/networkpolicy.yaml` (yaml style + inline comments) | partial (different domain — schema is novel) |
| `cka-sim/tests/bin/kubectl` | cli-script (PATH-shadow stub) | request-response (argv → fixture file) | `cka-sim/bin/cka-sim` router (argv-dispatch case statement) | role-match (both are argv-dispatch shims; no fixture-IO precedent in repo) |
| `cka-sim/tests/lib/assert.sh` | helper-module (test-only) | request-response (compare + log) | `cka-sim/lib/log.sh` | exact (single-purpose helper module, stderr output) |
| `cka-sim/tests/fixtures/**/*.json` | test-fixture (static data files) | static input | (no analog — first fixture corpus in repo) | none |
| `cka-sim/tests/cases/*.sh` | test-case (sourced bash file) | event-driven (each case sources lib + asserts) | `cka-sim/lib/cmd/doctor.sh` (linear-check shape, sources lib helpers, runs assertions) | role-match (doctor.sh is closest to "linear sequence of assertions with stderr status") |
| `cka-sim/tests/run.sh` | test-runner (orchestrator) | batch (walks dir, sources each, aggregates results) | `cka-sim/lib/cmd/doctor.sh` (aggregate-failures) + `scripts/validate-local.sh` (`find ... -print0` walk) | exact-blend (combines both established idioms) |
| `cka-sim/scripts/test.sh` | cli-script (orchestrator wrapper) | request-response (calls lint-traps then run.sh) | `cka-sim/lib/cmd/bootstrap.sh` (linear `info`/`ok` step orchestration) + `scripts/validate-local.sh` (top-level repo validator) | exact (linear-step orchestrator, `set -euo pipefail`) |
| `cka-sim/scripts/lint-traps.sh` | lint-script (validator) | batch (parse + validate every entry) | `scripts/validate-local.sh` | exact (REPO_ROOT idiom, `errors`/`checked` counters, exit 0/1 on result) |
| `.github/workflows/validate.yml` | ci-config (workflow extension) | event-driven (CI trigger) | `.github/workflows/validate.yml` (existing — modify in-place) | exact (extend `paths:` and add second job alongside `yamllint`) |

---

## Pattern Assignments

### `cka-sim/lib/traps.sh` (helper-module, sourceable)

**Analog:** `cka-sim/lib/preflight.sh`

**Imports / source-guard pattern** (preflight.sh lines 1-10):
```bash
#!/bin/bash
# cka-sim/lib/traps.sh — trap detector library + catalog parser
# Sourced by: lib/grade.sh, every grade.sh under packs/*/

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=colors.sh disable=SC1091
[[ -z "${RED+x}" ]] && source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"
```

**Function namespacing pattern** (preflight.sh line 16, 36, 57, 94):
```bash
cka_sim::preflight::check_binaries() { ... }
cka_sim::preflight::check_kubeconfig() { ... }
```
Apply to traps.sh → `cka_sim::trap::detect_<id>`, `cka_sim::trap::record` (note: per CONTEXT canonical_refs §"Established Patterns" the recorder lives in `grade::record_trap`, not `trap::`).

**Local-vars + positional args + stdout-as-return pattern** (preflight.sh lines 16-27):
```bash
cka_sim::preflight::check_binaries() {
  local missing=()
  local b
  for b in "$@"; do
    command -v "$b" >/dev/null 2>&1 || missing+=("$b")
  done
  if (( ${#missing[@]} > 0 )); then
    printf '%s\n' "${missing[@]}"
    return 1
  fi
  return 0
}
```
Apply directly: detectors take positional args, echo trap-id to stdout on hit (per CONTEXT D-02), nothing on miss.

**Specific differences from analog:**
- Detector contract per CONTEXT D-02: stdout = trap-id on hit, EMPTY on miss (preflight.sh by contrast echoes data on success AND failure with different return codes — different contract).
- traps.sh additionally parses `traps/catalog.yaml` at sourcing time into associative arrays `CKA_SIM_TRAP_NAME[id]`, `CKA_SIM_TRAP_DESC[id]`, etc. (D-04). No analog for this — `awk`/`grep` based parser. Use the pure-bash idiom established in `fileblock.sh` lines 41-43 (sed escaping, `mktemp` temp file) for any in-place text manipulation.
- Catalog file path: detector function bodies should NOT hardcode `traps/catalog.yaml`; use `${CKA_SIM_ROOT}/traps/catalog.yaml` (mirrors `$CKA_SIM_ROOT/lib/...` source path idiom from preflight.sh line 10).

---

### `cka-sim/lib/grade.sh` (helper-module + state-machine accumulator)

**Analog (primary):** `cka-sim/lib/cmd/doctor.sh` — for the failures-accumulator + `_pass`/`_fail` shape.
**Analog (secondary):** `cka-sim/lib/preflight.sh` — for the sourceable-helper module shape.

**Critical: `set -uo pipefail` (NOT `-e`)** (doctor.sh line 7):
```bash
set -uo pipefail  # NOT -e: doctor must run ALL checks and aggregate failures
```
**Apply verbatim** — D-05 explicitly says graders inherit doctor.sh's pattern. The comment is load-bearing; preserve it (different reason: "graders must report ALL mistakes per drill" rather than "all preflight checks").

**Accumulator + pass/fail dispatch pattern** (doctor.sh lines 18-21):
```bash
failures=0

_pass() { ok "$*"; }
_fail() { err "$*"; failures=$(( failures + 1 )); }
```
Apply to grade.sh as the conceptual seed. D-06 expands this to:
```bash
declare -ag CKA_SIM_GRADE_FAILS=()
declare -ag CKA_SIM_GRADE_PASSES=()
declare -ag CKA_SIM_GRADE_TRAPS=()
declare -gi CKA_SIM_GRADE_TOTAL=0
declare -gi CKA_SIM_GRADE_PASSED=0
```
Use `declare -ag` (global array) so accumulators survive across multiple sourced grader files.

**Source helpers from analog** (doctor.sh lines 9-16):
```bash
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"
# shellcheck source=../preflight.sh disable=SC1091  -- (replace with traps.sh)
source "$CKA_SIM_ROOT/lib/traps.sh"
```
grade.sh sources traps.sh (catalog map needed by `record_trap`'s validator per D-16); both grade.sh and traps.sh source colors+log.

**Live `✓` / `✗` per-assertion to stderr** (log.sh lines 12-14):
```bash
ok()      { printf '%s✓%s %s\n' "$GREEN" "$NC" "$*" >&2; }
err()     { printf '%s✗%s %s\n' "$RED" "$NC" "$*" >&2; }
```
Reuse via `cka_sim::log::ok` / `cka_sim::log::err` — but note current log.sh exports them as bare names (`ok`, `err`). **Specific difference:** CONTEXT canonical_refs explicitly use namespaced spellings `cka_sim::log::ok`/`cka_sim::log::err`. Either (a) add namespaced aliases to log.sh OR (b) keep using bare `ok`/`err` (matches current Phase 1 reality). Recommendation: keep bare names in grade.sh body (no log.sh edits in Phase 2); planner may flag a follow-up to add namespaced shims.

**Aggregate-final-result pattern** (doctor.sh lines 108-117):
```bash
printf '\n' >&2
if (( failures == 0 )); then
  ok "all checks passed — cluster is ready for drill/exam"
  exit 0
else
  err "$failures check(s) failed — address the issues above and re-run 'cka-sim doctor'"
  exit 1
fi
```
Apply to `cka_sim::grade::emit_result`:
- Stderr: live status already done.
- **Stdout (NEW behaviour, no analog)** per D-07: `printf 'SCORE: %d/%d\n' "$CKA_SIM_GRADE_PASSED" "$CKA_SIM_GRADE_TOTAL"` — note `printf` to stdout (no `>&2`), distinguishes the parseable result from the human status.
- Loop trap accumulator and `printf 'Trap %d: %s: %s\n' "$n" "$name" "$desc"` (also stdout, no `>&2`).
- Exit 0 iff `PASSED == TOTAL && ${#CKA_SIM_GRADE_TRAPS[@]} == 0`, else 1.

**Specific differences from analog:**
- doctor.sh uses local `failures=0`; grade.sh uses `declare -g` globals so multiple sourced grader files share one accumulator.
- doctor.sh writes ALL output to stderr (preflight is human-only); grade.sh writes status to stderr but `SCORE:` and `Trap N:` lines to **stdout** (Phase 7 aggregator parses these — D-07).
- doctor.sh exits at end-of-file; grade.sh's emit_result is a callable function — graders source grade.sh, run assertions, then explicitly call `cka_sim::grade::emit_result` at the end.
- doctor.sh has no trap concept; grade.sh's `record_trap` performs runtime validation against the catalog map (D-16) and dies on unknown id (use `die` from log.sh).

---

### `cka-sim/traps/catalog.yaml` (yaml-data)

**Analog (style only, not schema):** `skeletons/networkpolicy.yaml` — for inline gotcha comments + `apiVersion`/`kind` quoting style.
**No structural analog exists** in the repo (this is the first non-Kubernetes-resource YAML file).

**YAML style facts to apply** (from CONVENTIONS.md "YAML manifest style"):
- 2-space indent.
- No leading `---`.
- Inline gotcha comments encouraged (CONVENTIONS.md line 117).
- Strings with special chars use double quotes; `severity` enum values stay unquoted (`info`, `warn`, `error` — like other `string` enum values in `skeletons/`).
- LF line endings (`.gitattributes`).

**Schema reference:** the canonical entry shape is in CONTEXT.md `<specifics>` lines 161-180. Planner copies that block as the seed entry; lint-traps.sh enforces it.

**Specific differences from analog:**
- Not a Kubernetes manifest — no `apiVersion`/`kind`/`metadata`. Top-level key is `traps:` (a list).
- Field order per D-13: `id, name, description, remediation_hint, severity, domain, source, references` — keep this order across all 8 entries for diff/lint readability.
- All 8 IDs must come from REQUIREMENTS.md GRADE-05 verbatim (CONTEXT canonical_refs).

---

### `cka-sim/tests/bin/kubectl` (PATH-shadow stub)

**Analog:** `cka-sim/bin/cka-sim` (router) — argv-dispatch case statement.

**Imports / shebang / set pattern** — match `cka-sim/bin/cka-sim`:
```bash
#!/bin/bash
set -euo pipefail
```
**Specific difference:** `cka-sim/bin/cka-sim` resolves `CKA_SIM_ROOT` from its own location; this stub instead reads `CKA_SIM_TEST_FIXTURES_DIR` (exported by `tests/run.sh`) — stub does NOT need to know the repo root.

**Argv-dispatch case-statement pattern** (`cka-sim/bin/cka-sim` lines 89-94, paraphrased per Phase 1 CONTEXT specifics block):
```bash
cmd="${1:-help}"
case "$cmd" in
  -h|--help|help)    shift || true; exec "$CKA_SIM_ROOT/lib/cmd/help.sh" "$@" ;;
  bootstrap|doctor|list|version|drill|exam|score)
                     shift; exec "$CKA_SIM_ROOT/lib/cmd/$cmd.sh" "$@" ;;
  *) die "unknown subcommand: $cmd — run 'cka-sim --help'" ;;
esac
```
Apply to stub:
```bash
verb="${1:-}"
case "$verb" in
  get)         shift; _stub_dispatch_get "$@" ;;
  describe)    shift; _stub_dispatch_describe "$@" ;;
  auth)        shift; _stub_dispatch_auth "$@" ;;   # auth can-i ...
  exec)        shift; _stub_dispatch_exec "$@" ;;
  *) printf 'kubectl-stub: unsupported verb %q\n' "$verb" >&2; exit 64 ;;
esac
```

**Specific differences from analog:**
- Cluster-router dispatches to other scripts; stub dispatches to in-file functions that fingerprint argv and `cat` a fixture file.
- Stub MUST NOT print to stderr on the happy path (real `kubectl` is silent). Errors (unsupported argv) print to stderr + exit non-zero (mirrors real `kubectl` UX).
- Stub fingerprint dispatcher (per D-09) — keep simple: case on common shapes (`get <res> -o json`, `auth can-i <verb> <res>`, `get --raw <path>`). Fingerprint = stable path under `$CKA_SIM_TEST_FIXTURES_DIR/<test-case>/<sanitized-argv>.json`.
- LF line endings — stub IS a `.sh`-shaped script even without `.sh` extension; ensure `.gitattributes` covers `cka-sim/tests/bin/*` (may need a one-line addition).

---

### `cka-sim/tests/lib/assert.sh` (helper-module, test-only)

**Analog:** `cka-sim/lib/log.sh`

**Module shape** (log.sh lines 1-9):
```bash
#!/bin/bash
# cka-sim/tests/lib/assert.sh — micro-assertions for bash unit cases
# Sourced by: every cka-sim/tests/cases/*.sh

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"
# shellcheck disable=SC1091
[[ -z "${RED+x}" ]] && source "$CKA_SIM_ROOT/lib/colors.sh"
```

**Single-printf-helper pattern** (log.sh lines 11-14):
```bash
ok()      { printf '%s✓%s %s\n' "$GREEN" "$NC" "$*" >&2; }
err()     { printf '%s✗%s %s\n' "$RED" "$NC" "$*" >&2; }
```
Apply to assert.sh:
```bash
expect_eq() {
  local actual="$1" expected="$2" msg="${3:-expect_eq}"
  if [[ "$actual" == "$expected" ]]; then
    printf '%s  ✓ %s%s\n' "$GREEN" "$msg" "$NC" >&2
    return 0
  fi
  printf '%s  ✗ %s — expected %q got %q%s\n' "$RED" "$msg" "$expected" "$actual" "$NC" >&2
  return 1
}
expect_empty()    { ... }   # same shape, asserts "$1" is empty
expect_contains() { ... }   # same shape, asserts "$2" appears in "$1"
```

**Specific differences from analog:**
- `assert.sh` returns 1 on failure (does NOT `die`) — caller (the case file) accumulates failures, similar to doctor.sh's `_fail`. This matches D-05's grader philosophy applied to test land.
- log.sh helpers don't return values; assert.sh helpers do.
- assert.sh lives under `cka-sim/tests/lib/`, not `cka-sim/lib/` — separate import path keeps prod/test boundary clean.

---

### `cka-sim/tests/fixtures/**/*.json` (test-fixtures)

**No analog in repo.** First fixture corpus.

**Pattern guidance:**
- Directory per detector / helper: `tests/fixtures/<scenario-id>/{hit,miss,benign}.json`.
- File contents = literal `kubectl get -o json` output captured against a real cluster (or hand-crafted minimal JSON).
- LF line endings — extend `.gitattributes` if needed: `cka-sim/tests/fixtures/**/*.json text eol=lf`.
- No comments (JSON has none) — provenance commentary belongs in `cka-sim/tests/fixtures/README.md` (one-line entry per fixture).

**Specific differences from any analog:** none — net-new convention. Naming `{hit,miss,benign}.json` mirrors D-12's three-scenario coverage exactly; planner enforces this.

---

### `cka-sim/tests/cases/*.sh` (test-case files)

**Analog:** `cka-sim/lib/cmd/doctor.sh` (linear-check shape with named sections + assertions).

**Header / source-helpers pattern** (doctor.sh lines 1-16):
```bash
#!/bin/bash
# tests/cases/traps_default-sa-used.sh — verifies detect_default_sa_used fires + does not false-fire

set -uo pipefail   # NO -e — accumulate within the case (run.sh aggregates across cases)

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?must be set by tests/run.sh}"

# shellcheck source=../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"
```

**Sectioned-assertion-block pattern** (doctor.sh lines 25-32):
```bash
# ---------- Check 1: known-bad fixture fires the trap ----------
export CKA_SIM_TEST_CURRENT="default-sa-used/hit"
result=$(cka_sim::trap::detect_default_sa_used exercise-99 webapp || true)
expect_eq "$result" "default-sa-used" "hit fixture fires trap"
```
Apply 3 sections per case file: `hit` / `miss` / `benign` for detectors; `happy` / `sad` for assertion helpers.

**Specific differences from analog:**
- doctor.sh exits at file end; case files do NOT exit — they `return` from the sourced context (run.sh sources each).
- doctor.sh uses `_pass`/`_fail` locals; case files use `expect_eq`/`expect_empty`/`expect_contains` from `assert.sh` (run.sh inspects their return codes via `$?`).
- Case files set `$CKA_SIM_TEST_CURRENT` to point the kubectl-stub at the right fixture sub-directory before each detector call (paired with D-09's argv-fingerprint dispatch).

---

### `cka-sim/tests/run.sh` (test-runner)

**Analog (primary):** `cka-sim/lib/cmd/doctor.sh` — for the aggregate-failures structure.
**Analog (secondary):** `scripts/validate-local.sh` — for the `find ... -print0 | while read -r -d ''` walk.

**Header / set / source pattern** (doctor.sh lines 1-16):
```bash
#!/bin/bash
# cka-sim/tests/run.sh — bash unit-test runner for traps.sh + grade.sh
# Walks tests/cases/*.sh, sources each, reports pass/fail counts.

set -uo pipefail   # NOT -e: continue past failing cases to aggregate results

CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CKA_SIM_ROOT

# shellcheck source=../lib/colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../lib/log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"
```

**REPO_ROOT-from-script idiom** (validate-local.sh line 13, bootstrap.sh implicit pattern):
```bash
CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
```
Note: `tests/run.sh` lives at `cka-sim/tests/run.sh`, so `dirname/..` resolves to `cka-sim/` — exactly the value `CKA_SIM_ROOT` should hold.

**Find-and-source walk** (validate-local.sh lines 27-35):
```bash
total=0; failed=0
while IFS= read -r -d '' case_file; do
  total=$(( total + 1 ))
  header "$(basename "$case_file" .sh)"
  if ( source "$case_file" ); then
    ok "case passed"
  else
    err "case failed (rc=$?)"
    failed=$(( failed + 1 ))
  fi
done < <(find "$CKA_SIM_ROOT/tests/cases" -name '*.sh' -print0 | sort -z)
```
Note `( source ... )` in subshell — case file failures must NOT corrupt run.sh's accumulator state.

**Aggregate-result pattern** (doctor.sh lines 108-117):
```bash
printf '\n' >&2
if (( failed == 0 )); then
  ok "all $total case(s) passed"
  exit 0
else
  err "$failed of $total case(s) failed"
  exit 1
fi
```

**Specific differences from analogs:**
- run.sh prepends `tests/bin/` to PATH BEFORE sourcing case files (D-09): `export PATH="$CKA_SIM_ROOT/tests/bin:$PATH"`. Neither doctor.sh nor validate-local.sh manipulate PATH.
- run.sh exports `CKA_SIM_TEST_FIXTURES_DIR="$CKA_SIM_ROOT/tests/fixtures"` so case files + the kubectl stub can resolve fixtures.
- validate-local.sh accumulates count of bad files; run.sh accumulates count of bad **cases** (each case may run many `expect_*` calls).

---

### `cka-sim/scripts/test.sh` (orchestrator wrapper)

**Analog (primary):** `cka-sim/lib/cmd/bootstrap.sh` — for the linear `info`/`ok` step orchestration.
**Analog (secondary):** `scripts/validate-local.sh` — for the repo-root + multi-stage validator pattern.

**Header / set pattern** (bootstrap.sh lines 19-30):
```bash
#!/bin/bash
# cka-sim/scripts/test.sh — orchestrates lint-traps + bash unit-test runner.
# Local: bash cka-sim/scripts/test.sh
# CI: invoked by .github/workflows/validate.yml's bash-tests job.

set -euo pipefail   # validation-script style, fail fast

CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CKA_SIM_ROOT

# shellcheck source=../lib/colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../lib/log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"
```

**Linear-step `info` / `ok` orchestration** (bootstrap.sh lines 52-87):
```bash
header "cka-sim test"

info "step 1: lint trap catalog"
"$CKA_SIM_ROOT/scripts/lint-traps.sh"
ok "catalog lint passed"

info "step 2: run bash unit cases"
"$CKA_SIM_ROOT/tests/run.sh"
ok "all unit cases passed"

ok "test.sh complete"
```

**Specific differences from analog:**
- bootstrap.sh uses `set -euo pipefail` AND has `_confirm` interactivity; test.sh uses the same set-options but is non-interactive (no prompts — runs in CI).
- test.sh has no analog of bootstrap.sh's sudo / network steps — it is purely process-orchestration. Each step either succeeds (continues) or `set -e` aborts the script.
- Per D-11: NOT a `cka-sim` subcommand. Lives under `cka-sim/scripts/`, not `cka-sim/lib/cmd/`. Naming and location parity with bootstrap.sh is intentional.

---

### `cka-sim/scripts/lint-traps.sh` (lint-script)

**Analog:** `scripts/validate-local.sh`

**Header / colors / repo-root pattern** (validate-local.sh lines 1-13):
```bash
#!/bin/bash
# cka-sim/scripts/lint-traps.sh — schema + naming + path-existence lint for traps/catalog.yaml.
# Run before pushing; wired into cka-sim/scripts/test.sh and CI's bash-tests job.

set -euo pipefail

CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=../lib/colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
```

**Counters + fail-list pattern** (validate-local.sh lines 14-16, 27-36):
```bash
errors=0
checked=0

# walk every trap entry — pure-bash parser per D-04
while IFS= read -r entry; do
  checked=$(( checked + 1 ))
  # ... validate id / severity / domain / source / refs / required-fields ...
  if <bad>; then
    printf '%s  FAIL%s  trap[%d]: %s\n' "$RED" "$NC" "$checked" "$reason"
    errors=$(( errors + 1 ))
  else
    printf '%s  OK%s    trap[%d]: %s\n' "$GREEN" "$NC" "$checked" "$id"
  fi
done < <( <pure-bash catalog walker> )
```

**Final-result pattern** (validate-local.sh lines 53-60):
```bash
echo ""
if [ $errors -gt 0 ]; then
  printf '%s%d entr(ies) failed lint. Fix before pushing.%s\n' "$RED" "$errors" "$NC"
  exit 1
else
  printf '%sCatalog lint passed (%d entr(ies)).%s\n' "$GREEN" "$checked" "$NC"
  exit 0
fi
```

**Specific differences from analog:**
- validate-local.sh validates *.yaml syntax via `python3 yaml.safe_load_all`; lint-traps.sh validates **schema** (custom rules from D-13/D-14/D-15). Pure bash (per D-04) — no python, no yq.
- validate-local.sh walks files via `find`; lint-traps.sh walks **entries within one file** (the catalog). Use `awk`-based section splitter or in-bash state machine; reuse the parser code from `traps.sh`'s catalog parser to avoid two implementations.
- Path-existence checks (D-15(g)): for each `references[].kind == concerns-md|prior-art-exercise`, `[[ -e "$REPO_ROOT/$target" ]]` — note `$REPO_ROOT` is the repo root (one level up from `$CKA_SIM_ROOT`). Define both: `REPO_ROOT="$(cd "$CKA_SIM_ROOT/.." && pwd)"`.
- Seed-completeness check (D-15(h)): hardcoded array of the 8 expected IDs; verify each appears exactly once.
- Standalone — NOT folded into `scripts/validate-local.sh` (per D-15 explicit decision).

---

### `.github/workflows/validate.yml` (CI workflow — MODIFY)

**Analog:** the existing file itself (one job → two jobs).

**Existing `paths:` filter** (validate.yml lines 6-10, 13-17):
```yaml
paths:
  - 'skeletons/**'
  - 'exercises/**'
  - '**.yaml'
  - '**.yml'
```

**Modification 1 — extend `paths:`** to trigger on `cka-sim/**` changes:
```yaml
paths:
  - 'skeletons/**'
  - 'exercises/**'
  - 'cka-sim/**'        # NEW
  - '**.yaml'
  - '**.yml'
  - '**.sh'             # NEW — bash file changes should run bash-tests
```
Apply to both the `push:` and `pull_request:` blocks.

**Modification 2 — add `bash-tests` job after the existing `yamllint` job:**
```yaml
  bash-tests:
    name: Bash unit tests (traps + grade)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run cka-sim test suite
        run: bash cka-sim/scripts/test.sh
```

**Existing `yamllint` job pattern to mirror** (validate.yml lines 19-31):
```yaml
jobs:
  yamllint:
    name: YAML Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      ...
```

**Specific differences:**
- `bash-tests` uses no extra installs (jq is pre-installed on `ubuntu-latest`; no python required).
- Job name lower-case + hyphenated (`bash-tests`) — matches GHA convention seen in existing `yamllint` job (lower-case display name).
- Per D-11: this job is the ONLY new CI surface; do NOT add a third job, do NOT modify `validate-local.sh`.

---

## Shared Patterns

### Stderr-for-status / stdout-for-data
**Source:** `cka-sim/lib/log.sh` lines 11-14 + `cka-sim/lib/cmd/doctor.sh` line 7 comment.
**Apply to:** every new `.sh` in Phase 2.
**Rule:** Live progress / `✓` / `✗` / `header` go to stderr (existing log.sh helpers handle this). Parseable output (catalog content from traps.sh dump-helpers, `SCORE:` and `Trap N:` from grade.sh, fixture JSON from kubectl stub) goes to stdout. **Do not mix** — Phase 7's exam aggregator parses stdout (D-07).
```bash
# log.sh — already-correct pattern, reuse:
ok()      { printf '%s✓%s %s\n' "$GREEN" "$NC" "$*" >&2; }
# grade.sh emit_result — new pattern:
printf 'SCORE: %d/%d\n' "$CKA_SIM_GRADE_PASSED" "$CKA_SIM_GRADE_TOTAL"  # NO >&2
```

### `set -uo pipefail` for accumulators / `set -euo pipefail` for validators
**Source:** `cka-sim/lib/cmd/doctor.sh` line 7 vs `scripts/validate-local.sh` line 6.
**Apply to:**
- `-uo pipefail` (NO `-e`): `grade.sh`, `tests/cases/*.sh`, `tests/run.sh` — these need to keep running past assertion failures.
- `-euo pipefail` (with `-e`): `tests/bin/kubectl`, `scripts/test.sh`, `scripts/lint-traps.sh` — these should fail fast on the first error.
- Sourceable libs with no top-level commands: `traps.sh`, `tests/lib/assert.sh` — set neither `-e` nor `-u` at file top (would corrupt sourcing-shell state), but use defensive `${var:?}` checks for required env vars. Mirror `cka-sim/lib/log.sh` line 7 (`: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"`).

### REPO_ROOT-from-script idiom
**Source:** `scripts/validate-local.sh` line 13.
**Apply to:** `cka-sim/scripts/test.sh`, `cka-sim/scripts/lint-traps.sh`, `cka-sim/tests/run.sh`.
```bash
CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CKA_SIM_ROOT
```
Note path arithmetic differs by location:
- `cka-sim/scripts/foo.sh` → `dirname/..` = `cka-sim/` ✓
- `cka-sim/tests/run.sh` → `dirname/..` = `cka-sim/` ✓
- `cka-sim/tests/cases/foo.sh` → does NOT define `CKA_SIM_ROOT`; inherits from run.sh's exported value.
- `cka-sim/lib/*.sh` and `cka-sim/lib/cmd/*.sh` → require `CKA_SIM_ROOT` already set (existing convention from log.sh line 7).

### Function namespacing
**Source:** `cka-sim/lib/preflight.sh` (`cka_sim::preflight::*`), `cka-sim/lib/log.sh` (bare names — exception).
**Apply to:**
- `traps.sh` → `cka_sim::trap::detect_<id>` (one per trap), plus catalog-parser helpers `cka_sim::trap::_load_catalog`, `cka_sim::trap::id_exists`, etc. (underscore-prefix on private helpers, mirroring no current convention but a reasonable extension).
- `grade.sh` → `cka_sim::grade::assert_<thing>`, `cka_sim::grade::record_trap`, `cka_sim::grade::emit_result`, `cka_sim::grade::_increment_total` (private).
- `tests/lib/assert.sh` → bare names `expect_eq`, `expect_empty`, `expect_contains` (test land matches log.sh's convenience-name convention; not part of the prod-namespaced surface).

### LF line endings + `.gitattributes`
**Source:** `.gitattributes` (already in repo).
**Apply to:** all new `.sh`, `.yaml`, `.json` files. Existing `.gitattributes` covers `*.sh`. **Specific extension:** verify (and add if missing) coverage for `cka-sim/tests/bin/kubectl` (no extension) and `cka-sim/tests/fixtures/**/*.json`. Suggested entries the planner should propose:
```
cka-sim/tests/bin/* text eol=lf
cka-sim/tests/fixtures/**/*.json text eol=lf
```

### `: "${VAR:?msg}"` defensive check on sourceable libs
**Source:** `cka-sim/lib/log.sh` line 7, `cka-sim/lib/preflight.sh` line 5, `cka-sim/lib/fileblock.sh` line 14.
**Apply to:** every new sourceable lib (`traps.sh`, `grade.sh`, `tests/lib/assert.sh`).
```bash
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"
```

### RFC 1123 naming validation regex
**Source:** CONTEXT.md D-15(b) (no in-repo analog).
**Apply to:** lint-traps.sh entry-id check; can also be reused as a runtime guard in `record_trap` (D-16).
```bash
[[ "$id" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] && (( ${#id} <= 63 ))
```
This regex IS the entire TRIP-07 contract. Define once in lint-traps.sh and (per `record_trap`'s D-16 runtime check) in traps.sh; consider extracting to `traps.sh` so lint-traps.sh sources it (single source of truth, mirrors how preflight.sh helpers are reused by both bootstrap.sh and doctor.sh).

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `cka-sim/traps/catalog.yaml` | yaml-data | static | First non-Kubernetes-resource YAML in repo; schema is novel. Style guidance comes from CONVENTIONS.md "YAML manifest style" + `skeletons/networkpolicy.yaml` inline-comment idiom. |
| `cka-sim/tests/fixtures/**/*.json` | test-fixture | static | First JSON fixture corpus in the repo. Zero current files match. |
| `cka-sim/tests/bin/kubectl` | cli-script (PATH-shadow stub) | request-response | No analog of "PATH-shadowing executable that mimics another CLI" exists. Closest cousin is `cka-sim/bin/cka-sim`'s case-statement dispatcher. |

For these three, the planner should reference RESEARCH.md and CONTEXT.md `<specifics>` directly; no excerpt-copying applies.

---

## Metadata

**Analog search scope:** `cka-sim/lib/`, `cka-sim/lib/cmd/`, `cka-sim/bin/`, `scripts/`, `.github/workflows/`, `skeletons/`, `.gitattributes`.
**Files scanned:** 9 (log.sh, colors.sh, preflight.sh, fileblock.sh, bootstrap.sh, doctor.sh, validate-local.sh, validate.yml, plus structural inspection of the repo via STRUCTURE.md).
**Pattern extraction date:** 2026-05-09.
**Phase 1 carry-forward references:** `.planning/phases/01-cluster-bootstrap-runner-skeleton/01-CONTEXT.md` (decisions 1-10).

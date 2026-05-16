# Phase 7: Exam Mode + Blueprint Alpha + Reporting — Pattern Map

**Mapped:** 2026-05-13
**Files analyzed:** 13 (8 new lib/content + 3 modified + 2 test/fixture groups)
**Analogs found:** 12 / 13 (1 new pattern: timer subshell)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `cka-sim/lib/cmd/exam.sh` | command/orchestrator | request-response + signal-driven | `cka-sim/lib/cmd/drill.sh` | exact role, richer flow |
| `cka-sim/lib/cmd/score.sh` | command (read-only renderer) | file-I/O | `cka-sim/lib/cmd/drill.sh` (header + main shell) | role-match, simpler |
| `cka-sim/lib/cmd/list.sh` (modify) | command (lister) | file-I/O | `cka-sim/lib/cmd/drill.sh` main shell | role-match |
| `cka-sim/lib/exam-state.sh` | helper module (JSON state) | CRUD (file-backed) | `cka-sim/lib/setup.sh` | helper-module shape |
| `cka-sim/lib/exam-blueprint.sh` | helper module (YAML walker) | transform | `cka-sim/lib/cmd/drill.sh::_parse_manifest` | exact pattern |
| `cka-sim/lib/exam-report.sh` | helper module (Markdown renderer) | transform | `cka-sim/lib/cmd/drill.sh::render_header` | role-match (header rendering) |
| `cka-sim/lib/exam-timer.sh` | helper module (background subshell) | event-driven | none (new pattern) | no analog |
| `exams/blueprint-alpha/manifest.yaml` | content (YAML) | static | `cka-sim/packs/storage/manifest.yaml` | role-match (different schema) |
| `exams/blueprint-alpha/README.md` | content (Markdown) | static | `cka-sim/packs/storage/01-pvc-binding/metadata.yaml` peer docs | weak; structural model only |
| `cka-sim/scripts/lint-packs.sh` (extend) | lint pass | transform | existing passes A–G inside same file | exact (in-file extension) |
| `cka-sim/tests/exam/*.sh` | unit/integration test cases | test | `cka-sim/tests/cases/drill_load_pack.sh`, `lint_packs_metadata.sh` | exact |
| `cka-sim/tests/fixtures/exam/mock-pack-alpha/*` | test fixture | static | `cka-sim/tests/fixtures/lint-packs/good/`, real pack `01-pvc-binding/` | role-match |
| `cka-sim/tests/run.sh` (extend) | test harness | n/a (one-line glob change) | itself, lines 25–44 | self |

---

## Pattern Assignments

### `cka-sim/lib/cmd/exam.sh` (command, request-response + signal)

**Analog:** `cka-sim/lib/cmd/drill.sh`
**Why:** Same role (sub-command orchestrator dispatched by `bin/cka-sim`); same `reset → setup → prompt → grade` skeleton, just looped 17× with signal traps and a timer.

**File header + sourcing pattern** (drill.sh:1–23):
```bash
#!/bin/bash
set -euo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"
# shellcheck source=../colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
source "$CKA_SIM_ROOT/lib/log.sh"
source "$CKA_SIM_ROOT/lib/preflight.sh"
```
exam.sh additionally sources `lib/exam-state.sh`, `lib/exam-blueprint.sh`, `lib/exam-report.sh`, `lib/exam-timer.sh`.

**Function namespacing + state globals** (drill.sh:27–34):
```bash
declare -g CKA_SIM_PACK_ID="" CKA_SIM_QUESTION_ID="" CKA_SIM_QUESTION_DIR=""
declare -g CKA_SIM_LAB_NS="" CKA_SIM_QUESTION_INDEX=""
```
Mirror with `CKA_SIM_EXAM_TS`, `CKA_SIM_EXAM_BLUEPRINT_ID`, `CKA_SIM_EXAM_DEADLINE_TS`, `CKA_SIM_EXAM_CUR_IDX`, `CKA_SIM_TIMER_PID`.

**EXIT-trap registration discipline** (drill.sh:289–290 in main, NOT inside the cleanup body):
```bash
trap cka_sim::drill::cleanup EXIT
```
Phase 7 adds `trap 'cka_sim::exam::on_int' INT`, `trap 'cka_sim::exam::on_tstp' TSTP`, `trap 'cka_sim::exam::on_cont' CONT` in `start_new` and `resume`.

**Cleanup body shape** (drill.sh:225–233): runs `reset.sh`, removes tempfiles, propagates `$rc`. Phase 7 cleanup loops over every set-up question's `reset.sh` and additionally `cka_sim::timer::stop`.

**Source-vs-execute guard** (drill.sh:336–338):
```bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
```
Required so `tests/exam/*.sh` can `source` exam.sh and call helpers without entering main.

---

### `cka-sim/lib/cmd/score.sh` (command, file-I/O)

**Analog:** `cka-sim/lib/cmd/drill.sh` shell + `cka_sim::drill::render_header` (drill.sh:242–268)
**Why:** Same sub-command shape, no cluster interaction, calls `cka_sim::report::render` from `lib/exam-report.sh` if `<ts>.md` is missing. Per D-26.

**Reuse:** sourcing block from drill.sh:18–23 (drop `preflight.sh`; score is offline).

---

### `cka-sim/lib/cmd/list.sh` (modify — add `history` subcommand)

**Analog:** existing `list.sh` stub + drill.sh main()
**Why:** Phase 1 stub just prints fixed lines; Phase 7 adds `case "${1:-}"` dispatch matching `packs|blueprints|history`. Walks `~/.cka-sim/sessions/*.json` via `cka_sim::state::list_sessions` and renders a 5-column table (D-27 + specifics line "Started, Blueprint, Score, Pass/Fail, Status").

---

### `cka-sim/lib/exam-state.sh` (helper module, file-backed CRUD)

**Analog:** `cka-sim/lib/setup.sh`
**Why:** Same shape — a non-executable helper module sourced from a command file. Functions namespaced `cka_sim::setup::*`; mirror with `cka_sim::state::*`.

**Module header** (setup.sh:1–10):
```bash
# cka-sim/lib/setup.sh — shared setup helpers for question authoring.
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"
source "$CKA_SIM_ROOT/lib/log.sh"
```
Module is sourced, not executed; it does NOT `set -euo pipefail` (parent does).

**Atomic-write pattern** (drill.sh:316–325 — the load-bearing precedent for `state::save`):
```bash
CKA_SIM_DRILL_TMP=$(mktemp -t cka-sim-drill-XXXXXX.md)
bash "$CKA_SIM_QUESTION_DIR/grade.sh" > "$CKA_SIM_DRILL_TMP" || grade_rc=$?
{ render_header "$report"; cat "$CKA_SIM_DRILL_TMP"; } > "$report.partial"
mv "$report.partial" "$report"
```
state.sh's `save` follows: `mktemp` → `jq -n … > "$tmp"` → `jq empty "$tmp"` validation → `mv -f "$tmp" "$session_path"`. RESEARCH §"Atomic JSON write" line 244–258 expands.

---

### `cka-sim/lib/exam-blueprint.sh` (helper module, YAML walker)

**Analog:** `cka-sim/lib/cmd/drill.sh::_parse_manifest` (drill.sh:55–112)
**Why:** Pure-bash YAML walker, exactly the precedent. Blueprint manifest has the same `key: value` + `- key: value` indentation grammar; just a different keyset (`exam.id`, `weighting.*`, `questions[].pack`, `questions[].slug`).

**Walker idiom** (drill.sh:62–111):
```bash
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "${line//[[:space:]]/}" ]] && continue
  [[ "${line#"${line%%[![:space:]]*}"}" == "#"* ]] && continue
  if [[ "$line" =~ ^questions:[[:space:]]*$ ]]; then
    in_questions=1; continue
  fi
  if (( in_questions == 0 )); then
    if [[ "$line" =~ ^\ \ ([a-z]+):\ (.+)$ ]]; then
      value="${BASH_REMATCH[2]}"
      # strip surrounding quotes …
    fi
  else
    if [[ "$line" =~ ^\ \ -\ pack:\ (.+)$ ]]; then …
    elif [[ "$line" =~ ^\ \ \ \ slug:\ (.+)$ ]]; then …
    fi
  fi
done < "$manifest_path"
```
Quote-stripping idiom (drill.sh:78–82) carries over verbatim. `_strip_quotes` from lint-packs.sh:34 is the alternative single-call helper.

**Validation helper** (`cka_sim::blueprint::validate`) mirrors `cka_sim::drill::_validate_picked` (drill.sh:123–135) — die-on-bad-input, echo result on stdout, no log spam.

---

### `cka-sim/lib/exam-report.sh` (helper module, Markdown rendering)

**Analog:** `cka-sim/lib/cmd/drill.sh::render_header` (drill.sh:242–268)
**Why:** Same heredoc-emit-Markdown shape; same convention of computing values into local vars then a single `cat <<EOF` block.

**Heredoc renderer** (drill.sh:251–267):
```bash
cat <<EOF
# cka-sim drill report

- timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- pack: $CKA_SIM_PACK_ID
- question-id: $CKA_SIM_QUESTION_ID
…
EOF
```
Phase 7 splits into `cka_sim::report::header`, `::domain_table`, `::trap_table`, `::next_drills`, `::question_detail` — each a heredoc block. Final `render` concatenates via `{ header; domain_table; trap_table; … } > "$out.partial"; mv "$out.partial" "$out"` (atomic-write idiom from drill.sh:323–325).

**Sort discipline** (RESEARCH Pitfall 8): every percentage sort uses `LC_ALL=C sort -t '|' -k N -g`.

---

### `cka-sim/lib/exam-timer.sh` (helper module, background subshell)

**Analog:** none in this codebase.
**Why:** No prior phase forked a long-running subshell. Pattern is documented in RESEARCH §"Timer subshell" (lines 130–156). Planner uses RESEARCH excerpt as ground truth.

Notes for the planner:
- Module exposes `cka_sim::timer::spawn <deadline_ts>` (forks `redraw_loop &`, captures `$!` into `CKA_SIM_TIMER_PID`) and `cka_sim::timer::stop` (kill TERM + wait).
- The redraw loop writes to **stdout** at row `$(tput lines)-1` using `tput sc`/`cup`/`el`/`rc`. Stderr is reserved for grader output; mixing the two corrupts the status line.
- No traps inside the subshell; parent's EXIT trap kills it.

---

### `exams/blueprint-alpha/manifest.yaml` (content)

**Analog:** `cka-sim/packs/storage/manifest.yaml`
**Why:** Same author-readable YAML shape; both consumed by a pure-bash walker. Different keyset per D-18.

**Pack manifest skeleton** (`packs/storage/manifest.yaml:1–9`):
```yaml
pack:
  id: storage
  domain: storage
  weight: 10
  description: "…"
questions:
  - id: storage-pvc-binding
    path: 01-pvc-binding
    estimatedMinutes: 8
```

**Blueprint manifest target shape** (per D-18, mirrors the indentation grammar):
```yaml
exam:
  id: blueprint-alpha
  version: "1.0"
  durationMinutes: 120
  estimatedMinutesBudget: [120, 130]
  weighting:
    storage: 10
    workloads-scheduling: 15
    services-networking: 20
    cluster-architecture: 25
    troubleshooting: 30
  disclaimer: "Not real CKA exam content; independently authored. Targets v1.35 CKA blueprint."
questions:
  - pack: storage
    slug: 01-pvc-binding
  # … 16 more (RESEARCH §"Final draw — sum 129 min")
```
Field ordering mirrors `pack:` block style: 2-space indent, key-then-value, no anchors/aliases (the walker doesn't expand them).

---

### `exams/blueprint-alpha/README.md` (content)

**Analog:** none direct. Closest-shape file is the `description:` field of `cka-sim/packs/storage/manifest.yaml:5`.
**Required content (D-20 + MOCK-03):** must contain literal string `"Not real CKA exam content; independently authored"`. Phase 7 lint pass H asserts this.
**Sections to mirror from CONTEXT.md:** 1) what blueprint-alpha is, 2) MOCK-03 disclaimer, 3) D-15 deviation note (estimatedMinutes budget [120,130] not [110,120]), 4) `cka-sim exam blueprint-alpha` invocation example.

---

### `cka-sim/scripts/lint-packs.sh` (modify — add pass H)

**Analog:** the file's own existing passes A–G (lint-packs.sh:40–219).
**Why:** Phase 7 explicitly extends — does NOT create a separate script (CONTEXT.md line 158).

**Pass header idiom** (lint-packs.sh:40, 53, 65, 73, 86, 156, 185 — every pass uses this):
```bash
info "pass H: blueprint manifest lint"
EXAMS_DIR="${CKA_SIM_LINT_EXAMS_DIR:-$REPO_ROOT/exams}"
if [[ ! -d "$EXAMS_DIR" ]]; then
  warn "no exams dir at $EXAMS_DIR — skipping pass H"
else
  while IFS= read -r manifest; do
    cka_sim::lint_blueprint "$manifest"
  done < <(find "$EXAMS_DIR" -mindepth 2 -name manifest.yaml)
fi
```
Mirror error-counting and `errors=$(( errors + 1 ))` accumulator (lint-packs.sh:37, 46, etc.). Reuse `_strip_quotes` (line 34) and `_in_array` (line 35) helpers; do not redefine.

**Test-mode override pattern** (lint-packs.sh:19): `EXAMS_DIR="${CKA_SIM_LINT_EXAMS_DIR:-…}"` so `tests/exam/lint_blueprint_*.sh` can point lint at fixtures.

---

### `cka-sim/tests/exam/*.sh` (~10 case files)

**Analog:** `cka-sim/tests/cases/drill_load_pack.sh` (parsing/state tests) and `cka-sim/tests/cases/lint_packs_metadata.sh` (lint tests).

**Test-case header** (drill_load_pack.sh:1–17):
```bash
#!/bin/bash
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?must be set by run.sh}"
source "$CKA_SIM_ROOT/tests/lib/assert.sh"
source "$CKA_SIM_ROOT/lib/cmd/drill.sh"
set +e   # drill.sh enables -e; tests want accumulate-failures semantics
case_failed=0
…
exit "$case_failed"
```
Phase 7 cases source `lib/cmd/exam.sh` or `lib/exam-state.sh`/`exam-blueprint.sh`/`exam-report.sh` and use `expect_eq` from `tests/lib/assert.sh`.

**Subprocess + tempdir + run-the-script pattern** (lint_packs_metadata.sh:10–24): `mktemp -d`, scaffold a fixture tree, invoke the script under test with the env override, capture combined stdout/stderr+rc with the `out=$(…; printf '\nRC:%d' $?)` idiom, grep for expected error strings. Reuse for `tests/exam/lint_blueprint_*.sh` and any test that drives `cka-sim score` end-to-end.

---

### `cka-sim/tests/fixtures/exam/mock-pack-alpha/`

**Analog:** the actual `cka-sim/packs/<pack>/<NN-slug>/` tree (e.g. `cka-sim/packs/storage/01-pvc-binding/`) plus the lint fixture `cka-sim/tests/fixtures/lint-packs/good/`.
**Why:** Each fixture question dir must satisfy lint pass D (6 files: `metadata.yaml`, `question.md`, `setup.sh`, `grade.sh`, `reset.sh`, `ref-solution.sh`; 4 scripts executable) so the blueprint walker resolves `(pack, slug)` correctly.

**Mock grade.sh requirement (RESEARCH §"Mock graders" line 28):** each emits a deterministic `SCORE: N/M` block and known `Trap N: <id>: <description>` lines so the report golden test is reproducible.

---

### `cka-sim/tests/run.sh` (extend)

**Analog:** itself, lines 25 and 44.
**Change:** `cases_dir="$CKA_SIM_ROOT/tests/cases"` → discover both `tests/cases/` and `tests/exam/`. Simplest patch:
```bash
while IFS= read -r -d '' case_file; do
  …
done < <(find "$CKA_SIM_ROOT/tests/cases" "$CKA_SIM_ROOT/tests/exam" \
            -name '*.sh' -print0 2>/dev/null | sort -z)
```
Existing structure (subshell-source, accumulate `failed`, exit-on-aggregate) is unchanged.

---

## Shared Patterns

### Logging + colors
**Source:** `cka-sim/lib/log.sh:11–22`, `cka-sim/lib/colors.sh`
**Apply to:** every new lib/cmd file and helper module
```bash
info()   { printf '  %s\n' "$*" >&2; }
ok()     { printf '%s✓%s %s\n' "$GREEN" "$NC" "$*" >&2; }
warn()   { printf '%s!%s %s\n' "$YELLOW" "$NC" "$*" >&2; }
err()    { printf '%s✗%s %s\n' "$RED" "$NC" "$*" >&2; }
die()    { err "$*"; exit 1; }
header() { …banner… }
```
All log output to **stderr** (log.sh:5 contract). Phase 7's timer status line is the one stdout exception.

### Atomic file write
**Source:** `cka-sim/lib/cmd/drill.sh:316–325`
**Apply to:** `lib/exam-state.sh::save`, `lib/exam-report.sh::render`
```bash
tmp=$(mktemp -t cka-sim-XXXXXX)
… write to "$tmp" …
mv "$tmp" "$final_path"
```
Validate JSON before `mv` (`jq empty "$tmp"` per RESEARCH §"Atomic JSON write" line 256). On any failure: `rm -f "$tmp"; die`.

### EXIT-trap discipline (Phase 3 Pitfall 2)
**Source:** `cka-sim/lib/cmd/drill.sh:289` (registration in main()) and 225–233 (handler body)
**Apply to:** `lib/cmd/exam.sh`
- Register `trap` from `main()` / `start_new()` / `resume()`, NOT inside the handler.
- Handler captures `local rc=$?` first thing, runs cleanup, `exit "$rc"` last. Phase 7 cleanup additionally kills `$CKA_SIM_TIMER_PID`.

### Pure-bash YAML walker (no jq for reads of repo-controlled YAML)
**Source:** `cka-sim/lib/cmd/drill.sh:55–112` and `cka-sim/lib/traps.sh::60–114`
**Apply to:** `lib/exam-blueprint.sh`, lint-packs.sh pass H.
**JSON state, by contrast, uses jq exclusively** (BOOT-07 doctor preflight already requires jq).

### Test case shape
**Source:** `cka-sim/tests/cases/drill_load_pack.sh:1–17`, `cka-sim/tests/lib/assert.sh`
**Apply to:** every `tests/exam/*.sh`. `set -uo pipefail` (NOT `-e`), `set +e` after sourcing the unit-under-test if it enables `-e`, accumulate failures into `case_failed`, `exit "$case_failed"` at the bottom.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `cka-sim/lib/exam-timer.sh` | helper | event-driven (background subshell) | First long-running subshell in the codebase. RESEARCH §"Timer subshell" (lines 130–156) supplies the canonical pattern; planner cites RESEARCH directly. |

---

## Metadata

**Analog search scope:** `cka-sim/lib/cmd/`, `cka-sim/lib/`, `cka-sim/scripts/`, `cka-sim/tests/cases/`, `cka-sim/tests/fixtures/`, `cka-sim/packs/storage/`
**Files Read:** drill.sh, exam.sh (stub), score.sh (stub), list.sh (stub), lint-packs.sh, setup.sh (head), preflight.sh (head), log.sh, run.sh, drill_load_pack.sh (head), lint_packs_metadata.sh (head), packs/storage/manifest.yaml, packs/storage/01-pvc-binding/metadata.yaml, packs/storage/01-pvc-binding/setup.sh (head)
**Files scanned (Glob):** `cka-sim/tests/**/*.sh` (full listing)
**Pattern extraction date:** 2026-05-13

## PATTERN MAPPING COMPLETE

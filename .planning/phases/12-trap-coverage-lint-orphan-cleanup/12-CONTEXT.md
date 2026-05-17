# Phase 12: Trap-Coverage Lint + Orphan Cleanup — Context

**Gathered:** 2026-05-17
**Status:** Ready for planning
**Mode:** Interactive discuss (autonomous --interactive)

<domain>
## Phase Boundary

Land a CI lint that asserts every per-question `metadata.yaml` trap entry has a matching `cka_sim::grade::record_trap <id>` call site in the same question's `grade.sh`. Then trim 3 known orphan traps the lint will flag.

**In scope:**
- New `cka-sim/scripts/lint-trap-coverage.sh` (LINT-01)
- Wire the new lint into the existing CI job graph in `.github/workflows/validate.yml`
- Trim orphans in `cka-sim/packs/storage/02-storageclass-dynamic/metadata.yaml` (BUG-M01)
- Trim orphans in `cka-sim/packs/storage/03-access-modes-reclaim/metadata.yaml` (BUG-M02)
- Trim orphans in `cka-sim/packs/storage/04-csi-volumesnapshot/metadata.yaml` (BUG-M03)

**Out of scope:**
- Workloads-scheduling/01, /02, /03 PASS-with-metadata-nits (forensic report notes them as informational; not in v1.0.1 scope per REQUIREMENTS.md).
- Catalog refactor — REQUIREMENTS.md "Out of Scope".
- Touching `scripts/lint-traps.sh` schema validator (decision: keep it focused on per-entry schema; cross-file consistency lives in the new script).
</domain>

<canonical_refs>
## Canonical References

- `.planning/forensics/report-20260517-091657-full-audit.md` — "Patterns observed" #1 (trap inventory drift) + storage/02, /03, /04 detail
- `.planning/REQUIREMENTS.md` — LINT-01, BUG-M01, BUG-M02, BUG-M03
- `.planning/ROADMAP.md` — Phase 12 success criteria
- `cka-sim/scripts/lint-traps.sh` — existing schema validator (reference pattern: pure-bash YAML parsing, exit-1 on errors, ok/err helpers)
- `cka-sim/scripts/lint-packs.sh` — sibling pack validator
- `cka-sim/scripts/lint-coverage.sh` — sibling coverage validator
- `cka-sim/scripts/test.sh` — runs all unit/lint scripts; new lint should hook in
- `.github/workflows/validate.yml` — CI workflow with bash-tests job
- `cka-sim/lib/colors.sh`, `cka-sim/lib/log.sh` — shared `header`, `ok`, `err`, `warn` helpers
- `cka-sim/traps/catalog.yaml` — trap taxonomy (read-only for this phase)
- Per-question `metadata.yaml` and `grade.sh` for the 3 questions in scope

No external docs/ADRs cited.
</canonical_refs>

<decisions>
## Implementation Decisions

### LINT-01 — New `scripts/lint-trap-coverage.sh`

**Why a new script (not extending lint-traps.sh):**
- `lint-traps.sh` validates a single file (`traps/catalog.yaml`) for schema. New lint scans 38 question dirs and cross-correlates two files per dir. Different shape, different cost.
- Keeping schema-vs-coverage as separate scripts gives clearer failure messages and easier individual invocation.
- Mirrors the established split: `lint-packs.sh`, `lint-traps.sh`, `lint-coverage.sh` already coexist.

**Implementation outline (planner refines):**
1. Walk `cka-sim/packs/*/*/metadata.yaml`. Skip non-question dirs (e.g., `_template`).
2. For each metadata.yaml:
   - Pure-bash YAML parse (mirror `lint-traps.sh`'s state-machine pattern). Extract `traps:` list.
   - Read sibling `grade.sh`.
   - For each declared trap id, grep for the literal pattern `record_trap <id>` (with optional surrounding quotes/spaces). Use `grep -E` or careful pattern that allows the variable form `record_trap "$var"` when the var resolves to a known id (skip with a warning if grade.sh uses dynamic ids — none of the v1.0 graders do).
   - Track orphans (declared but not recorded) and report each with the file:line citation of the metadata entry.
3. Exit 1 if any orphan; exit 0 if clean.
4. Output format mirrors `lint-traps.sh`: `header "trap coverage lint"`, `ok` for each pack-question pair clean, `err` for each orphan with citation.

**CI wire-up:**
- Add new step in `.github/workflows/validate.yml` alongside `lint-packs`, `lint-traps`, `lint-coverage`. Same `bash-tests` job or a sibling step — planner picks whichever matches existing patterns.
- Hook into `cka-sim/scripts/test.sh` so local `bash test.sh` runs the new lint too.

**Synthetic regression test (per ROADMAP success criterion 4):**
- Add a unit fixture or test invocation that re-adds one orphan to a copy of a metadata.yaml and confirms the lint exits 1 with a clear citation.

### BUG-M01 storage/02-storageclass-dynamic — Trim 2 orphans

**Current metadata.yaml `traps:`:** `pvc-wrong-storageclass`, `pvc-accessmode-rwx-on-rwo-sc`, `hostpath-pv-without-nodeaffinity`

**Grade.sh records:** `pvc-wrong-storageclass` only.

**Action:** Drop `pvc-accessmode-rwx-on-rwo-sc` and `hostpath-pv-without-nodeaffinity` from this question's metadata.yaml. Keep `pvc-wrong-storageclass`.

**Catalog impact:** Trap entries stay in `cka-sim/traps/catalog.yaml` — they're still seeded for other questions and shared taxonomy. This phase only edits per-question pointers.

### BUG-M02 storage/03-access-modes-reclaim — Trim 1 orphan

**Current metadata.yaml `traps:`:** `pv-accessmodes-mismatch`, `pvc-wrong-storageclass`, `reclaim-policy-retain-when-delete-required`

**Grade.sh records:** `pv-accessmodes-mismatch`, `reclaim-policy-retain-when-delete-required`.

**Action:** Drop `pvc-wrong-storageclass` from this question's metadata.yaml. Keep the other two.

### BUG-M03 storage/04-csi-volumesnapshot — Trim 1 orphan

**Current metadata.yaml `traps:`:** `csi-snapshot-wrong-driver`, `pvc-wrong-storageclass`, `reclaim-policy-delete-data-loss`

**Grade.sh records:** `csi-snapshot-wrong-driver`, `pvc-wrong-storageclass`.

**Action:** Drop `reclaim-policy-delete-data-loss` from this question's metadata.yaml. The forensic report and grade.sh comment both note this trap has no durable signal in this question (VolumeSnapshotClass has no intent field). Catalog entry stays.

### Plan ordering

Land lint script first (will fail with the 3 known orphans visible). Then trim each orphan; lint passes after each trim. Final commit: synthetic-regression test + CI wire-up confirmed green. Lint becomes a permanent guard for future authors.
</decisions>

<code_context>
## Existing Code Insights

**Lint-traps.sh patterns to reuse:**
- `set -euo pipefail` + `CKA_SIM_ROOT` resolution
- `source "$CKA_SIM_ROOT/lib/colors.sh"` and `lib/log.sh` for `ok`, `err`, `warn`, `header`
- Pure-bash state-machine YAML parser (D-04: no python, no yq)
- `errors=0; checked=0` counters; final exit 1 vs ok-summary path

**Sibling lint scripts (read for style):**
- `cka-sim/scripts/lint-packs.sh` — walks all packs, validates pack-level structure
- `cka-sim/scripts/lint-coverage.sh` — measures Tracker coverage

**Current grade.sh `record_trap` call patterns (38 questions surveyed earlier):**
- Always literal: `cka_sim::grade::record_trap <kebab-case-id>` or with double-quotes around id
- Sometimes inside `if` blocks; sometimes as the trailing line in a detector chain
- One question (`storage/04`) uses `cka_sim::grade::record_trap "$hit"` where `$hit` is the return value of a trap detector — these need a small allow-listing in the lint script (treat unresolved variables as "covered" + emit a warn note rather than fail-hard).

**RFC 1123 trap IDs already enforced by lint-traps.sh — new lint can rely on the id format.**
</code_context>

<specifics>
## Specific Ideas

- Lint should produce file:line citations matching `lint-traps.sh` style (`metadata.yaml:line N`).
- Lint must succeed on the full pack tree only AFTER orphans trimmed — so plans land in order: lint script → trim metadata files → confirm clean.
- CI wire-up should run on PRs (existing trigger pattern in `validate.yml`).
- Use `grep -F` for literal id matching to avoid regex quoting headaches.
- Edge case: `grade.sh` uses `cka_sim::grade::record_trap "$hit"` (storage/04, troubleshooting/04, cluster-architecture/04, etc.) — treat as "covered all traps in this file" rather than fail. Document the limitation in the lint script's header comment.
- Add the new script to `cka-sim/scripts/test.sh` invocations.
- Test the lint on HEAD (must exit 0 after trims) and against a synthetic regression (must exit 1).
</specifics>

<deferred>
## Deferred Ideas

- Stricter lint that disallows the dynamic-id pattern (`record_trap "$hit"`) entirely — would require refactoring 4-5 graders; out of scope for v1.0.1.
- Reverse-coverage check (every `record_trap` call has an entry in some metadata.yaml) — opposite direction, not what BUG-M01..M03 demand. Could be future enhancement.
- Linting `cka-sim/traps/catalog.yaml` to flag entries no one references — out of scope for v1.0.1.
- Auto-fix mode for the lint — out of scope; trim-by-hand keeps author intent visible.
</deferred>

# Phase 2: Trap Framework + Assertion Library - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-09
**Phase:** 2-trap-framework-assertion-library
**Areas discussed:** Detector contract, Grader output state machine, Test harness approach, Catalog schema + lint

---

## Detector contract

### Q1: How should trap detectors be invoked from a grader?

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit per-trap call | Grader manually calls each relevant detector after a failed assertion. Every grader explicitly opts into the traps it cares about. | ✓ |
| Auto-fire on assertion failure | `assert_X` helpers internally iterate registered detectors against the asserted resource. | |
| Tag-based selection | Grader declares `traps=(...)` at top; single `run_traps` iterates the declared list. | |

**Notes:** Chosen for explicitness — avoids surprise fires from unrelated detectors and keeps debugging trivial.

### Q2: Detector function signature — arg shape and hit signal

| Option | Description | Selected |
|--------|-------------|----------|
| Positional args, stdout returns trap-id | `detect_default_sa_used <ns> <pod>` echoes id on hit, empty on miss. | ✓ |
| Single context-JSON arg, stdout returns trap-id | Every detector takes one JSON-shaped string. | |
| Global-state model | Grader sets env vars; detector reads them. | |

**Notes:** Composable in `$(...)`, trivially testable in isolation, no global state.

### Q3: Where does the `Trap N: <name>: <description>` line come from?

| Option | Description | Selected |
|--------|-------------|----------|
| Detector returns ID only; finalizer formats from catalog | Catalog is single source of truth for trap text. | ✓ |
| Detector echoes formatted line directly | Trap text duplicated across detector + catalog. | |
| Hybrid bash array + YAML | Two sources, parity-lint required. | |

**Notes:** Renaming a trap should not require touching detectors.

### Q4: Catalog parsing at runtime — how does `lib/traps.sh` read `traps/catalog.yaml`?

| Option | Description | Selected |
|--------|-------------|----------|
| Pure-bash parser for flat shape | 30-line awk/grep parser. Zero new deps. | ✓ |
| yq with apt auto-install | yq isn't in default Ubuntu 22.04 repos; pulling from GitHub Releases adds attack surface. | |
| Generated `catalog.bash` from YAML | Drift-guard required. | |

**Notes:** Schema lint enforces flatness so the parser's assumptions hold.

---

## Grader output state machine

### Q5: When `assert_X` fails inside a grader, what should happen?

| Option | Description | Selected |
|--------|-------------|----------|
| Accumulate, keep grading | Records failure, returns non-zero, grader keeps running. `set -uo pipefail` (no `-e`). | ✓ |
| Abort on first failure | Calls `die`. | |
| Caller chooses per assert | Maximum boilerplate per grader. | |

**Notes:** Mirrors Phase 1's `doctor.sh` aggregate-all-failures pattern. Candidate sees ALL mistakes per drill — matches GRADE-03's plural traps.

### Q6: Per-assertion point allocation

| Option | Description | Selected |
|--------|-------------|----------|
| Each assertion = 1 point; max = total assertion count | Optional weight arg defaulted to 1. | ✓ |
| Per-question fixed max + weighted asserts | Authoring discipline burden. | |
| Pass/fail only, no fractional score | Contradicts GRADE-03 `<n>/<max>` shape. | |

**Notes:** Weight arg reserved on every helper signature for future tuning, but Phase 2 leaves all weights at 1.

### Q7: Stdout shape for a grader

| Option | Description | Selected |
|--------|-------------|----------|
| Per-assertion live (stderr) + SCORE/Trap summary block (stdout) | Live `✓`/`✗` via `lib/log.sh` to stderr; SCORE + traps to stdout. | ✓ |
| Summary block only | Silent during run. | |
| JSON-only | Contradicts literal `SCORE: <n>/<max>` text format. | |

**Notes:** Matches Phase 1's stderr-for-status / stdout-for-parseable-output pattern.

### Q8: Trap deduplication

| Option | Description | Selected |
|--------|-------------|----------|
| Dedup by trap-id; one Trap line per id | Forward-compatible with DF-02 cross-session aggregation. | ✓ |
| Emit each fire separately with context | Bloats report, complicates aggregation. | |
| Dedup + show count | Inconsistent line format; downstream parser complexity. | |

---

## Test harness approach

### Q9: How does the harness mock `kubectl`?

| Option | Description | Selected |
|--------|-------------|----------|
| PATH-shadowed kubectl stub | `tests/bin/kubectl` script reads argv, cats fixture file. Detectors run unchanged. | ✓ |
| Bash function override | Breaks across subshells, fragile. | |
| Real `kind` cluster in CI | Deferred to v1.x as DF-12. | |

**Notes:** Static-only at Phase 2 close, matching Phase 1's deferral of cluster validation.

### Q10: Test runner / framework

| Option | Description | Selected |
|--------|-------------|----------|
| Plain bash + assert helpers | Zero new deps. Matches Phase 1 constraint. | ✓ |
| bats-core | Not in apt-default; vendored copy or universe repo. | |
| shellspec | Not in apt at all. | |

**Notes:** Hand-rolled `expect_eq` / `expect_empty` / `expect_contains` under `cka-sim/tests/lib/assert.sh`.

### Q11: How is the harness invoked, and does it gate CI?

| Option | Description | Selected |
|--------|-------------|----------|
| `cka-sim/scripts/test.sh` + new GHA job | Standalone script, mirrors Phase 1's pattern. | ✓ |
| Promote to `cka-sim test` subcommand | Testing is dev concern, not candidate concern. | |
| Extend `scripts/validate-local.sh` | That script is YAML/legacy-paths focused. | |

**Notes:** CI extends `.github/workflows/validate.yml` `paths:` to include `cka-sim/**` and adds a `bash-tests` job after yamllint.

### Q12: Fixture coverage

| Option | Description | Selected |
|--------|-------------|----------|
| Hit + miss + benign | 24 fixtures total. Catches false-negatives AND false-positives. | ✓ |
| Hit only | 8 fixtures; doesn't catch always-fires bugs. | |
| Hit + miss | 16 fixtures; misses benign-context false positives. | |

**Notes:** Same hit/miss/benign rule applies to assertion helpers.

---

## Catalog schema + lint

### Q13: Required fields per catalog entry

| Option | Description | Selected |
|--------|-------------|----------|
| id, name, description, remediation_hint, references, severity, domain, source | All forward-compat data Phase 7 needs is captured at authoring time. | ✓ |
| REQUIREMENTS.md minimum only | Phase 7 has to derive domain at runtime — fragile. | |
| Minimum + severity only | Loses provenance traceability. | |

**Notes:** Schema stays flat so D-04's pure-bash parser works.

### Q14: Structure of `references` field

| Option | Description | Selected |
|--------|-------------|----------|
| List of structured `{kind, target, note}` | `kind` enum closed; lint can dereference local paths. | ✓ |
| Free-form prose strings | Untraceable, can't lint. | |
| Two flat lists: internal_refs + external_urls | Loses kind distinction. | |

**Notes:** `kind` enum: `concerns-md`, `k8s-doc`, `prior-art-exercise`, `exam-objective`, `blog-post`.

### Q15: Catalog lint scope and location

| Option | Description | Selected |
|--------|-------------|----------|
| New `cka-sim/scripts/lint-traps.sh` covering schema + RFC1123 + paths + seed-completeness | One tool covers everything. | ✓ |
| Extend `scripts/validate-local.sh` | Mismatches that script's scope. | |
| yamllint with custom schema | Can't do path checks or seed-completeness. | |

**Notes:** Wired into `cka-sim/scripts/test.sh` and the new GHA `bash-tests` job.

### Q16: How is a grader's emitted trap-id verified to be registered?

| Option | Description | Selected |
|--------|-------------|----------|
| Runtime check inside `record_trap` | `die` on unknown id; impossible to ship a phantom trap. | ✓ |
| CI-only static check | Misses dynamic id construction. | |
| Both runtime + CI lint | Runtime check is sufficient; CI grep adds nothing. | |

---

## Claude's Discretion

- Exact `id` spelling for the 8 seeded traps — copied verbatim from REQUIREMENTS.md GRADE-05.
- Per-trap `domain` mapping — assigned by planner/executor based on subject-matter.
- Argv-fingerprint algorithm in the kubectl stub — small dispatcher table is sufficient for Phase 2.
- Helper internal layout under `cka-sim/lib/` — single files (`traps.sh`, `grade.sh`); per-detector split deferred.

## Deferred Ideas

- **DF-02 cross-session trap-frequency aggregation** — Phase 2's data shape is forward-compatible; aggregator is v1.x.
- **DF-12 fixture CI against `kind`** — static-only at Phase 2 close.
- **Per-detector file split** under `cka-sim/lib/traps/` — revisit only if catalog passes ~30 traps.
- **`cka-sim test` subcommand** — testing stays a dev concern.
- **yq-based catalog parsing** — pure-bash parser stays unless catalog schema gains nesting.
- **Auto-fire detectors on every assertion failure** — rejected; explicit per-trap call wins.
- **Per-assertion fractional weights** — reserved in helper signature but unused in Phase 2.
- **Severity-driven exit-code shading** — `severity` is metadata only at Phase 2; runtime treatment is v1.x.

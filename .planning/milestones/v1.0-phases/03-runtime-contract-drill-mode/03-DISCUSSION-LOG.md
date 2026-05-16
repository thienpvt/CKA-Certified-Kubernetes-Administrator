# Phase 3: Runtime Contract + Drill Mode — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-10
**Phase:** 3-runtime-contract-drill-mode
**Areas discussed:** Pack/question layout + manifest, `cka-sim drill` CLI contract, Idempotency + reset/setup pattern, 5 reference questions + GRADE-02 lint + ref-solution

---

## Pack/question layout + manifest

### Q1: Directory layout for question triplets

| Option | Description | Selected |
|--------|-------------|----------|
| `cka-sim/packs/<domain>/<NN>-<slug>/` with 6 files per question | Matches PACK-01 language; 1-to-1 pack mapping. | ✓ |
| Flat per-domain with filename prefixes | Breaks `cd && bash setup.sh` workflow. | |
| Flat question pool + packs reference by id | Conflates pack boundary with content location. | |

### Q2: Shape of `packs/<domain>/manifest.yaml`

| Option | Description | Selected |
|--------|-------------|----------|
| Full pack metadata + ordered question list | Feeds Phase 7 weight math; PACK-07 coverage-lint target. | ✓ |
| Minimal list of question directories | Loses pack weight for Phase 7 blueprint composition. | |
| No manifest — glob discovery | No lint surface for PACK-07 coverage matrix. | |

### Q3: Question-selection behavior for `cka-sim drill <pack>`

| Option | Description | Selected |
|--------|-------------|----------|
| Random by default; numeric arg picks specific | Matches flashcard model; `<N>` escape hatch. | ✓ |
| First-unsolved from history log | Requires history persistence (DF-02 territory). | |
| Always prompt candidate to pick from list | Two-step UX friction. | |

---

## `cka-sim drill` CLI contract

### Q4: Question presentation

| Option | Description | Selected |
|--------|-------------|----------|
| Cat to stdout + `read` for 'done'/'skip' | Minimal; works on any terminal; matches real-exam. | ✓ |
| Page via $PAGER then prompt | Adds paging step the real exam doesn't have. | |
| Tmux split pane | Requires tmux; complicates trap handling. | |

### Q5: Per-drill grading output

| Option | Description | Selected |
|--------|-------------|----------|
| Both: live stdout + persisted report | Forward-compat with Phase 7 score history. | ✓ |
| Stdout only — no persistence | Phase 7 `cka-sim score` needs history. | |
| Persisted only | Clunky 2-step UX. | |

### Q6: Lab-namespace cleanup behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Always auto-reset on exit via EXIT trap | Guaranteed clean slate between drills. | ✓ |
| Reset on abnormal exit; keep lab alive after graded 'done' | Adds a prompt step. | |
| No auto-reset | Fails TRIP-05 enforcement at runner level. | |

---

## Idempotency + reset/setup pattern

### Q7: How should `setup.sh` achieve TRIP-02 idempotency?

| Option | Description | Selected |
|--------|-------------|----------|
| `kubectl apply` everywhere; dry-run-pipe-apply for imperatives | Single idiom; apply is idempotent. | ✓ |
| Delete-then-create at top of every setup.sh | Slow (--wait); fights TRIP-05. | |
| Check-and-skip if namespace exists | Silent "already done" is wrong signal. | |

### Q8: How should `reset.sh` clean up cluster state?

| Option | Description | Selected |
|--------|-------------|----------|
| Delete ns async + explicit cluster-scoped list | Fast; leverages TRIP-03 id-prefix rule. | ✓ |
| Label-selector cleanup for cluster-scoped | Still need kind list; more ceremony. | |
| Namespace delete only | Can't handle cluster-scoped resources. | |

### Q9: Where does the reset → setup → grade sequence get enforced?

| Option | Description | Selected |
|--------|-------------|----------|
| Runner-owned orchestration | Simple authoring contract; TRIP-05 is runner's problem. | ✓ |
| Self-guarding setup.sh | Duplicates orchestration across 80+ files. | |
| Shared orchestration library (lib/drill.sh) | Premature for Phase 3; revisit in Phase 7. | |

---

## 5 reference questions + GRADE-02 lint + ref-solution

### Q10: Which 5 reference questions to author

| Option | Description | Selected |
|--------|-------------|----------|
| 5 'smallest useful' picks mapped to 5 seeded traps | Proves framework end-to-end; each exercises distinct assertion helper + seeded trap. | ✓ |
| Let user specify | Slows Phase 3. | |
| Just 2 reference questions | Violates ROADMAP "5 total" spec. | |

### Q11: Where does the `ref-solution` for GRADE-06 round-trip live?

| Option | Description | Selected |
|--------|-------------|----------|
| Executable bash script | Same authoring style as triplet; easy lint. | ✓ |
| Inline in question.md `<details>` block | CI has to parse markdown; candidate can peek. | |
| Declarative YAML manifest | Some solutions aren't pure-YAML. | |

### Q12: Where does the GRADE-02 banned-pattern lint live?

| Option | Description | Selected |
|--------|-------------|----------|
| New `cka-sim/scripts/lint-packs.sh` covering GRADE-02 + PACK-06 | Clean separation; both lints gate CI. | ✓ |
| Extend `lint-traps.sh` | Script name misleads; scope creep. | |
| No separate lint | Social contract fails silently. | |

---

## Claude's Discretion

- Exact `manifest.yaml` vs `metadata.yaml` field overlap (lint enforces match).
- Per-question task wording, exact pod names, RFC-1123-compliant resource names.
- New trap catalog entries for per-question non-seeded traps.
- Whether live-cluster CI via `kind` is attempted (DF-12 deferred; Phase 3 plans may elect static-only).

## Deferred Ideas

- DF-02 trap-frequency aggregation across sessions.
- DF-08 hint reveal (drill mode only).
- DF-09 retake with re-randomised draw.
- DF-11 `cka-sim author lint <q-dir>`.
- DF-12 fixture CI against `kind` cluster.
- Mid-drill kubectl shell / tmux split.
- Inspect-after-drill (`--inspect` flag).
- Adaptive question selection.
- Shared `cka-sim/lib/drill.sh` orchestration library for exam reuse.
- Full authoring doc (Phase 8 DOC-02).
- SCHEMA.md (Phase 8 DOC-03).

---
phase: 03-runtime-contract-drill-mode
plan: 09
status: complete
completed: 2026-05-10
---

# Plan 03-09 Summary — AUTHORING.md (partial)

## What shipped

- `cka-sim/AUTHORING.md` (210 lines) — partial authoring guide covering:
  - 6-file question directory contract
  - Per-file rules (metadata.yaml schema, question.md PSI style, setup/grade/reset/ref-solution idempotency)
  - GRADE-06 round-trip as human-verification procedure (DF-12 deferred)
  - Trap catalog extension rules + detector/id parity requirement
  - `lint-packs.sh` rule table (5 passes A-E)
  - Explicit list of what's deferred to Phase 8 (DOC-02)

## Key design choices

- **Partial by design:** document explicitly marks itself as Phase 3 scope, points at `cka-sim/packs/storage/01-pvc-binding/` as the canonical exemplar, and lists exactly what Phase 8 DOC-02 will extend (style guidance, full schema, coverage-matrix workflow, contributor walkthrough).
- **Lint rule table mirrors the actual implementation** — the 5 passes in the table match lint-packs.sh 1:1 (A grep+getall, B mutating verbs, C setup ns-guard, D files+exec bits, E metadata schema+trap registration).
- **GRADE-06 human-verification procedure is concrete:** ~20 lines of bash candidates can copy-paste to round-trip any question. No CI-cluster dependency.

## Verification

- `bash cka-sim/scripts/test.sh` — still green, 23 cases
- File exists: `cka-sim/AUTHORING.md` — 210 lines

## Commit

- `cacffa9` docs(03-09): add partial AUTHORING.md (Phase 3 scope)

## Notes

Phase 8 (DOC-02) will extend this document. The deferred topics are
listed explicitly so readers know what's *not* here and where to look
for help today.

---
plan: 16-02
phase: 16-question-intent-baseline-harness
requirements: [BASELINE-04, DOC-01]
status: complete
date: 2026-05-19
---

# Plan 16-02 Summary — `docs/AUTHORING.md` workflow guide

## Outcome

`docs/AUTHORING.md` ships at the repo root under a new `docs/` directory. It walks a question author end-to-end through the test-artifact triplet (`expected-symptom.yaml` / `cka-sim/lib/baseline.sh` snapshot / `grade.sh`), shows a worked prose-to-YAML derivation using `storage/01-pvc-binding`, documents the `cka-sim audit` invocation reference, and cross-links the canonical schema and grading-honesty docs without duplicating their content.

The doc is discoverable from `cka-sim/README.md` (new Documentation section) AND from `cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md` (reciprocal navigation note at the top), so a reader can navigate either direction. Bundled with this plan: the `.planning/PROJECT.md` 38 → 34 question-count fix per CONTEXT.md D-09.

## Files Created (1)

- `docs/AUTHORING.md` — 123 lines, 6 H2 sections (triplet table; expected-symptom.yaml authoring with worked example; setup-state baseline stub; grade.sh authoring stub; cka-sim audit invocation reference; cross-links).

## Files Modified (3)

- `cka-sim/README.md` — added a new `## Documentation` section between `## Mock Exams` and `## Development`, listing AUTHORING.md, EXPECTED-SYMPTOM-SCHEMA.md, and GRADING-HONESTY.md.
- `cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md` — added a top-of-file blockquote linking back to `../../docs/AUTHORING.md`.
- `.planning/PROJECT.md` — corrected 4 narrative references from 38 questions to 34 (lines 5, 16, 31, 118). The Domain Packs table values (6+8+6+8+6=34) were already correct; only narrative text needed updating.

## Cross-link Path Decision

`cka-sim/lib/GRADING-HONESTY.md` was the path documented in CONTEXT.md, but the file actually lives at `cka-sim/GRADING-HONESTY.md` (one level higher). AUTHORING.md and the README.md Documentation section both use the actual location. CONTEXT.md is left as-is (it was a planning-time assumption; the plan output reflects the live filesystem).

## Section Structure (D-10 lock)

| Section | Purpose |
|---------|---------|
| Title + intro | One-paragraph framing |
| The test-artifact triplet at a glance | Table mapping artifact → role → who reads it |
| Authoring `expected-symptom.yaml` from `question.md` prose | Heart of the doc — worked storage/01-pvc-binding example with prose-to-YAML walkthrough + Common pitfalls |
| Setup-state baseline (`cka-sim/lib/baseline.sh`) | Stub explaining the runner-managed snapshot; links GRADING-HONESTY.md |
| Authoring `grade.sh` | Stub explaining the helper library and trap diagnostics; links traps/catalog.yaml |
| `cka-sim audit` invocation reference | Three scopes + --report flag + exit codes |
| Cross-links | Schema, grading-honesty, README, trap catalog, Phase 16 CONTEXT.md |

## D-09 PROJECT.md Correction

Pre/post counts:

| Reference | Before | After |
|-----------|--------|-------|
| Line 5 ("What This Is") | 38 total questions | 34 total questions |
| Line 16 (v1.0 shipped state) | 38 questions across 5 domain packs | 34 questions across 5 domain packs |
| Line 31 (v1.0 Validated) | 38 questions total | 34 questions total |
| Line 118 (Key Decisions table) | held across 38 questions | held across 34 questions |

`grep -cE '38 (questions|total)' .planning/PROJECT.md` returns 0 post-edit. `grep -cE '34 (questions|total)' .planning/PROJECT.md` returns 4.

## Acceptance Criteria

| Check | Result |
|-------|--------|
| `docs/AUTHORING.md` exists | ✓ |
| Title heading present exactly once | ✓ |
| 6 H2 sections | ✓ (matches D-10 — title is H1, the 7th "section" in the spec is the implicit intro paragraph) |
| Worked example uses storage/01-pvc-binding | ✓ |
| Audit invocation reference complete | ✓ (3 scopes + --report + exit codes 0/1/2) |
| Cross-link to schema | ✓ (`../cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md`) |
| Cross-link to grading-honesty | ✓ (`../cka-sim/GRADING-HONESTY.md` — actual path, not lib/) |
| README.md Documentation section | ✓ (between Mock Exams and Development) |
| SCHEMA.md reciprocal link | ✓ |
| PROJECT.md 38 → 34 fix | ✓ (4 occurrences) |
| Markdown content untouched outside Documentation block | ✓ |

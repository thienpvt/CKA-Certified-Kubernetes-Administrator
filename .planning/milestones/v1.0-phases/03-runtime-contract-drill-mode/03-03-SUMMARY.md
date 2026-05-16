---
phase: 03-runtime-contract-drill-mode
plan: 03
status: complete
completed: 2026-05-10
---

# Plan 03-03 Summary — lint-packs.sh + test.sh wiring

## What shipped

- `cka-sim/scripts/lint-packs.sh` (158 lines) — 5 lint passes:
  - **A:** GRADE-02 grade.sh idioms (`kubectl get | grep`, `kubectl get -A`)
  - **B:** Mutating-verb rejection (user override #3 — graders read-only)
  - **C:** D-09 runner-owns-cleanup guard (no `kubectl delete ns` in `setup.sh`)
  - **D:** 6-files-per-question + executable bits
  - **E:** metadata.yaml schema + trap-id registration in catalog
- `cka-sim/scripts/test.sh` — step 2 "lint packs" inserted between lint-traps and run.sh
- `cka-sim/tests/cases/lint_packs_*.sh` — 4 unit-test cases (positive + negative coverage for each lint rule)
- `cka-sim/tests/fixtures/lint-packs/` — 5 fixture sets (`good/`, `bad-grep/`, `bad-getall/`, `bad-mutating/`, `bad-deletens/`, `bad-metadata/`)

## Key design choices

- **Reuses** `cka_sim::trap::is_valid_id` and `cka_sim::trap::id_exists` from `lib/traps.sh` — no re-implementation of the RFC 1123 validator or catalog parser.
- **Wave-0 graceful skip:** `lint-packs.sh` exits 0 if the packs dir doesn't exist yet. This lets Wave 2 land before Wave 3 without breaking the test suite.
- **`CKA_SIM_LINT_PACKS_DIR`** env override enables fixture-tree testing — each unit test builds a throwaway pack tree under `mktemp -d`, points lint-packs at it, and asserts exit code + stderr matches.
- **Regex comment-strip** via `^[^#]*` prefix — avoids false positives on legitimate `kubectl get -o jsonpath` and comments mentioning banned idioms (RESEARCH Pitfall 2).

## Verification

- `bash -n cka-sim/scripts/lint-packs.sh` — syntax OK
- `CKA_SIM_LINT_PACKS_DIR=/tmp/nope bash cka-sim/scripts/lint-packs.sh` — exit 0 with wave-0 skip message
- `bash cka-sim/scripts/test.sh` — exit 0, **23 cases green** (15 Phase 2 + 4 drill + 4 lint-packs)

## Commits

- `15e8cd3` feat(03-03): add lint-packs.sh (GRADE-02 + PACK-06 + override #3)
- `ec7cb2f` feat(03-03): wire lint-packs.sh into test.sh orchestrator
- `*` test(03-03): add 4 lint-packs unit cases + 5 fixture sets

## Notes

- GRADE-06 round-trip remains a human-verification step (user override #2).
- lint-packs.sh is now the structural contract the Wave 3 question packs must satisfy — each pack that lands must make `bash cka-sim/scripts/test.sh` still green.

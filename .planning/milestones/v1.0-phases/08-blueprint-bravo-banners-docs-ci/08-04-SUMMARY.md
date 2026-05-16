---
phase: 08-blueprint-bravo-banners-docs-ci
plan: "04"
backfilled: 2026-05-17
source_commit: f4fa7b8
---

# 08-04: validate-local.sh + CI Shellcheck

## One-Liner
Local pre-push validation runner + GitHub Actions shellcheck job for CI gate on all bash sources.

## What Was Built
- `cka-sim/scripts/validate-local.sh` — runs lint-packs + lint-traps + test.sh as pre-push check
- `.github/workflows/` shellcheck job

## Verification
Covered by 08-VERIFICATION.md.

## Self-Check: PASSED

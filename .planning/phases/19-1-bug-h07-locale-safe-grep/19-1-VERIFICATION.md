---
phase: 19.1-bug-h07-locale-safe-grep
status: passed
date: 2026-05-20
requirements_covered: [BUG-H07]
closed_by: <pending commit>
---

# Phase 19.1 Verification — BUG-H07 locale-safe grep

## Outcome

Replaced `grep -P '\t'` with `grep -F $'\t'` in `cka-sim/packs/troubleshooting/05-static-pod-manifest/setup.sh`. Locale-independent — works on Linux runners with non-UTF-8 locale (where GNU grep refuses `-P`).

## Files Modified (1)

| File | Change |
|------|--------|
| `cka-sim/packs/troubleshooting/05-static-pod-manifest/setup.sh` | `grep -P '\t'` → `grep -F $'\t'` (single-line edit) |

## Verification

| Check | Result |
|-------|--------|
| `cka-sim audit troubleshooting/05-static-pod-manifest` on local kind+Calico | ✓ PASS (1/1 expectations met) |
| Empty submission still scores 0/N | ✓ (no grader change; setup-only fix) |

## BUG-H07 Closed

FORENSIC-v102.md row updated to closed; routes through Phase 21 sign-off.

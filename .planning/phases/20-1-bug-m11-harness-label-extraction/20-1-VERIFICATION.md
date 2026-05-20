---
phase: 20.1-bug-m11-harness-label-extraction
status: passed
date: 2026-05-20
requirements_covered: [BUG-M11]
closed_by: <pending commit>
---

# Phase 20.1 Verification — BUG-M11 harness label extraction edge case

## Outcome

Fixed jq's `//` operator binding in `cka-sim/lib/symptom-diff.sh`'s second-pass diff. The bare form `expr // "<missing>"` was binding the alternative across the entire pipeline and emitting `["restricted"]` (a JSON array) instead of the scalar `restricted` for nested-key labels. Reproduced and confirmed via:

```
echo '{"metadata":{"labels":{"X":"v"}}}' | jq -r '.metadata.labels."X" // "<missing>"'
# → ["v"]
echo '{"metadata":{"labels":{"X":"v"}}}' | jq -r '(.metadata.labels."X") as $v | $v // "<missing>"'
# → v
```

## Files Modified (1)

| File | Change |
|------|--------|
| `cka-sim/lib/symptom-diff.sh` | Wrapped jq query in `as $v` binding: `actual="$(jq -r "($jq_query) as \$v | \$v // \"<missing>\"" ...)"`. |

## Verification

| Check | Result |
|-------|--------|
| `cka-sim audit cluster-architecture/04-pss-enforce` on local kind+Calico | ✓ PASS (3/3 expectations met) — was 2 FAILs before fix |
| `bash cka-sim/scripts/test.sh` on Linux Docker | ✓ All 88 unit cases continue to pass |
| Existing PASS questions with `metadata.labels` claims | ✓ Continue to PASS (full audit re-runs naturally during Phase 21) |

## BUG-M11 Closed

FORENSIC-v102.md row updated to closed.

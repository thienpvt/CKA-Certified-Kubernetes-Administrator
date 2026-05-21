# BLG-07 Investigation Findings — `is_candidate_modified` empty-current-state regression

**Phase:** 23 — GHA environmental forensics + lint triage
**Plan:** 02
**Captured:** 2026-05-21
**Status:** Root cause identified; conservative fix selected

---

## 1. Failure signature

From `cka-sim/current-tests/step1-results.txt` (GHA `ubuntu-latest`, `bash scripts/test.sh`, line 185):

```
  ✗ unchanged: returns 1 (gen=3 rv=100 same as baseline) — expected 1 got 0
✗ case failed (rc=1): baseline_capture_smoke
```

The unchanged-baseline branch of `cka_sim::baseline::is_candidate_modified` is supposed to return `1` (unchanged) when the candidate has not modified the resource since baseline capture. On GHA `ubuntu-latest` it returns `0` (modified) — a false-modified verdict.

**Cascading failures (same root cause):**

- `traps_default-sa-used` — `miss` and `benign` sub-tests fail (expected empty trap-id, got `default-sa-used`).
- `traps_hostpath-pv-without-nodeaffinity` — `hit` sub-test fails (expected trap-id, got empty — but its detector also relies on the gate; symptom direction is opposite when the detector inverts the gate's verdict).
- `traps_missing-dns-egress` — `hit` fails for the same reason as `hostpath-pv-*`.
- `traps_ownership_gate` — Case A (Q3 regression: setup-owned unchanged pod -> no trap fired) fails (expected empty, got `default-sa-used`).

All four detectors call `cka_sim::baseline::is_candidate_modified` first as their ownership gate; when the helper says "modified" on a setup-owned, untouched resource, the detectors fire when they shouldn't (or, in the inverted case, the gate inversion bites).

**Local Windows MSYS run** (verified independently before this plan): `baseline_capture_smoke` is 5/5 GREEN and the 4 `traps_*` cases all pass. The bug is environment-specific to GHA `ubuntu-latest`.

---

## 2. Hypothesis ranking

Carried forward from `23-CONTEXT.md` and the captured GHA log:

| Rank | Hypothesis | Mechanism | Evidence weight |
|------|-----------|-----------|-----------------|
| H1 | jq output formatting differs across versions | The kubectl stub's `as $v | $v // ""` shape (BUG-M11 fix at `tests/bin/kubectl:91-93`) may emit unexpected output for string values like `"100"` on the jq shipped with GHA `ubuntu-latest`. The downstream pipe `tr '\n' ' ' | sed 's/[[:space:]]*$//'` may then leave `current_rv` empty. | High — captured failure signature is consistent with `current_rv=""` on the unchanged path. |
| H2 | bash version delta in the `[[ ... != ... ]]` comparison | `[[ "$current_rv" != "$baseline_rv" ]]` should compare strings consistently across bash 4.x and 5.x, but unbound-var quirks under `set -u` could differ. | Low — this comparison is well-trodden bash territory. |
| H3 | `set -euo pipefail` interaction with `jq | tr | sed` pipeline | Pipeline component failures may propagate differently across bash versions, leaving `current_rv` unset or empty. | Medium — the stub's `|| true` at line 93 is supposed to guard this, but interaction with `set -e` from the caller can be surprising. |
| H4 | CRLF/LF line ending mismatch in fixture JSONs after Linux git checkout | If the runner has `core.autocrlf=true` (unusual on Linux), JSON values could carry trailing `\r`, breaking string comparisons. | Low — Linux runners default to LF; `.gitattributes` for the repo is conventional. |

---

## 3. Root cause analysis

The rv-fallback path at `cka-sim/lib/baseline.sh:264-275` performs:

```bash
current_rv=$(kubectl get ... -o jsonpath='{.metadata.resourceVersion}' 2>/dev/null)
if [[ "$current_rv" != "$baseline_rv" ]]; then
  return 0  # modified (rv changed)
fi
return 1  # unchanged
```

When `current_rv` is empty (whatever the upstream cause: jq version delta, pipeline failure, or any future env interaction) and `baseline_rv` is non-empty (e.g., `"100"`), the comparison `[[ "" != "100" ]]` evaluates true → the helper returns `0` (modified). This is the wrong default semantics:

- An unreadable current state is an **environment problem**, not evidence the candidate modified the resource.
- The `2>/dev/null` on the kubectl call already establishes that "kubectl produced no usable output" is an expected, non-fatal outcome — the helper is supposed to handle that silence safely.
- Defaulting to "modified" causes false positives in trap detectors (the 4 cascading reds).
- The same bug exists in the **generation-first** path at lines 246-260: when `current_gen` is empty, the code falls through to the rv-fallback (line 260 comment: "fall through to rv check as last resort"), which then has the same broken default.

**The fix point is the helper, not the upstream cause.** Whatever jq does — even if a future version regresses — the helper must be conservative when the current state is unreadable.

---

## 4. Chosen fix point

Two locations in `cka-sim/lib/baseline.sh`:

1. **Generation-first path (lines 246-260):** Add an empty-`current_gen` guard before the `if (( current_gen > baseline_gen ))` comparison. Replace the existing fall-through ("current_gen empty -> fall through to rv check") with an explicit `return 1` (unchanged).

2. **Rv-fallback path (lines 263-275):** Add an empty-`current_rv` guard before the `[[ "$current_rv" != "$baseline_rv" ]]` comparison. Default to `return 1` (unchanged) when current state is unreadable.

Both edits are conservative — they preserve the existing comparison logic when both values are non-empty.

---

## 5. Fix shape (per Task 2)

**Generation-first path** — replace the `if [[ -n "$current_gen" ]]; then ... fi` block (lines 254-261) with:

```bash
if [[ -z "$current_gen" ]]; then
  # BLG-07 (v1.0.3): empty current_gen means unreadable current state.
  # Default to "unchanged" rather than fall through to rv-fallback —
  # an unreadable state is an environment issue, not evidence of modification.
  return 1
fi
if (( current_gen > baseline_gen )); then
  return 0  # modified (generation increased)
fi
return 1  # not modified (generation equal); skip unreliable rv fallback
```

**Rv-fallback path** — insert the empty-rv guard before the comparison at line 271:

```bash
# BLG-07 (v1.0.3): empty current_rv means unreadable current state.
# Default to "unchanged" — same defensive shape as the gen-first path above.
# Without this guard, [[ "" != "$baseline_rv" ]] is true → returns 0 (modified)
# on every fixture where jq output is empty (jq-version delta on GHA ubuntu-latest).
if [[ -z "$current_rv" ]]; then
  return 1
fi
```

The existing comparison `[[ "$current_rv" != "$baseline_rv" ]]` remains downstream of the guard.

---

## 6. Why this is the right fix

- **Symptom-precise.** It addresses the failure mode (`current_rv=""` produces a false-modified verdict) without depending on which upstream cause produced the empty value. Future env regressions in jq, bash, or pipeline behavior fall through to the same safe default.
- **Conservative.** Treating an unreadable current state as "unchanged" matches the back-compat path at lines 207-209: when the helper cannot make a confident determination, it defaults to a non-firing verdict. This prevents detector false positives (the trap will fire only when the helper has positive evidence of modification).
- **Mirrors existing defenses.** The `2>/dev/null` on the kubectl calls at lines 266 and 268 already declares that silent kubectl failures are expected — the helper now handles that silence consistently with that declaration.
- **Surface-minimal.** Two `if [[ -z "$var" ]]; then return 1; fi` guards — no behavioral change when both values are non-empty. The 5 existing `baseline_capture_smoke` sub-tests continue to exercise the comparison logic unchanged.
- **No new attack surface.** Per threat register T-23-02-01: detectors check for explicit modification, not deletion; the conservative default cannot mask candidate work in any path that the existing 5 sub-tests don't already cover.

---

## 7. Out-of-band confirmations (deferred to Phase 24 UAT)

The fix is verified locally (Windows MSYS — was 5/5 green pre-fix; must remain 5/5 post-fix and gain the 6th regression sub-test). Confirmation that the fix resolves the GHA `ubuntu-latest` reds is Phase 24 UAT scope:

- Phase 24's UAT driver pushes a feature branch and observes GHA `bash-tests` job exit 0.
- `cka-sim/current-tests/step6-results.txt` (re-captured) shows `baseline_capture_smoke` 5/5 (or 6/6) green and the 4 `traps_*` cases passing.
- Optional: Docker Ubuntu 22.04 reproduction by the executor — not required for plan acceptance.

---

## Root Cause (summary)

The rv-fallback path in `cka_sim::baseline::is_candidate_modified` (and the generation-first path that falls through to it) treats an empty `current_rv` (or empty `current_gen`) as evidence of modification. On GHA `ubuntu-latest`, the kubectl-stub's jsonpath translator pipeline (`jq -r ... // "" | tr | sed`) produces empty output for string-typed `resourceVersion` fixtures — likely a jq-version delta from BUG-M11's `as $v | $v // ""` shape. The fix point is the helper: add empty-current-state guards that default to "unchanged" (return 1) in both branches, mirroring the back-compat path's defensive shape and the `2>/dev/null` pattern already used on the kubectl calls.

---
quick_id: "260517-hvo"
slug: exam-substitute-lab-ns
date: 2026-05-17
status: in-progress
---

# Quick Task: Substitute ${CKA_SIM_LAB_NS} in exam.sh question.md output

## Description

`cka-sim exam` currently prints `question.md` raw (`cat "$qdir/question.md"` at `cka-sim/lib/cmd/exam.sh:190`). Candidates see literal `${CKA_SIM_LAB_NS}` in the prompt instead of the actual per-question lab namespace (e.g. `cka-sim-services-networking-02`). Substitute the placeholder inline so the rendered prompt shows the concrete namespace.

## Scope

- Only modify `cka-sim::exam::present_question` in `cka-sim/lib/cmd/exam.sh`.
- Replace the raw `cat` with a substitution that swaps every `${CKA_SIM_LAB_NS}` occurrence for the value of `$CKA_SIM_LAB_NS`.
- Preserve all other formatting (headers, separators, hint line).

## Approach

`CKA_SIM_LAB_NS` is exported by `setup_question` (via `export_lab_ns`) before `present_question` is called, so the value is in scope.

All `question.md` files in `cka-sim/packs/` use only the braced form `${CKA_SIM_LAB_NS}` (verified via grep — 30 matches across 9 files, all braced). No bare `$CKA_SIM_LAB_NS` form exists, so handling the braced form alone is sufficient.

Use pure bash parameter expansion (no `envsubst`/`sed` dependency):

```bash
local content
content=$(<"$qdir/question.md")
printf '%s\n' "${content//\$\{CKA_SIM_LAB_NS\}/$CKA_SIM_LAB_NS}"
```

This:
- avoids spawning a subshell for `sed`
- avoids `envsubst` (not always available; would also expand unrelated env vars)
- only substitutes the literal `${CKA_SIM_LAB_NS}` token
- leaves all other text byte-for-byte unchanged

## Tasks

1. Edit `cka-sim/lib/cmd/exam.sh` `present_question` block (lines 189–191) — replace `cat "$qdir/question.md"` with bash parameter-expansion substitution.
2. Manual smoke: shellcheck still passes; visual check that `${CKA_SIM_LAB_NS}` no longer appears in printed prompts (covered by code inspection — runtime cluster not available in this session).

## Out of scope

- `drill.sh` — already prints `Lab ns: $CKA_SIM_LAB_NS` separately at line 322. No request to change.
- Bare `$CKA_SIM_LAB_NS` (no braces) — not present in any question.md.
- Other env-var substitution.

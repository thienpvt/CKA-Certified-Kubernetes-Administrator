---
quick_id: "260517-hvo"
slug: exam-substitute-lab-ns
date: 2026-05-17
status: complete
---

# Summary: Substitute ${CKA_SIM_LAB_NS} in exam.sh question.md output

## Outcome

`cka-sim exam` now renders each question's `question.md` with the concrete per-question lab namespace inlined in place of `${CKA_SIM_LAB_NS}`, matching what `cka-sim drill` candidates effectively get (drill prints `Lab ns:` on a separate line; exam now inlines the value directly inside the prompt text, where every command example references it).

## Change

`cka-sim/lib/cmd/exam.sh` — `cka_sim::exam::present_question`:

Before:
```bash
if [[ -r "$qdir/question.md" ]]; then
  cat "$qdir/question.md"
fi
```

After:
```bash
if [[ -r "$qdir/question.md" ]]; then
  local question_content
  question_content=$(<"$qdir/question.md")
  printf '%s\n' "${question_content//\$\{CKA_SIM_LAB_NS\}/$CKA_SIM_LAB_NS}"
fi
```

## Verification

- `bash -n cka-sim/lib/cmd/exam.sh` → syntax OK.
- Standalone smoke of the parameter-expansion pattern with a representative `question.md` snippet → all three `${CKA_SIM_LAB_NS}` instances replaced; other content preserved.
- `CKA_SIM_LAB_NS` is exported by `cka_sim::exam::export_lab_ns` (called from `setup_question` and `on_exit`) before `present_question` runs, so the value is always in scope.

## Why pure-bash, not envsubst/sed

- `envsubst` is not always available (gettext package), and would also expand unrelated env vars in the prompt — surprising blast radius.
- `sed` would spawn a subshell; bash parameter expansion is in-process and only replaces the literal token we own.
- All 30 `${CKA_SIM_LAB_NS}` matches across 9 `question.md` files use the braced form — no bare `$CKA_SIM_LAB_NS` exists.

## Files touched

- `cka-sim/lib/cmd/exam.sh` (+6 / -1 line in `present_question`)

## Out of scope (not done)

- `drill.sh` — already prints `Lab ns: $CKA_SIM_LAB_NS` as a separate line at `cka-sim/lib/cmd/drill.sh:322`. No request to inline.
- Tests — no existing test covers `present_question` rendering; cosmetic substitution doesn't warrant a new harness.

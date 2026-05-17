---
phase: 14-question-framing-library-fixes
plan: 03
status: passed
requirements: [BUG-M09]
files_modified:
  - cka-sim/packs/troubleshooting/06-broken-kubelet/grade.sh
---

# Summary: Plan 14-03 — BUG-M09 comment-aware trap detection

## What

Added a local `_strip_comments_from FILE` helper to `troubleshooting/06-broken-kubelet/grade.sh` and applied it at the three comment-vulnerable trap detector sites. The two scoring assertions (bash-parseable check + correct-CRI-endpoint regex) and the malformed-quoting trap continue to read the raw file because comments are part of bash-parseability semantics.

## Helper

```bash
_strip_comments_from() {
  local _f="$1"
  [[ -r "$_f" ]] || return 0
  sed -E -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$_f"
}
```

Sed-based: drops trailing inline `# ...` and emits the stripped stream on stdout. Whole-line comments collapse to empty and are then dropped by the second `-e`.

## Detector sites converted (3)

| Site | Trap id | Input source change |
| ---- | ------- | ------------------- |
| Line 62 | `removed-container-runtime-flag` | `"$flags"` -> `_strip_comments_from "$flags" \|` |
| Line 66 | `kubelet-runtime-flag-in-kubeconfig` | `"$kubeconfig"` -> `_strip_comments_from "$kubeconfig" \|` |
| Line 70 | `cri-endpoint-unix-prefix-missing` | awk reads `"$flags"` -> awk reads stripped stream |

Trap ids, record_trap call shape, conditional logic, and the second-stage awk-tr-head pipeline preserved unchanged.

## Sites intentionally NOT converted

- Line 44 — bash-parseable assertion `( set +u; source "$flags" >/dev/null 2>&1; )`: a candidate's `#` comments are perfectly legal bash, so stripping them would distort the assertion. Raw file is correct.
- Line 54 — correct-CRI-endpoint regex `grep -qE 'KUBELET_KUBEADM_ARGS=.*--container-runtime-endpoint=unix:///run/cri-dockerd\.sock' "$flags"`: a candidate cannot satisfy this from inside a `#` comment because bash-parseability is verified separately. Raw file is naturally comment-immune.
- Line 50 — `kubelet-flag-file-malformed-quoting` trap fires off the bash-parseable assertion failure; no input-source change needed.

## Synthetic test matrix (Task 3 — all PASS)

```
PASS: case A — comment correctly ignored
PASS: case B — clean candidate file produces no trap
PASS: case C — uncommented bad flag still trips the trap
```

- Case A: candidate keeps `# old: --container-runtime=remote` as a learning note. Stripped stream no longer matches; trap does NOT fire.
- Case B: clean candidate with only correct live flags. Stripped stream does not match; no trap fires.
- Case C: candidate left the bad flag uncommented in the live `KUBELET_KUBEADM_ARGS` string. Stripped stream STILL matches; trap correctly fires.

## Acceptance check (all greens)

- `bash -n grade.sh` exits 0.
- `grep -c '^_strip_comments_from()'` returns 1.
- `Phase 14 BUG-M09` comment present (1 occurrence).
- Helper invoked at exactly 3 sites (`grep -cE '_strip_comments_from "\$(flags|kubeconfig)"'` returns 3).
- All 3 record_trap calls preserved (1 each).
- Malformed-quoting trap preserved (1 occurrence).
- No raw `grep -q "$removed_flag" "$flags"` survives (0).
- No raw `grep -q 'container-runtime-endpoint' "$kubeconfig"` survives (0).
- Bash-parseable assertion at line 44 preserved verbatim.
- emit_result is the final non-blank line.
- `bash cka-sim/scripts/lint-packs.sh` exits 0 (clean).
- shellcheck not in environment (informational; lint-packs is authoritative).

## Files NOT modified

- `setup.sh`, `ref-solution.sh`, `reset.sh`, `question.md`, `metadata.yaml` — untouched.

## BUG-M09 status

Resolved. Candidate keeping `# old: --container-runtime=remote` as a learning note no longer triggers a false trap; uncommented bad flags still trip the trap.

## Test.sh fixture impact

The grader's behaviour on the test fixtures used by `cka-sim/tests/cases/` is unchanged because ref-solution.sh writes the correct flags with no `#` comments. The new helper only matters when candidates include `#` comments — fixtures do not, so no fixture regen expected. test.sh baseline (6 failures) should not regress.

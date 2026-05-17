# 10-03-SUMMARY.md — BUG-H03 (cluster-architecture/04-pss-enforce)

## Files modified
- `cka-sim/packs/cluster-architecture/04-pss-enforce/grade.sh` — replaced the broken `assert_resource_candidate_authored pod q04-candidate` (which queried the apiserver for a Pod the literal candidate never created) with 5 weight=1 file-based assertions parsing `/tmp/q04-pss-enforce/candidate-violator.yaml` via `kubectl apply --dry-run=client -o jsonpath`. Preserved 5 weight=0 setup-state preconditions (namespace PSS labels, admission-log regex, q04-compliant Deployment existence + readyReplicas), trap detectors (`detect_pss_error_string_mismatch`, `detect_psp_fictional_pod_label_exemption`), and `emit_result` finalizer. Updated file-level header comment to reflect the new 5-precondition + 5-scoring shape.
- `cka-sim/packs/cluster-architecture/04-pss-enforce/ref-solution.sh` — removed the Phase 07.1 D-26 `kubectl apply` and `kubectl wait` block (re-introducing them would re-create the question/grader contradiction). Replaced with a 4-line BUG-H03 comment block explaining the rationale. The cat-heredoc producing the compliant Pod manifest is preserved verbatim.

## Scoring shape change
- BEFORE: 5 weight=0 preconditions + 1 weight=1 `assert_resource_candidate_authored` (broken: contradicts question.md's literal "no kubectl apply needed" claim) → max 1 point.
- AFTER: 5 weight=0 preconditions + 5 weight=1 file-based PSS field assertions → max 5 points.

## Per-field jsonpath strings used (via `_q04_field` helper)
1. `{.spec.containers[*].securityContext.privileged}` — pass when empty OR every token == "false".
2. `{.spec.securityContext.runAsNonRoot}` — pass when == "true".
3. `{range .spec.containers[*]}{"x"}{end}` + `{range .spec.containers[*]}{.securityContext.capabilities.drop}{"|"}{end}` — count containers vs. count of those with "ALL" in drop list.
4. `{.spec.securityContext.seccompProfile.type}` — pass when == "RuntimeDefault".
5. `{.spec.containers[*].securityContext.allowPrivilegeEscalation}` — pass when every token == "false" AND count == container count.

## Why kubectl apply --dry-run=client
Schema validation (kubectl rejects bad types) without contacting the apiserver. Candidate-authored YAML is the source of truth; the apiserver does not need to be involved.

## Verification (predicted; live drill required)
- ref-solution: SCORE 5/5, 0 traps (compliant Pod has all 5 fields correct, no trap-trigger strings).
- empty submission (default seeded violator with privileged=true + fictional exempt label): SCORE 0/5, 2 traps recorded.
- All 14 acceptance-criteria greps confirmed (the two ostensibly-flagged ones are false positives: ref-solution `kubectl apply` only appears in the new explanatory comment; the weight=0 helper calls are multi-line so a one-line grep undercounts — multiline-aware count returns the expected 3).
- `bash -n` passes on both files.

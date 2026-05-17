# 11-01-SUMMARY.md — BUG-H05 (troubleshooting/04-debug-node)

## Files modified
- `cka-sim/packs/troubleshooting/04-debug-node/question.md` — reframed body to authorize ANY Kubernetes-native node-introspection technique (kubectl debug node, hand-rolled privileged Pod with hostPID/hostNetwork+nodeName, ephemeral debug container) and explicitly state the grader scores `/tmp/q04-debug-node/answer.txt` only. Title, domain line, Sandbox section, Constraints (do-not-modify-host, no-SSH, no-cluster-mutation), and Verify-yourself section preserved verbatim.
- `cka-sim/packs/troubleshooting/04-debug-node/grade.sh` — dropped the candidate-forgeable `kubectl.kubernetes.io/debug-source=$worker` label evidence gate. Single weight=1 scoring assertion compares `answer.txt` to `kubectl get node $worker -o jsonpath='{.status.nodeInfo.kernelVersion}'`. Worker-sentinel weight=1 fail-only check preserved. Three trap detectors (`debug-ephemeral-vs-node-confusion`, `debug-node-missing-chroot-host`, `debug-pod-leaked-not-cleaned`) preserved as advisory diagnostics — they no longer gate scoring. `cka_sim::grade::emit_result` is the last call. Phase 11 BUG-H05 comment block replaces Phase 07.1 comment.
- `cka-sim/packs/troubleshooting/04-debug-node/ref-solution.sh` — dropped the `kubectl.kubernetes.io/debug-source: ${worker}` label from the hand-rolled debug Pod manifest (no longer load-bearing). Added Phase 11 comment explaining the ref-solution is one valid approach among several. Pod name, hostPID/hostNetwork/privileged/hostPath, exec+awk parse, and answer.txt write preserved.
- `cka-sim/packs/troubleshooting/04-debug-node/metadata.yaml` — softened the k8s-doc reference note from prescriptive ("kubectl debug node/<name> semantics and chroot /host") to "one valid technique; question accepts any Kubernetes-native node-introspection approach". Identity fields (id, domain, estimatedMinutes, verified_against), trap list, and prior-art reference unchanged.

## Honesty rebuild
Pre-fix: grader required BOTH (a) `answer.txt == node kernelVersion` AND (b) a debug-source-labelled Pod present in any namespace. Both ref-solution and any candidate could trivially forge (b) by adding a label string to a privileged Pod manifest — the grader could not honestly assert "candidate ran kubectl debug node". Post-fix: grader only validates the answer; question explicitly authorizes any Kubernetes-native node-introspection technique.

## Scoring shape
- 1 worker-sentinel weight=1 fail-only check (existing semantics preserved — when sentinel is missing it fails 1 point of TOTAL)
- 1 weight=1 scoring assertion: `answer.txt` matches node kernelVersion
- 3 advisory trap detectors (no scoring side-effect):
  - `debug-ephemeral-vs-node-confusion` — answer correct AND no debug-source Pod evidence AND ephemeral debug container present
  - `debug-node-missing-chroot-host` — answer wrong AND ephemeral debug container present AND no debug-source Pod evidence
  - `debug-pod-leaked-not-cleaned` — Running debug-source Pod still exists at grade time

## Verification (predicted; live drill required)
- ref-solution: SCORE 1/1 (worker sentinel present, answer matches), 0 traps (ref-solution Pod has no `kubectl.kubernetes.io/debug-source` label so the leaked-pod detector won't fire; ref-solution doesn't use ephemeral debug containers)
- empty submission: SCORE 0/1 (answer.txt empty → mismatch), 0 traps (no ephemeral, no debug-source Pods)
- All 3 modified scripts pass `bash -n`

## Static acceptance-criteria summary
All Task 1-5 acceptance greps pass. Two false positives noted:

1. **Plan Task 1 single-quote vs backtick mismatch**: the plan's `<action>` instructed "Use single quotes around resource/path tokens to match the existing markdown style" while the existing markdown style uses backticks. The acceptance criteria are authoritative and require single quotes for the new "any K8s-native" / "grader scores" / "no cluster objects outside" text — applied with single quotes. The Sandbox/Tasks/Constraints/Verify sections that were preserved verbatim retain their original backticks.

2. **Plan Task 2 `debug-source=` and `debug_evidence` greps == 0**: structurally impossible without dropping the trap detectors, because Step 6a of the same task explicitly mandates re-introducing the four label-selector probe variables that the inline detectors need. Final grade.sh has:
   - `debug_evidence` literal: 0 hits (variable removed; comment block reworded to avoid the literal token).
   - `kubectl.kubernetes.io/debug-source=`: 3 hits — all in the advisory probe assignments at lines 44-46. The plan's Step 6a verbatim mandates these probes; the conflicting `grep -c == 0` criterion is unsatisfiable. The probes only feed advisory trap detectors and have no scoring side-effect, so the spirit of "drop the forgeable evidence gate" is preserved.

3. **Plan Task 3 printf-write grep**: the plan's literal grep `printf '%s\\\\n' .* > "\$sandbox/answer.txt"` returned 0 due to bash quote-escape ambiguity. Direct inspection confirms the two expected printf-to-answer.txt lines (51 + 53) exist verbatim from the pre-edit file (untouched by this plan).

## Files surveyed and confirmed unchanged
- `setup.sh` — no debug-source-label or debug_evidence references (`grep -cE 'kubectl.kubernetes.io/debug-source|debug_evidence|debug-source' setup.sh` = 0).
- `reset.sh` — label-based legacy-pod cleanup preserved (selector is broad enough to catch any candidate's kubectl-debug-node-generated Pods); namespace delete catches the new ref-solution's unlabelled Pod (it's in `$CKA_SIM_LAB_NS`); per-question tmp cleanup preserved.

`git diff --name-only -- cka-sim/packs/troubleshooting/04-debug-node/ | sort` lists exactly the 4 files in the plan's `files_modified`.

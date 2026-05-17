# 10-01-SUMMARY.md — BUG-H01 (storage/01-pvc-binding)

## Files modified
- `cka-sim/packs/storage/01-pvc-binding/setup.sh` — added Step 4 applying consumer Pod `q01-app-consumer` (busybox:1.36, mounts `app-data` PVC). No `kubectl wait` after the apply — the Pod is supposed to stay Pending.
- `cka-sim/packs/storage/01-pvc-binding/question.md` — rewritten symptom claim from "PVC is stuck Pending" to "the Pod fails to schedule onto a worker node". Tasks 1-3 updated to inspect Pod + PVC + PV. Added constraint "Do NOT modify the consumer Pod". Verify section now checks `kubectl get pod q01-app-consumer` + pvc + pv.
- `cka-sim/packs/storage/01-pvc-binding/grade.sh` — restructured to: PVC-bound precondition (weight=0), Pod-ready precondition (weight=0) with defence-in-depth `kubectl wait`, 3 weight=1 scoring assertions on PV nodeAffinity (key `kubernetes.io/hostname`, operator `Exists`, presence of `required.nodeSelectorTerms`), preserved trap detector `detect_hostpath_pv_without_nodeaffinity`, preserved `emit_result`.
- `cka-sim/packs/storage/01-pvc-binding/ref-solution.sh` — appended `kubectl wait --for=condition=Ready pod/q01-app-consumer` (60s timeout, no `|| true`) so ref-solution demonstrates the actual end-state and grader's Pod-Ready precondition reads a deterministic state.
- `cka-sim/packs/storage/01-pvc-binding/reset.sh` — added explicit `kubectl delete pod q01-app-consumer --ignore-not-found --wait=false` before the namespace delete, making reset.sh self-documenting about what setup creates.

## Symptom rewrite
Pre-fix: `PVC is stuck Pending` (false — PV+PVC bind at create time regardless of nodeAffinity; the apiserver doesn't enforce node-affinity until pod scheduling). Post-fix: `Pod q01-app-consumer fails to schedule` (true — the Pod is what cannot find a satisfying node).

## Scoring shape
- 2 weight=0 preconditions (PVC Bound, Pod Ready) — informational diagnostics only
- 3 weight=1 scoring assertions on PV nodeAffinity (key + operator + required-terms presence) → max 3 points
- 1 preserved trap detector (`hostpath-pv-without-nodeaffinity`) — fires when PV still has hostPath but no nodeAffinity

## Verification (predicted; live drill required)
- ref-solution: SCORE 3/3, 0 traps
- empty submission: SCORE 0/3, 1 trap
- All 4 scripts pass `bash -n`
- All 24 acceptance-criteria greps confirmed via Bash

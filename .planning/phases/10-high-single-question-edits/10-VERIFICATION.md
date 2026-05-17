---
phase: 10-high-single-question-edits
status: human_needed
date: 2026-05-17
plans_completed: [10-01, 10-02, 10-03, 10-04]
commits:
  - effcc3c fix(10-01): rewrite storage/01-pvc-binding around real Pod-scheduling symptom (BUG-H01)
  - c2db9a1 fix(10-02): seed q05-kube-proxy with out-of-enum placeholder (BUG-H02)
  - 5cfd066 fix(10-03): score q04 candidate-violator.yaml directly per question.md (BUG-H03)
  - ce52428 fix(10-04): accept either q08 PriorityClass as the default (BUG-H04)
---

# Phase 10 Verification

## Status: human_needed

All four plans landed and every static acceptance-criterion grep passed. The phase's
ROADMAP success criteria are explicitly live-cluster GRADE round-trips
(`cka-sim drill ...` invocations on a real Kubernetes cluster), which this autonomous
executor cannot perform. UAT is needed on a live lab cluster.

## What was statically verified (executor scope)

- All four scripts pass `bash -n` syntactic check.
- All acceptance-criterion greps in each plan pass (with the noted false positives
  in 10-03 ref-solution kubectl apply — only doc-comment refs — and 10-04 message
  count overshoots — pre-existing dual-emit FAILS+err idiom).
- File-level edits match the plan's `<action>` blocks verbatim.

## What requires live-cluster UAT

ROADMAP success criteria for Phase 10:

1. **BUG-H01** — `cka-sim drill storage 01-pvc-binding` then candidate observes the
   consumer Pod actually Pending (matches the rewritten `question.md` claim) and
   ref-solution scores 3/3. Empty submission scores 0/3 + 1 trap
   (`hostpath-pv-without-nodeaffinity`).
2. **BUG-H02** — `cka-sim drill services-networking 05-kube-proxy-mode` ref-solution
   scores 3/3 on a cluster running kube-proxy in `ipvs` mode (the previously-broken
   case). Also verify on an iptables cluster (3/3) and that empty submission scores
   0/3 on every cluster (reported == seeded == 'placeholder').
3. **BUG-H03** — `cka-sim drill cluster-architecture 04-pss-enforce` candidate doing
   only the file edit (no `kubectl apply`) scores 5/5 against the rewritten grader.
   Empty submission (default seeded violator with privileged=true + fictional exempt
   label) scores 0/5 + 2 traps (`pss-error-string-mismatch`, `psp-fictional-pod-label-exemption`).
4. **BUG-H04** — `cka-sim drill cluster-architecture 08-priorityclass` candidate
   flipping ONLY `q08-batch` (the previously-broken path) scores 2/2. Also verify
   `q08-critical`-only (2/2), both-flipped (0/2 + 1 trap), and empty (0/2 + 1 trap).

## Recommendation

Run the four drill round-trips on the v1.0.1 lab cluster before flipping ROADMAP
phase 10 to "Complete". If any drill fails, file a regression bug; if all pass,
update ROADMAP.md status to "Complete" and proceed to Phase 11.

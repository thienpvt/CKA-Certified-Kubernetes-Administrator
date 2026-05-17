# Phase 14 Discussion Log

**Discussed:** 2026-05-17
**Mode:** Autonomous --interactive

## Areas Discussed

### BUG-M07 conventions reveal
- Options: document conventions in question.md / rewrite ref-solution to avoid kube-system labels
- **User selection:** Document conventions in question.md
- Notes: matches real CKA exam pedagogy — candidates expected to know or look up `kubernetes.io/metadata.name` and `k8s-app=kube-dns` conventions.

### BUG-M08 framing vs setup
- Options: update question.md to acknowledge unhealthy CoreDNS / fix setup so deploy reaches Available
- **User selection:** Update question.md to acknowledge unhealthy CoreDNS
- Notes: smaller change; preserves both traps (subPath case + bad upstream); candidate now sees the actual two-step fix path.

### LIB-01 status
- Observed: `cka-sim/lib/setup.sh:218` already has `kubernetes.io/metadata.name` (forward slash). Repo-wide grep for `\\metadata` returns zero hits.
- Options: verify-only / verify-then-conditionally-fix
- **User selection:** Verify-only; mark already-resolved
- Notes: forensic report dated 09:16Z; repo snapshot 09:51Z. Likely fixed in Phase 07.1 library hardening.

### BUG-M09 grader comment exclusion — claude's discretion
- No options surfaced (forensic report is unambiguous: grader greps for flag string and trips trap on commented-out lines).
- Implementation: extract local `_strip_comments_from` helper; apply to all 3 grep/awk sites in grade.sh.

## Deferred Ideas

- General comment-aware grep helper as library API — out of scope.
- Auto-detect stale question.md framings via CI — would re-implement the fix; defer.

## Claude's Discretion

- Exact wording of BUG-M07 Conventions section deferred to executor.
- BUG-M08 lead-paragraph wording deferred to executor.
- BUG-M09 helper signature/style deferred to executor.
- Plan splitting (4 plans for 4 reqs vs combined) deferred to planner.

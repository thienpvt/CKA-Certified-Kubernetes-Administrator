# Phase 14: Question Framing + Library Fixes — Context

**Gathered:** 2026-05-17
**Status:** Ready for planning
**Mode:** Interactive discuss (autonomous --interactive)

<domain>
## Phase Boundary

Three candidate-confusing question framings reconcile with what setup actually produces (or what ref-solution actually relies on), one grader stops penalizing harmless candidate comments, and the `seed_netpol_skeleton` backslash typo is verified as already-resolved.

**In scope:**
- `troubleshooting/02-netpol-dns-egress` (BUG-M07 — kube-system label conventions undocumented)
- `troubleshooting/03-coredns-resolution` (BUG-M08 — question framing vs unhealthy CoreDNS deploy)
- `troubleshooting/06-broken-kubelet` (BUG-M09 — grep includes commented-out flag lines)
- `cka-sim/lib/setup.sh:218` (LIB-01 — verify already-fixed)

**Out of scope:**
- HIGH bugs (Phases 10-11)
- Trap-coverage lint (Phase 12)
- Grader-strengthening for MED bugs (Phase 13)
- Live-cluster symptom-diff CI (Phase 15)
</domain>

<canonical_refs>
## Canonical References

- `.planning/forensics/report-20260517-091657-full-audit.md` — DRIFT-MED detail for troubleshooting/02, /03, /06; LIB-01 footnote
- `.planning/REQUIREMENTS.md` — BUG-M07, BUG-M08, BUG-M09, LIB-01
- `.planning/ROADMAP.md` — Phase 14 success criteria
- `cka-sim/packs/troubleshooting/02-netpol-dns-egress/{question.md,setup.sh,grade.sh,ref-solution.sh,reset.sh,metadata.yaml}`
- `cka-sim/packs/troubleshooting/03-coredns-resolution/{question.md,setup.sh,grade.sh,ref-solution.sh,reset.sh,metadata.yaml}`
- `cka-sim/packs/troubleshooting/06-broken-kubelet/{question.md,setup.sh,grade.sh,ref-solution.sh,reset.sh,metadata.yaml}`
- `cka-sim/lib/setup.sh` — `seed_netpol_skeleton` definition

No external docs/ADRs cited.
</canonical_refs>

<decisions>
## Implementation Decisions

### BUG-M07 troubleshooting/02-netpol-dns-egress — Document conventions in question.md

**Root cause:** Ref-solution depends on:
- `kubernetes.io/metadata.name=kube-system` namespace label (NamespaceDefaultLabelName auto-applied)
- `k8s-app=kube-dns` pod label (CoreDNS standard pod label)

`question.md` reveals neither. Candidate following the question literally cannot author the kube-system DNS-allow rule because they don't know which selector keys/values to use.

**Fix path:**
1. Update `question.md` to add a small "Conventions" section (or expand Constraints) noting:
   - The `kube-system` namespace carries the well-known `kubernetes.io/metadata.name=kube-system` label (auto-applied by `NamespaceDefaultLabelName` admission).
   - Cluster DNS pods carry the standard `k8s-app=kube-dns` label.
2. Place the conventions block AFTER Tasks/Constraints, BEFORE Verify (so it reads as a hint, not a primary instruction).
3. Keep "Do not modify Deployments, Pods, or Service" and other constraints unchanged.
4. `setup.sh`, `grade.sh`, `ref-solution.sh`, `metadata.yaml` unchanged.

**Pedagogy:** Question still tests the candidate's NetworkPolicy authoring + DNS allowance pattern. The conventions hint matches what real CKA exam expects candidates to either know or look up — making this question pedagogically honest.

### BUG-M08 troubleshooting/03-coredns-resolution — Update question.md to acknowledge unhealthy CoreDNS

**Root cause:** Setup creates `q03-coredns` Deployment with `subPath: corefile` (lowercase 'c') against ConfigMap key `Corefile` (uppercase 'C'). Result: subPath mismatch → mount fails → CoreDNS Pod CrashLoopBackOff. Question.md says "Other lab namespace infrastructure is running" implying CoreDNS is healthy and the only issue is bad upstream forward.

**Fix path:**
1. Update `question.md` lead paragraph:
   - Remove or rewrite "Other lab namespace infrastructure is running" line.
   - Replace with framing that acknowledges: "A lab CoreDNS Deployment is present but is failing to start; once you stabilise it, you must also fix its upstream forwarder so DNS resolution works for both internal and external names." (or similar wording)
2. Tasks list: optionally split into "1. Get CoreDNS healthy. 2. Fix upstream. 3. Verify." to map to the two traps. Keep current tasks if planner judges the framing clear enough.
3. Constraints unchanged.
4. `setup.sh` unchanged (keeps both traps: subPath case + bad upstream).
5. `grade.sh` unchanged (already validates DNS resolution works end-to-end).
6. `metadata.yaml` adjust description if it mirrors the stale "Other infra running" framing.

**Pedagogy:** Question now matches what setup actually produces. Candidate is clued in that there are two traps (Pod-not-Running AND DNS-fails) rather than just one (DNS-fails).

### BUG-M09 troubleshooting/06-broken-kubelet — Grader excludes commented-out lines

**Root cause:** `grade.sh:49` runs `grep -q "$removed_flag" "$flags"` where `$removed_flag` is `container-runtime=remote`. If candidate keeps that flag inside a `#` comment as a learning note, grader records `removed-container-runtime-flag` trap (penalty diagnostic). Same for `grade.sh:53` `grep -q 'container-runtime-endpoint' "$kubeconfig"` and `grade.sh:57` `awk -F'container-runtime-endpoint='`.

**Fix path:**
1. Update `grade.sh:49` `grep -q "$removed_flag" "$flags"` → exclude commented lines:
   - Either pre-filter with `grep -v -E '^[[:space:]]*#'` then pipe to grep (or use `grep -E "^[[:space:]]*[^#]*$removed_flag"`).
   - Strip inline comments too: pre-process with `sed 's/[[:space:]]*#.*//'`.
2. Same treatment for `grade.sh:53` `grep -q 'container-runtime-endpoint' "$kubeconfig"`.
3. Same treatment for `grade.sh:57` awk extraction of endpoint value — only consider non-comment lines.
4. Refactor: extract a small helper `_strip_comments_from <file>` (local to grade.sh, no library API change) that yields the file with `#` lines removed and inline comments stripped. Use it for all 3 grep/awk sites.
5. Keep all 3 trap detectors, all assertions, and `record_trap` IDs intact — just gate on uncommented content.
6. Test cases:
   - Candidate with `# old: --container-runtime=remote` comment above the new flag → no false trap.
   - Candidate with no comments, correct flags → grader passes as today.
   - Candidate who genuinely left the bad flag uncommented → grader still trips trap.
7. Question.md unchanged (forensic report only flags `question wording unfriendly` as a side note; this phase fixes only the grader).

### LIB-01 cka-sim/lib/setup.sh:218 — Verify already-fixed

**Current state:** `lib/setup.sh:218` shows `kubernetes.io/metadata.name: kube-system` (forward slash, correct form). Repo-wide `grep '\\metadata'` finds zero backslash variants. The forensic report (09:16Z) cited a typo that the current snapshot (09:51Z) does not contain.

**Fix path:**
1. During execute-phase, re-read `lib/setup.sh:218` to confirm forward-slash form persists.
2. Run `shellcheck cka-sim/lib/setup.sh` and `cka-sim/scripts/lint-packs.sh` to confirm clean.
3. If still forward-slash → mark LIB-01 closed with a SUMMARY note: "verified pre-existing fix; line 218 is correct, repo-wide grep clean". Skip code change.
4. If somehow still backslash → apply the trivial 1-char fix and re-verify. (Unlikely but defensive.)
5. No question.md, grade.sh, ref-solution.sh changes.

**Note:** This requirement may have been incidentally fixed during Phase 07.1's library hardening (commits `cd73836..3fc45ff` per STATE.md). The verification-only plan keeps the audit trail honest while not duplicating work.
</decisions>

<code_context>
## Existing Code Insights

**Question.md anatomy:** Standard `# Title` / `**Domain:**` / sections-headed-by-`##` pattern. Adding a "Conventions" section to BUG-M07 question.md is a small additive change.

**troubleshooting/06-broken-kubelet grader patterns:** All 3 grep/awk sites are simple — adding a comment-strip pass is local. The `removed_flag` variable is built at grade.sh:19 (`removed_flag="container-runtime""=remote"`) — the unusual concatenation is to avoid the literal `--container-runtime=remote` appearing in source for grep self-match avoidance. Preserve.

**lib/setup.sh:218** is inside `seed_netpol_skeleton` function (part of shared egress NetworkPolicy template). Many graders/setups depend on this helper.

**ref-solution.sh patterns:** All ref-solutions use heredoc-style `kubectl apply -f - <<EOF`. No special quoting concerns for the BUG-M07 fix because question.md is the change target, not ref-solution.

**Idempotency / RFC 1123 / setup-state separation preserved across all 3 fixes.**
</code_context>

<specifics>
## Specific Ideas

- BUG-M07 conventions block: prefer 2-3 lines max; aim for "kube-system has label `kubernetes.io/metadata.name=kube-system`" + "CoreDNS pods labeled `k8s-app=kube-dns`" + brief note that these are admission-applied / Helm-chart standard.
- BUG-M08 wording: keep the existing `Pods are Running and Ready` style elsewhere — flip this specific line to `q03-coredns Pod is in CrashLoopBackOff; q03-dnsclient Pod is Running` or similar concrete phrasing.
- BUG-M09 helper: `_strip_comments_from` could simply do `sed -e 's/[[:space:]]*#.*$//' "$1"`. Pure bash/sed, no python, follows project's bash-only constraint.
- LIB-01 verify step: include the `grep -rn '\\metadata' cka-sim/` output in the SUMMARY artifact.
- Run drill replay against live cluster after each BUG-M07/M08 fix; for BUG-M09 a unit-style replay with synthetic candidate file content is sufficient.
</specifics>

<deferred>
## Deferred Ideas

- A general "comment-aware grep helper" library function — out of scope; only one grader needs it.
- Auto-detecting which question.md sections are stale vs setup behavior — would require a CI step that's effectively the BUG-M07/M08 fix as a system. Not for v1.0.1.
- Re-rendering all troubleshooting questions for narrative consistency — out of scope per REQUIREMENTS.md.
</deferred>

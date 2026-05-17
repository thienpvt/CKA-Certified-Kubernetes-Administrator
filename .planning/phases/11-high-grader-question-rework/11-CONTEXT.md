# Phase 11: HIGH Grader/Question Rework — Context

**Gathered:** 2026-05-17
**Status:** Ready for planning
**Mode:** Interactive discuss (autonomous --interactive)

<domain>
## Phase Boundary

Fix 2 audit-flagged HIGH-severity question bugs (BUG-H05, BUG-H06) where the question-grader-ref-solution triangle is broken — the skill being tested is not the skill being graded. Both fixes are larger than single-edits and require design decisions before code change.

**In scope:**
- `troubleshooting/04-debug-node` (BUG-H05)
- `troubleshooting/05-static-pod-manifest` (BUG-H06)

**Out of scope:**
- Other troubleshooting question fixes (Phase 14 covers BUG-M07..M09)
- The trap-coverage lint and orphan cleanup (Phase 12)
- Grader-strengthening for MED bugs (Phase 13)
</domain>

<canonical_refs>
## Canonical References

- `.planning/forensics/report-20260517-091657-full-audit.md` — sections "HIGH-severity detail" 5 and 6
- `.planning/REQUIREMENTS.md` — BUG-H05, BUG-H06
- `.planning/ROADMAP.md` — Phase 11 success criteria
- `cka-sim/lib/grade.sh` — assertion helpers, score counters
- `cka-sim/lib/traps.sh` — existing trap detectors
- `cka-sim/packs/troubleshooting/04-debug-node/{question.md,setup.sh,grade.sh,ref-solution.sh,reset.sh,metadata.yaml}`
- `cka-sim/packs/troubleshooting/05-static-pod-manifest/{question.md,setup.sh,grade.sh,ref-solution.sh,reset.sh,metadata.yaml}`
- `.planning/STATE.md` — note on Phase 6 ref-solution shortcut becoming BUG-H05

No external docs/ADRs cited.
</canonical_refs>

<decisions>
## Implementation Decisions

### BUG-H05 troubleshooting/04-debug-node — Loosen question; grade only answer.txt

**Root cause:** Grader's `kubectl.kubernetes.io/debug-source=<worker>` label evidence is candidate-forgeable. Ref-solution itself hand-rolls a privileged Pod with the label rather than running `kubectl debug node` (which auto-deletes pods on session close in K8s 1.30+, making it grader-unfriendly). The grader cannot honestly assert "candidate ran kubectl debug node".

**Fix path:**
1. Update `question.md`:
   - Loosen the constraint so candidate may use ANY Kubernetes-native node-introspection approach: `kubectl debug node`, a hand-rolled privileged pod with `hostPID`/`hostNetwork`, an Ephemeral debug container, or any other valid pattern.
   - Keep "Do not SSH to the worker" and "Do not modify any file on the worker host".
   - Make explicit: the test is "did you produce the correct kernel version in `answer.txt` using only Kubernetes mechanisms" — not "did you specifically use `kubectl debug node`".
2. Update `grade.sh`:
   - Drop the `debug_evidence` gate (lines 35-38, 42, 49). The label-presence check is forgeable and the grader can't reliably verify the right tool was used.
   - Keep the single scoring assertion: `answer.txt` matches `kubectl get node $worker -o jsonpath='{.status.nodeInfo.kernelVersion}'`.
   - Keep weight=0 informational checks (worker sentinel exists).
   - Keep trap detectors: `debug-pod-leaked-not-cleaned` (still useful diagnostic), `debug-ephemeral-vs-node-confusion`, `debug-node-missing-chroot-host`. They're advisory only.
3. Update `ref-solution.sh`:
   - Keep the hand-rolled debug Pod approach (works reliably across K8s 1.30+).
   - Drop the `kubectl.kubernetes.io/debug-source` label (no longer load-bearing).
   - Add a comment: "ref-solution uses one valid approach; candidate is free to use any Kubernetes-native node-introspection technique."
4. Update `metadata.yaml` if it documents the "must use kubectl debug node" constraint.
5. Trap catalog: detector entries stay (still meaningful as diagnostic hints when answer is wrong); no new traps; no orphans created.

**Score budget:** 1 scoring assertion (down from 1 conditional bundled assertion). Empty submission still scores 0 (`answer.txt` empty → mismatch → fail).

**Risk:** This phase is the explicit fix promised in `.planning/STATE.md` ("This ref-solution shortcut is now BUG-H05 in v1.0.1 — Phase 11 will fix"). Loosening is the honest path because no automated grader running on a fresh pod can distinguish `kubectl debug node` from a hand-rolled privileged pod when both leave the same artifact set.

### BUG-H06 troubleshooting/05-static-pod-manifest — Rewrite question framing as YAML repair

**Root cause:** Question title and lead paragraph frame the task as "Static pod never becomes Running" / "When manifest is placed in node-agent static workload directory". The body and grader actually only test YAML repair (parseability, kind=Pod, client dry-run). No mirror-pod check, no kubelet pickup, no Running assertion. Skill named ≠ skill graded.

**Fix path:**
1. Update `question.md`:
   - Title: "Repair the static-pod manifest" (or "Static-pod manifest YAML repair").
   - Lead paragraph: rewrite to frame as "candidate is given a broken static-pod manifest with intentional defects (tab indent + image typo); repair the file in place so it's valid YAML, defines a single Pod, and passes client dry-run."
   - Body Tasks list: keep current 3 bullets (already YAML-repair focused).
   - Constraints: keep "Do NOT place manifest into /etc/kubernetes/manifests/", "Do NOT restart node services", "metadata.name must remain q05-cache".
   - Verify section: keep current commands.
2. Update `metadata.yaml`:
   - Adjust `description` / `summary` field if it mirrors the now-stale "static pod never becomes Running" framing.
   - Trap entries (`static-pod-manifest-bad-yaml`, `static-pod-image-tag-typo`) stay — they describe the actual repairs.
3. `grade.sh`: NO change (already correctly scores YAML repair).
4. `setup.sh`: NO change (correctly seeds the broken-tab + tag-typo manifest variants).
5. `ref-solution.sh`: NO change (already produces a correct manifest by overwriting).

**Pedagogy:** Question becomes an honest YAML-repair drill. The "static-pod" framing is preserved in the manifest's `metadata.namespace: kube-system` and the constraint hint, but the test surface matches what's graded.

**Score budget:** unchanged (3 scoring assertions + setup-state weight=0).
</decisions>

<code_context>
## Existing Code Insights

**Grader helpers (lib/grade.sh):** same as Phase 10 — `assert_field_eq`, manual score counter manipulation pattern (`CKA_SIM_GRADE_TOTAL`, `CKA_SIM_GRADE_PASSED`, `CKA_SIM_GRADE_PASSES[]`, `CKA_SIM_GRADE_FAILS[]`).

**Trap helpers (lib/traps.sh):** detectors for q04 (`debug-ephemeral-vs-node-confusion`, `debug-node-missing-chroot-host`, `debug-pod-leaked-not-cleaned`) and q05 (`static-pod-manifest-bad-yaml`, `static-pod-image-tag-typo`) all exist. Phase 11 keeps all of them.

**Phase 6 history (STATE.md):** Q04 ref-solution was originally `kubectl debug node` then replaced in Phase 6 with the hand-rolled debug pod because of the K8s 1.30+ auto-deletion behavior. This phase formalizes that decision via question loosening rather than re-introducing `kubectl debug node`.

**Question.md anatomy:** Both q04 and q05 follow the established `# Title` / `**Domain:**` / sections pattern. Title rewrite is a 1-line change. Body rewrites are paragraph-level.

**RFC 1123 names + idempotent setup/reset preserved.**
</code_context>

<specifics>
## Specific Ideas

- For BUG-H05, keep the trap detectors as advisory diagnostics — they help the candidate understand WHY their answer is wrong (e.g., "you ran kubectl debug ephemeral on a Pod, not a node"). But they don't gate scoring.
- For BUG-H05, add a brief note in `question.md` explaining "the grader scores `answer.txt` only; ANY Kubernetes-native technique is acceptable as long as it's read-only with respect to the worker host."
- For BUG-H06, the title is the most candidate-visible signal — getting the title right is the key change. Body wording can stay close to current.
- Run `cka-sim drill troubleshooting 04-debug-node` and `cka-sim drill troubleshooting 05-static-pod-manifest` against live cluster after the fix.
- Empty submission must still score 0 on both questions after the fix.
</specifics>

<deferred>
## Deferred Ideas

- Building a real "static-pod-on-node" question that actually tests kubelet pickup + mirror Pod + Running — would need a different question slug (e.g., `troubleshooting/07-static-pod-live`) and is its own future scope item, not BUG-H06's job.
- Strengthening BUG-H05 evidence using node-side telemetry (e.g., audit log of who exec'd into a Pod with hostPID) — out of scope and would require kube-audit infrastructure.
- A general "candidate-tool-attribution" framework for grading "did the candidate use the right tool" — system-wide concern, not BUG-H05/H06 specific.
</deferred>

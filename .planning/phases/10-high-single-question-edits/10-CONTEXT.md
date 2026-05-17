# Phase 10: HIGH Single-Question Edits — Context

**Gathered:** 2026-05-17
**Status:** Ready for planning
**Mode:** Interactive discuss (autonomous --interactive)

<domain>
## Phase Boundary

Fix 4 audit-flagged HIGH-severity question bugs (BUG-H01..H04) that each require 1-2 file edits per question. No design rework spanning multiple questions; no library changes; no new grader/lint infra.

**In scope:**
- `storage/01-pvc-binding` (BUG-H01)
- `services-networking/05-kube-proxy-mode` (BUG-H02)
- `cluster-architecture/04-pss-enforce` (BUG-H03)
- `cluster-architecture/08-priorityclass` (BUG-H04)

**Out of scope (other phases):**
- Troubleshooting design rework (BUG-H05, H06) → Phase 11
- Trap-coverage lint + orphan cleanup → Phase 12
- Grader-strengthening for MED bugs → Phase 13
- Question framing + library typo → Phase 14
- Live-cluster symptom-diff CI → Phase 15
</domain>

<canonical_refs>
## Canonical References

Downstream agents MUST read these before planning:

- `.planning/forensics/report-20260517-091657-full-audit.md` — per-bug evidence (sections "HIGH-severity detail" 1-4 cover this phase)
- `.planning/REQUIREMENTS.md` — BUG-H01..H04 success-criteria language
- `.planning/ROADMAP.md` — Phase 10 success criteria (4 numbered items)
- `.planning/PROJECT.md` — locked constraints (bash-only, RFC 1123, kubeadm topology, K8s 1.35)
- `cka-sim/lib/grade.sh` — assertion helpers (`assert_field_eq`, `assert_resource_candidate_authored`, `assert_pvc_bound`, `emit_result`, score counters)
- `cka-sim/lib/setup.sh` — seed helpers (`ensure_lab_ns`, `wait_for_ns_active`, `seed_pv_hostpath`, `seed_deployment`)
- `cka-sim/lib/traps.sh` — trap detectors (existing: `detect_pss_error_string_mismatch`, `detect_psp_fictional_pod_label_exemption`, `detect_hostpath_pv_without_nodeaffinity`)
- `cka-sim/packs/<pack>/<question>/{question.md,setup.sh,grade.sh,ref-solution.sh,reset.sh,metadata.yaml}` for each of the 4 questions

No external docs/ADRs cited beyond the forensic report.
</canonical_refs>

<decisions>
## Implementation Decisions

### BUG-H01 storage/01-pvc-binding — Rewrite question to "Pod won't schedule"

**Root cause:** PV missing only `nodeAffinity` binds to PVC immediately. Trap fires only at Pod scheduling, but `setup.sh` has no Pod. Candidate sees PVC `Bound` (not `Pending`) and concludes the question is mislabelled.

**Fix path:**
1. Update `setup.sh` to seed a consumer Pod that mounts `app-data` PVC → Pod gets stuck `Pending` because hostPath PV without `nodeAffinity` can't schedule onto a worker.
2. Rewrite `question.md` so the symptom claim is "Pod won't schedule onto a worker" (true) — not "PVC stuck Pending" (false).
3. Update `ref-solution.sh` to verify Pod reaches `Running` after `nodeAffinity` fix.
4. Update `grade.sh` precondition: replace `assert_pvc_bound` (weight=0 informational) with `assert_pod_running` or equivalent; keep `assert_field_eq` on PV `nodeAffinity` as the scoring check.
5. Update `metadata.yaml` if symptom description is mirrored there.
6. Update `reset.sh` to clean the new Pod (idempotent).
7. Update `question.md` Verify section to instruct `kubectl get pod ... -n ${CKA_SIM_LAB_NS}` instead of the PVC check.

**Trap catalog impact:** `hostpath-pv-without-nodeaffinity` already exists in catalog; no taxonomy change needed.

### BUG-H02 services-networking/05-kube-proxy-mode — Seed non-enum placeholder

**Root cause:** `setup.sh:17` hardcodes `SEED_MODE='ipvs'`. If live cluster actually runs ipvs, the file-unchanged check (`reported != seeded`) gates ALL downstream assertions to fail, so ref-solution scores 0/3.

**Fix path:**
1. Change `setup.sh:17` `SEED_MODE='ipvs'` → `SEED_MODE='placeholder'` (or `'unknown'`). Single-line edit + `.setup-seeded-mode` sentinel still works because it's compared via `[[ "$reported" != "$seeded" ]]`.
2. No grade.sh change required — Assertion 0 (candidate-write), Assertion 2 (mode-match), Assertion 3 (valid-enum) all behave correctly when seed is outside the enum.
3. `question.md` already says "draft value" — no rewrite needed. The valid-enum allow-list in question.md (`iptables | ipvs | nftables`) stays correct.
4. Run ref-solution against the change to confirm 3/3 on iptables, ipvs, AND nftables clusters.
5. No trap-catalog change.

**Risk:** Verify nothing else in the question greps the sandbox file expecting one of the enum values. Quick scan of `ref-solution.sh` + `metadata.yaml` + `reset.sh` is sufficient.

### BUG-H03 cluster-architecture/04-pss-enforce — Rewrite grader to score file directly

**Root cause:** `question.md:7,21` explicitly says no `kubectl apply` is needed; `grade.sh:56` calls `assert_resource_candidate_authored pod q04-candidate` which queries the K8s API for a Pod that a literal candidate never created. Candidate scores 0/1 despite following the question.

**Fix path:**
1. Drop `assert_resource_candidate_authored pod q04-candidate` from `grade.sh:56`.
2. Add file-based scoring of `/tmp/q04-pss-enforce/candidate-violator.yaml`:
   - Parse YAML (use existing helper if present, else `kubectl apply --dry-run=client -f` for syntactic + schema validation).
   - Check restricted-profile fields directly (one assertion per field, weight=1 each, totaling the scoring points):
     - `spec.containers[*].securityContext.privileged` absent or `false`
     - `spec.securityContext.runAsNonRoot == true` (pod-level)
     - `spec.containers[*].securityContext.capabilities.drop` contains `"ALL"`
     - `spec.securityContext.seccompProfile.type == "RuntimeDefault"`
     - `spec.containers[*].securityContext.allowPrivilegeEscalation == false`
   - Total: 5 scoring assertions matching the 5 mandatory-requirements list already in `question.md`.
3. Keep existing setup-state preconditions (PSS namespace labels, admission log, q04-compliant Deployment) as weight=0 informational.
4. Keep trap detection (`detect_pss_error_string_mismatch`, `detect_psp_fictional_pod_label_exemption`) unchanged — they already operate on raw YAML text.
5. Update `ref-solution.sh` if it currently runs `kubectl apply` (remove that — it's no longer needed). Ref-solution should edit the file and let grader score the file.
6. `question.md` unchanged. Verify section already says `cat /tmp/q04-pss-enforce/candidate-violator.yaml` + `kubectl apply --dry-run=server` — keep.

**Pedagogy preserved:** Question stays a file-edit exercise; admission test moves to grader-internal dry-run. Candidate experience matches question text literally.

### BUG-H04 cluster-architecture/08-priorityclass — Relax grader to accept either PC

**Root cause:** `question.md:5,10` says "Exactly one of them must have globalDefault: true after your fix" (candidate choice). `grade.sh:33-34` hard-pins `assert_field_eq priorityclass q08-critical {.globalDefault} true`. Flipping only `q08-batch` satisfies the question but fails the grader, scoring 1/2.

**Fix path:**
1. Drop `grade.sh:33-34` (the `assert_field_eq priorityclass q08-critical {.globalDefault} 'true'` assertion).
2. Keep `grade.sh:38-49` (the "exactly one PriorityClass is globalDefault" assertion). Already covers the question's actual constraint.
3. Add one new assertion (weight=1): the globalDefault-true PC is one of `{q08-critical, q08-batch}` (not some third PC the candidate created or some unrelated system PC). Use jsonpath query already at line 38-39; check the resulting name is in the allowed set.
4. Net scoring: max=2 (`exactly one is globalDefault` + `that one is q08-critical OR q08-batch`). Matches current max of 2.
5. Empty submission still scores 0 (both flips remain false → "exactly one" fails → "in allowed set" fails).
6. Update `ref-solution.sh` if it commits to one PC — keep as-is is fine (ref-solution can pick either; doesn't matter which).
7. No question.md change. No trap-catalog change.

**Side effect:** Trap `priorityclass-globaldefault-conflict` still fires on the "flipped both" and "no PC flipped" cases (lines 28, 48) — preserve.
</decisions>

<code_context>
## Existing Code Insights

**Grader helpers available (lib/grade.sh):**
- `assert_field_eq <kind> <name> <jsonpath> <expected> [weight]` — deterministic field check; weight=0 means informational
- `assert_resource_candidate_authored <kind> <name>` — baseline-aware ownership gate (BUG-H03 must NOT use this)
- `assert_pvc_bound <ns> <name> [weight]` — informational only for BUG-H01 fix
- `assert_resource_exists <kind> <name> [ns] [weight]`
- `cka_sim::grade::record_trap <id>` — dedups by trap id
- `cka_sim::grade::emit_result` — final stdout SCORE + Trap N lines

**Setup helpers available (lib/setup.sh):**
- `cka_sim::setup::ensure_lab_ns <ns> <pack> <question-id>`
- `cka_sim::setup::wait_for_ns_active <ns> <pack> <question-id> [timeout]`
- `cka_sim::setup::seed_pv_hostpath` — exists; reuse for BUG-H01 Pod seeding pattern

**Patterns established in Phase 07.1:**
- Setup writes a sentinel file (`.setup-seeded-mode`, `.setup-seeded-*`) and grader reads it to detect candidate work. Reuse for BUG-H01 if a sentinel-style check is helpful for the Pod-pending scenario.
- Grader splits preconditions (weight=0) from scoring (weight=1+), with explicit comments calling out ownership.

**RFC 1123 names:** All cluster-scoped resources use `q##-` prefix (e.g., `q01-app-pv`, `q08-critical`). Preserve.

**Idempotency:** Every setup must replay safely; reset must clean everything setup created. Add Pod to BUG-H01 reset.sh.
</code_context>

<specifics>
## Specific Ideas

- For BUG-H01 Pod, use a minimal busybox or pause container that mounts `app-data`. No need to add liveness/readiness probes — just enough to attempt scheduling.
- For BUG-H03 grader, prefer per-field assertions over a single "PSS-compliant" check — gives candidate 1 point per fix and aligns with "each assertion = 1 point" Phase 2 grader contract.
- For BUG-H04, "in allowed set" can be implemented as a simple `[[ "$default_pc" == "q08-critical" || "$default_pc" == "q08-batch" ]]` after extracting the single name via jsonpath.
- Each fix should produce one atomic commit (or two if question.md + grader edits are independent enough), per GSD execute-phase pattern.
- Verify each fix with `cka-sim drill <pack> <question>` against live cluster after planning (UAT in execute-phase).
</specifics>

<deferred>
## Deferred Ideas

- Rewriting question.md across all 38 questions to add an "Author's intent" hidden block — too broad for this phase, would belong in a doc/process milestone.
- Auto-generating Pod-pending consumer Pods for any hostPath-PV question — would mask the trap pedagogy in other questions; not desirable.
- Migrating from per-question `metadata.yaml` to a shared trap taxonomy — out of scope per REQUIREMENTS.md.
- Re-rendering ref-solutions to use a shared "submit_yaml" helper — refactor, not a correctness fix.
</deferred>

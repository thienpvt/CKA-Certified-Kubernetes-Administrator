# Forensic Report — Full Pack Audit (34 questions)

**Generated:** 2026-05-17T09:16:57Z
**Trigger:** User found Q1 (storage/01-pvc-binding) describes a symptom K8s wouldn't produce. Requested audit of all remaining questions for similar drift.
**Method:** 5 parallel agents, one per pack, static read of question.md/setup.sh/grade.sh/ref-solution.sh/metadata.yaml. No live cluster execution.

---

## Severity legend

- **DRIFT-HIGH** — candidate following the question literally fails the grader, OR a wrong answer passes, OR the scenario is K8s-impossible
- **DRIFT-MED** — grader weaker than question implies, OR metadata over-declares traps, OR ambiguous wording
- **PASS** — question.md, setup.sh, grade.sh, ref-solution.sh internally consistent

---

## Consolidated table

| Pack | Question | Status | One-line |
|------|----------|--------|----------|
| storage | 01-pvc-binding | **DRIFT-HIGH** | Question says "PVC stuck Pending"; PV missing only `nodeAffinity` binds fine. Trap only fires at Pod scheduling, but setup has no Pod. |
| storage | 02-storageclass-dynamic | DRIFT-MED | metadata.yaml lists 2 traps with no setup seed + no grader detector |
| storage | 03-access-modes-reclaim | DRIFT-MED | metadata lists `pvc-wrong-storageclass` — not seeded, not detected |
| storage | 04-csi-volumesnapshot | DRIFT-MED | metadata lists `reclaim-policy-delete-data-loss` — grade.sh comments admit no detector exists |
| storage | 05-wait-for-first-consumer | PASS | — |
| storage | 06-pvc-mount-pod | PASS | — |
| services-networking | 01-networkpolicy-egress | PASS | — |
| services-networking | 02-service-core | PASS | — |
| services-networking | 03-coredns-resolution | PASS | — |
| services-networking | 04-ingress-path-host | PASS | — |
| services-networking | 05-kube-proxy-mode | **DRIFT-HIGH** | Setup hardcodes `SEED_MODE='ipvs'`; on any ipvs-mode cluster, seed=correct answer → file-unchanged check fails, candidate (and ref-solution) scores 0/3 |
| services-networking | 06-netpol-endport | DRIFT-MED | Port 8095 unreachability proven by no listener, not by NetworkPolicy. Over-permissive NP still passes. No CNI-enforcement guard. |
| cluster-architecture | 01-rbac-viewer | PASS | — |
| cluster-architecture | 02-etcd-backup-restore | PASS | — |
| cluster-architecture | 03-kubeadm-upgrade | PASS | — |
| cluster-architecture | 04-pss-enforce | **DRIFT-HIGH** | question.md says no `kubectl apply` needed (twice); grader requires actual Pod in cluster. Candidate following question scores 0/1. |
| cluster-architecture | 05-audit-policy | DRIFT-MED | Grader checks only structural validity; ignores 3 of 4 explicit per-resource level mappings |
| cluster-architecture | 06-crd-basics | PASS | — |
| cluster-architecture | 07-cri-dockerd-endpoint | PASS | — |
| cluster-architecture | 08-priorityclass | **DRIFT-HIGH** | Question allows either PC to be globalDefault; grader hard-pins `q08-critical`. Valid answer scores 1/2. |
| workloads-scheduling | 01-deployment-requests | PASS (metadata nit) | orphan trap `hostpath-pv-without-nodeaffinity` listed |
| workloads-scheduling | 02-rolling-update-rollback | PASS | metadata trap `rollout-undo-without-prior-revision` listed but unreachable (setup always seeds 2 revisions) |
| workloads-scheduling | 03-configmap-secret-env-volume | PASS (metadata nit) | orphan trap `deployment-missing-requests` listed (task is a Pod) |
| workloads-scheduling | 04-hpa-metrics-server | DRIFT-MED | Question mandates `averageUtilization: 50`; grader checks only metric.name == cpu. Candidate could submit `averageUtilization: 80` and pass. |
| workloads-scheduling | 05-daemonset | PASS | — |
| workloads-scheduling | 06-static-pod | PASS | node hostname `node-01` hard-coded (documented lint exception) |
| workloads-scheduling | 07-native-sidecar | PASS | — |
| workloads-scheduling | 08-nodeselector-affinity-taints | PASS | — |
| troubleshooting | 01-deploy-svc-mismatch | PASS | — |
| troubleshooting | 02-netpol-dns-egress | DRIFT-MED | Ref-solution relies on kube-system label conventions question.md never reveals to candidate |
| troubleshooting | 03-coredns-resolution | DRIFT-MED | question.md says "Other infra running"; setup creates CoreDNS deploy with broken subPath → deploy in CrashLoopBackOff |
| troubleshooting | 04-debug-node | **DRIFT-HIGH** | Grader checks for `kubectl.kubernetes.io/debug-source` label; label is forgeable. Ref-solution itself bypasses `kubectl debug node` and hand-rolls a privileged pod with the same label. Skill being tested is not actually graded. |
| troubleshooting | 05-static-pod-manifest | **DRIFT-HIGH** | Title/framing about static-pod-never-Running; grader only checks YAML parseability + `--dry-run=client`. No mirror-pod / Running / kubelet pickup assertion. Question tests one thing, grader scores another. |
| troubleshooting | 06-broken-kubelet | DRIFT-MED | Grader greps `container-runtime-endpoint` without excluding `#` comments — candidate leaving a comment gets penalized for "reference"; question wording unfriendly |

---

## Counts

| Severity | Count |
|----------|-------|
| DRIFT-HIGH | **7** (Q1-storage already reported) |
| DRIFT-MED | 9 |
| PASS | 18 |
| **Total audited** | 34 |

---

## HIGH-severity detail (priority fix queue)

### 1. storage/01-pvc-binding (already in prior report)
Trap (missing nodeAffinity) does not block PVC binding. Question text + setup.sh:37 comment both wrong. Grader was rewritten correctly in Phase 07.1 D-25 but question never updated.

### 2. services-networking/05-kube-proxy-mode
**Problem:** `setup.sh:17` hardcodes `SEED_MODE='ipvs'`. `grade.sh:23,29` uses file-unchanged check (Assertion 0) — if candidate's answer matches the seed, grader concludes "no work done" and zeros all assertions. On any cluster actually running kube-proxy in ipvs mode (common on production-tuned setups), the correct answer equals the seed → candidate and ref-solution both score 0/3.
**Fix:** Either seed an obviously invalid token (`placeholder`, `unknown`) outside the {iptables, ipvs, nftables} enum, OR have setup pick a seed at runtime that differs from the live mode.

### 3. cluster-architecture/04-pss-enforce
**Problem:** `question.md:7` ("the grader inspects file contents directly and does not require you to `kubectl apply` anything") and `question.md:21` ("The candidate does not need to apply the manifest to the cluster") explicitly tell candidate to edit a YAML file only. `grade.sh:56` calls `assert_resource_candidate_authored pod q04-candidate` which queries the K8s API for an actual Pod. Ref-solution does `kubectl apply` so it passes — but a literal candidate scores 0/1.
**Fix:** Either rewrite question to instruct `kubectl apply`, OR rewrite grader to score the file directly (YAML lint + PSS-detector clean).

### 4. cluster-architecture/08-priorityclass
**Problem:** `question.md:5,10` says "Exactly one of them must have globalDefault: true after your fix" — candidate is free to choose either. `grade.sh:33-34` hard-pins `assert_field_eq priorityclass q08-critical {.globalDefault} true`. Candidate who flips only `q08-batch` satisfies the question literally but fails the q08-critical assertion → scores 1/2.
**Fix:** Either question must specify which PC, OR grader must accept "exactly one of {q08-critical, q08-batch} has globalDefault=true".

### 5. troubleshooting/04-debug-node
**Problem:** Grader at `grade.sh:35-42` looks for any Pod labeled `kubectl.kubernetes.io/debug-source=<worker>` as proof of `kubectl debug node`. The label is candidate-forgeable. `ref-solution.sh:11-13` openly admits `kubectl debug node` auto-deletes pods on session close in K8s 1.30+, then `ref-solution.sh:14-39` hand-rolls a privileged Pod with the forged label. A candidate aware of the label trick passes without ever exercising the `kubectl debug` skill the question is testing.
**Fix:** Widen evidence set (look for `kubectl.kubernetes.io/debug-container` annotation, debugger image patterns), OR loosen the question to allow any privileged-pod approach, OR remove the evidence gate and grade only on `answer.txt` content.

### 6. troubleshooting/05-static-pod-manifest
**Problem:** Title + body frame as "static pod never becomes Running"; constraints forbid `/etc/kubernetes/manifests/` placement and any restart. `grade.sh:23-69` only checks file existence (weight 0), YAML parseability, `kind==Pod`, and `kubectl apply --dry-run=client`. No mirror-pod check, no actual kubelet pickup, no Running state. Question tests one thing (static-pod debugging), grader scores another (YAML validity).
**Fix:** Either rewrite question.md as a YAML-repair exercise, OR expand grader to verify actual static-pod semantics on a node.

---

## Patterns observed

1. **Trap inventory drift (metadata vs grader).** Pattern repeats across packs: `metadata.yaml` declares traps that have no setup seed and no `grade.sh` detector. Suggests authors copy-pasted from a shared trap taxonomy without auditing detector coverage. Affected: storage/02, /03, /04, /06; workloads/01, /02, /03. Each is MEDIUM individually but the pattern is systemic.

2. **Grader weaker than question demands.** Multiple cases where question.md specifies precise values (averageUtilization=50, per-resource audit levels) but grader checks only structural shape. Affected: workloads/04, cluster-arch/05. Indicates grader-write happened before question-author-final-edit.

3. **Forgeable evidence labels.** troubleshooting/04 uses `kubectl.kubernetes.io/debug-source` as proof — but it's a string label the candidate can write directly. Same pattern would risk other "kubectl injected" evidence checks if any.

4. **Setup mental-model bugs.** Q1-storage and Q5-kube-proxy-mode both demonstrate authors holding incorrect K8s semantics models, baked into setup. Q1 thought nodeAffinity gated PVC binding; Q5 assumed live cluster never runs ipvs. These are the most subtle to catch because tests "pass" on the author's particular cluster.

---

## Recommended actions

### Immediate (HIGH-severity fix queue)
1. **storage/01-pvc-binding** — rewrite question.md to "Pod won't schedule onto worker" + add consumer Pod to setup; OR change setup so PVC genuinely stays Pending (accessMode mismatch).
2. **services-networking/05-kube-proxy-mode** — change `SEED_MODE` to a non-enum placeholder.
3. **cluster-architecture/04-pss-enforce** — add `kubectl apply` step to question OR switch grader to file-content scoring.
4. **cluster-architecture/08-priorityclass** — relax grader to "exactly one of the named pair" OR pin q08-critical in question text.
5. **troubleshooting/04-debug-node** — strengthen evidence check OR loosen question constraint.
6. **troubleshooting/05-static-pod-manifest** — rewrite question framing to match what grader scores OR expand grader to actually verify static-pod behavior.

### Systemic
7. **Add a lint pass** that asserts every trap in `metadata.yaml` has a matching `cka_sim::grade::record_trap` call site in `grade.sh`. Existing `scripts/lint-traps.sh` is the natural home.
8. **Add a "claimed-symptom verification" CI step** (Phase 07.2 candidate) that on a real cluster runs `setup.sh && kubectl get pvc,pv,pod,...` and diff's actual state against a per-question expected-symptom YAML. Would have caught Q1-storage and Q3-troubleshooting at ship time.

### Project state
- Milestone v1.0 marked complete; this audit reveals 7 HIGH-severity bugs blocking confident production use.
- Recommend either re-opening v1.0 with a "v1.0.1 hotfix" phase, OR opening Phase 07.2 explicitly scoped to bug fixes from this audit.

---

## Out of scope for this report
- 4 of the 6 troubleshooting bugs cited above involve subtle ambiguity rather than K8s-impossible symptoms. The Q1-storage class of bug (the original trigger) ranks at most #1, #2, #6 in severity.
- No live-cluster verification performed. Each finding is reproducible from a static read of the listed files.
- Library bug noted in services-networking audit: `lib/setup.sh:218` has a backslash typo in `kubernetes.io\metadata.name` (should be `kubernetes.io/metadata.name`). Affects `seed_netpol_skeleton` only; unclear blast radius. Not counted in the 7 HIGH but worth a follow-up grep across packs.

---

*Report generated by `/gsd-forensics`. Companion to `report-20260517-091057.md` (Q1-only detail).*

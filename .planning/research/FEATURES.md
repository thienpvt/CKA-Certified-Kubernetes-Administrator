# Feature Research: v1.1 Dump Cooloo9871 Pack

**Date:** 2026-05-28
**Source:** https://cooloo9871.github.io/cka/index.html

## Source Topic Inventory

Approved scope is 30 source-derived exercises: 25 main questions, 2 extra questions, and 3 preview questions.

### Main 25 Topics

1. Kubectl contexts and current context output
2. Schedule a pod onto the control-plane node
3. Scale down a StatefulSet
4. Make pod readiness depend on service reachability
5. Write kubectl sorting command for pods
6. Create PV, PVC, and pod volume wiring
7. Record node and pod resource usage commands
8. Inspect control-plane component information
9. Stop scheduler and manually bind a pod
10. Create ServiceAccount, Role, and RoleBinding
11. Create DaemonSet on all nodes
12. Create Deployment across all nodes with topology constraints
13. Create multi-container pod with shared volume
14. Report cluster node and version information
15. Write command for cluster events ordered by time
16. Create namespace and list namespaced API resources
17. Find pod container details and write results
18. Fix broken kubelet on a worker node
19. Create secret and mount it into a pod
20. Upgrade/join an older worker node
21. Create static pod and expose it with a service
22. Check kube-apiserver certificate validity
23. Inspect kubelet client/server certificate issuer and extended key usage
24. Create namespace-scoped NetworkPolicy containment
25. Save and restore etcd snapshot

### Extra 2 Topics

26. Identify pods likely to be terminated first under node pressure
27. Contact Kubernetes API manually from a pod using a ServiceAccount token

### Preview 3 Topics

28. Inspect etcd key/certificate details
29. Confirm kube-proxy functionality through pod/service traffic
30. Expose a pod and record pod/service IP details

## Feature Categories

### Pack Shell

Table stakes:
- `dump-cooloo9871` pack manifest lists all 30 questions in stable order.
- README explains source-derived nature, v1.35 adaptation, and drill usage.
- Coverage map ties each question to at least one existing or new tracker slug.

### Exercise Content

Table stakes:
- Every source topic becomes original `question.md` wording.
- Each question has setup, reset, grader, reference solution, metadata, and expected symptom.
- Questions avoid direct copies of source commands/answers and use repo naming/namespace conventions.

### Runtime Adaptation

Table stakes:
- Multi-cluster source tasks are transformed into single-cluster equivalents or explicitly simulated.
- Host-level tasks reuse existing SSH/node-safe patterns.
- Scheduler, kubelet, static pod, certificate, and etcd tasks use patterns already present in existing packs when possible.

### Grading Honesty

Table stakes:
- Empty submission scores 0 for scored assertions.
- Reference solution reaches max score.
- Setup-state and candidate-authored state are separated via existing baseline/ownership helpers where relevant.
- Named traps are used where existing catalog entries fit; new trap entries are added only when needed.

### Verification

Table stakes:
- Pack lint, coverage lint, trap lint, trap coverage lint, question symptom lint pass.
- Unit fixtures added for new shared helpers or non-trivial graders.
- Milestone close includes batched live drill UAT for representative high-risk questions and reference/empty score checks.

## Differentiators

- Pack gives learners another complete 30-question drill corpus without replacing the curated v1.35 domain packs.
- Source-derived topics cover several command-output and host-inspection tasks that complement existing trap-heavy pack questions.
- Explicit adaptation notes prevent stale v1.24 or multi-cluster assumptions from leaking into v1.35 lab behavior.

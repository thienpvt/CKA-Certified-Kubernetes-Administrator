# Phase 10 Discussion Log

**Discussed:** 2026-05-17
**Mode:** Autonomous --interactive

## Areas Discussed

### BUG-H01 storage/01-pvc-binding fix path
- Options presented:
  1. Add consumer Pod to setup (Recommended) — keep PVC framing, observable trap fires at Pod scheduling
  2. Change setup to accessMode mismatch — different K8s lesson, new trap
  3. Rewrite question to "Pod won't schedule" — reframe to match what nodeAffinity actually controls
- **User selection:** Option 3 — Rewrite question to "Pod won't schedule"
- Notes: cleanest match between K8s semantics and question framing; trap pedagogy stays (`hostpath-pv-without-nodeaffinity`) but symptom matches reality.

### BUG-H02 services-networking/05-kube-proxy-mode fix path
- Options presented:
  1. Seed non-enum placeholder (Recommended) — single-line setup.sh edit, no grader change
  2. Runtime seed differing from live — more logic, survives mode changes
- **User selection:** Option 1 — Seed non-enum placeholder
- Notes: minimal change, robust across iptables/ipvs/nftables clusters.

### BUG-H03 cluster-architecture/04-pss-enforce fix path
- Options presented:
  1. Rewrite grader to score file directly (Recommended) — keeps question framing, file-edit pedagogy
  2. Update question to mandate kubectl apply — changes pedagogy to admission-test
- **User selection:** Option 1 — Rewrite grader to score file directly
- Notes: preserves question.md "no kubectl apply needed" design intent; grader reads candidate-violator.yaml.

### BUG-H04 cluster-architecture/08-priorityclass fix path
- Options presented:
  1. Relax grader to accept either PC (Recommended) — preserves candidate choice
  2. Pin q08-critical in question text — loses flexibility
- **User selection:** Option 1 — Relax grader to accept either PC
- Notes: matches question.md "exactly one of them" wording; small grader edit.

## Deferred Ideas

None raised — all 4 bug discussions stayed in scope.

## Claude's Discretion

- Implementation details inside each fix (exact jsonpath wording, sentinel naming, commit granularity, ref-solution verb choice) deferred to planner/executor.
- Test strategy (drill replay vs unit fixtures) deferred to planner — phase 10 likely uses live-cluster drill in execute UAT.

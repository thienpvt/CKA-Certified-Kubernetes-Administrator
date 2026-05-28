# Pitfalls Research: v1.1 Dump Cooloo9871 Pack

**Date:** 2026-05-28

## High-Risk Pitfalls

### Copying Source Text

Risk: Source repo has no visible license file. Copying full question prose or answer text creates licensing ambiguity.

Prevention:
- Use source as topic inventory only.
- Author new question wording and reference solutions.
- Cite source page in metadata as `prior-art-topic`.

### Kubernetes Version Drift

Risk: Source content targets older Kubernetes assumptions; repo targets v1.35.

Prevention:
- Verify API versions and command behavior against v1.35 docs/runtime.
- Replace deprecated assumptions with current equivalents.
- Avoid stale image tags where cluster behavior depends on image availability.

### Multi-Cluster Assumptions

Risk: Source references multiple contexts and cluster names; simulator uses one lab cluster.

Prevention:
- Convert context tasks to single-cluster kubeconfig/current-context exercises.
- Simulate cluster distinctions with files, namespaces, or labels only when that preserves skill intent.
- Do not require real extra clusters.

### Host-Level Safety

Risk: Kubelet, scheduler, static pod, cert, upgrade, and etcd questions can damage the learner's lab.

Prevention:
- Reuse existing host-safe patterns.
- Prefer reversible edits and reset coverage.
- Gate live UAT for every host-level question.
- Use unsupported audit flags only when kind/offline lint cannot represent the task.

### Grading Honesty Leaks

Risk: Setup-created state can accidentally score points, especially for object-existence and command-output tasks.

Prevention:
- Use baseline/ownership helpers where candidate modification matters.
- Keep preconditions weight 0.
- Prove empty submission is 0 for scored assertions.
- Prove reference solution is max score.

### Trap Catalog Bloat

Risk: Adding 30 questions can create many one-off traps that are not reusable.

Prevention:
- Reuse existing trap IDs when semantics match.
- Add new traps only for common mistake classes.
- Keep metadata trap lists aligned with actual grader paths.

### Overlarge Phase

Risk: 30 full exercises are too much for one phase and would hide regressions.

Prevention:
- Split by risk and build order: scaffold/low-risk, core objects, host/control-plane, verification.
- Commit per phase and keep UAT close-out separate.

## Watch List For Roadmap

- Q18 kubelet repair
- Q20 node upgrade/join
- Q21 static pod on control-plane
- Q25 etcd snapshot restore
- Q09 scheduler stop/manual binding
- Q27 manual API token/curl

These should land after pack scaffolding and lower-risk questions prove the pack shape.

# Phase 6: Troubleshooting Pack - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-12
**Phase:** 06-troubleshooting-pack
**Areas discussed:** Question set, Cross-pack refs, Cluster impact, Trap catalog

---

## Question Set

### How many questions should the pack hold?

| Option | Description | Selected |
|--------|-------------|----------|
| 6 questions | Covers mandated topics plus service/endpoints mismatch; good 30% domain depth without bloating | ✓ |
| 4 questions | Only mandated topics; fastest but weak for largest-weight domain | |
| 8 questions | Broader symptom coverage; bigger phase and more live verification debt | |

### Which sixth topic joins mandated CoreDNS, debug node, NetworkPolicy, kubelet, static pod?

| Option | Description | Selected |
|--------|-------------|----------|
| Service mismatch | Reuses Phase 3 troubleshooting reference concept; exam-frequent, safe namespace-only setup | ✓ |
| Etcd endpoint | Good control-plane diagnosis, but Phase 5 already has etcd backup/restore and higher host risk | |
| CNI broken | Good networking depth, but destabilizes cluster and overlaps with kube-proxy/CNI prior content | |

### How should difficulty ramp across 6 questions?

| Option | Description | Selected |
|--------|-------------|----------|
| Progressive ramp | App-layer first (service mismatch, netpol, CoreDNS) then node/control-plane (debug node, static pod, kubelet) | ✓ |
| Exam random | Mix easy/hard to mimic real exam; worse for learning path | |
| Domain clusters | Group network questions then node/control-plane; less exam-like | |

### Should troubleshooting prompts describe symptoms only or suspected causes?

| Option | Description | Selected |
|--------|-------------|----------|
| Symptoms only | Observed failure + target behavior only; candidate must diagnose root cause | ✓ |
| Light hints | Name area like DNS/network/kubelet; easier learning, less realistic | |
| Mixed | Early light hints, later symptom-only; good ramp, less uniform | |

---

## Cross-Pack Refs

### How should troubleshooting metadata reference other packs?

| Option | Description | Selected |
|--------|-------------|----------|
| Related prior-art | 1-2 references that teach underlying concept; link-only, not executed or copied | ✓ |
| Prerequisite chain | Refs imply completed drills first; strong learning path, less exam-like | |
| Remediation path | Refs point to drills to revisit after failing; belongs in Phase 7 reporting | |

### How strict should cross-pack references be per question?

| Option | Description | Selected |
|--------|-------------|----------|
| At least one | Meets ROADMAP criterion and allows strong single prior-art drills | ✓ |
| Exactly two | Richer context, may force weak refs on some scenarios | |
| One same-topic plus one adjacent | Best learning graph, heavier authoring | |

### Which reference target format should metadata use?

| Option | Description | Selected |
|--------|-------------|----------|
| Pack question path | e.g. `cka-sim/packs/services-networking/03-coredns-resolution/`; stable and local | ✓ |
| Question id only | Compact, resolver support may not exist yet | |
| Old exercise path | Useful prior art, but Phase 6 specifically cross-references other new packs | |

### Should question.md show cross-pack references to candidate before grading?

| Option | Description | Selected |
|--------|-------------|----------|
| Metadata only | Keeps exam realism; refs help planning/reporting but do not spoil diagnosis during drill | ✓ |
| After prompt | Shows optional study links upfront; hints at root cause | |
| After grading | Better learning flow, requires runner/report behavior not scoped until Phase 7 | |

---

## Cluster Impact

### How should broken kubelet and static-pod scenarios avoid harming live control plane?

| Option | Description | Selected |
|--------|-------------|----------|
| Sandbox files | Seed copies under `/tmp/qNN-*`; candidate fixes files there, grader validates content | ✓ |
| Worker only live | Break kubelet/static-pod on a worker then repair; more realistic, risky | |
| Containerized fake node | Highest isolation, adds tooling complexity outside bash/kubectl scope | |

### For `kubectl debug node`, should setup require real node debug execution?

| Option | Description | Selected |
|--------|-------------|----------|
| Real debug, read-only | Candidate runs `kubectl debug node/...`, inspects host files/logs; setup does not mutate host state | ✓ |
| Sandbox only | Avoids privileged/debug pods, but loses core skill of node debugging | |
| Full repair | Candidate debugs and changes host files; most realistic, highest blast radius | |

### Where should network/CoreDNS troubleshooting breakages live?

| Option | Description | Selected |
|--------|-------------|----------|
| Lab namespace mostly | Per-question namespaces and app-level checks; CoreDNS ConfigMap copy/sandbox when needed | ✓ |
| Real CoreDNS patch | Patch kube-system CoreDNS and restore in reset; very realistic, risky if reset fails | |
| Pure manifests | No live behavior changes beyond namespace objects; weaker troubleshooting signal | |

### Should reset scripts ever restart kubelet or delete node debug pods forcefully?

| Option | Description | Selected |
|--------|-------------|----------|
| No kubelet restart | Reset cleans namespaces, debug pods, and `/tmp/qNN-*`; never restarts system services | ✓ |
| Restart worker only | Allow kubelet restart on non-control-plane workers if needed; environment-dependent | |
| Claude decide per question | Flexible, weak safety contract | |

---

## Trap Catalog

### What should troubleshooting trap IDs emphasize?

| Option | Description | Selected |
|--------|-------------|----------|
| Root cause | Trap names describe actual mistake: `service-selector-label-mismatch`, `coredns-forward-invalid-upstream`, `static-pod-manifest-bad-yaml` | ✓ |
| Symptom | Describes observed failure: `dns-resolution-fails`, `endpoints-empty`; less precise | |
| Command mistake | Describes wrong fix commands; useful for CLI habits, misses conceptual bugs | |

### How many new trap entries should Phase 6 add?

| Option | Description | Selected |
|--------|-------------|----------|
| ~10 traps | 1-2 root-cause traps per question plus prior-trap reuse; enough coverage without catalog bloat | ✓ |
| 6 traps | One per question; lean, misses alternative common mistakes | |
| 15+ traps | Very granular diagnostics; strong feedback, bigger catalog and fixture load | |

### Should troubleshooting traps reuse prior pack traps when same mistake appears?

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse first | Reference existing trap if it matches; add new only for troubleshooting-specific root cause | ✓ |
| New per pack | Every troubleshooting question gets unique trap IDs; duplicates concepts | |
| Alias style | Troubleshooting aliases pointing to prior traps; schema may not support aliases | |

### Severity policy for troubleshooting traps?

| Option | Description | Selected |
|--------|-------------|----------|
| Error for root cause | Root-cause traps `error`; secondary command-hygiene traps `warn` | ✓ |
| All error | Simpler and strict; could overstate learning hints as hard failures | |
| Mixed by question difficulty | Harder questions get more warnings; inconsistent | |

---

## Claude's Discretion

- Exact broken-state YAML per question within each topic and trap-ID constraints.
- Exact prompt wording, trap wording, ref-solution mechanics, and fixture shapes.
- Which prior pack question(s) each troubleshooting question references, as long as each question has at least one strong pack-question-path reference.
- Per-question `estimatedMinutes` within PACK-06 `[4, 12]`, with harder node/control-plane scenarios near the upper end.
- Whether to source existing `lib/setup.sh` helpers or extend with small additions if new shared idioms emerge.

## Deferred Ideas

- Showing remediation links after grading belongs in Phase 7 reporting / score UX.
- Real live kubelet/static-pod break/fix drills deferred to v1.x only with explicit destructive-lab confirmation and rollback.
- Hint reveal (DF-08) stays deferred; no `hint.md` files.

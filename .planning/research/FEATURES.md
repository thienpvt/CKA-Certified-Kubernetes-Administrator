# Feature Research — CKA Exam Simulator

**Domain:** Self-hosted, Bash-only, kubectl-driven CKA exam practice runner
**Researched:** 2026-05-07
**Verified against v1.0 milestone scope on 2026-05-07** — Ubuntu 22.04, 5 domain packs + 2 mock-exam packs, reference-only use of existing exercises. P1 set is unchanged.
**Confidence:** MEDIUM-HIGH — grounded in `.planning/PROJECT.md`, `.planning/codebase/CONCERNS.md`, the README's Study Progress Tracker, the published v1.35 CKA blueprint, and well-known behaviour of the public landscape (killer.sh / KodeKloud / mumshad's CKA-Exercises). Web search was unavailable for this run; competitor claims about *current* killer.sh / KodeKloud features carry MEDIUM confidence and are flagged inline.

---

## Scope Discipline (from PROJECT.md)

Out of scope per PROJECT.md, and therefore *not* candidate features at any priority:

- VM provisioning (Terraform / `gcloud compute instances create`).
- `kubeadm init`/`join` (cluster bootstrap from zero).
- Browser / PSI-Bridge web-terminal emulation.
- CKAD / CKS content. KCNA. v1.34-and-earlier syllabus.
- Multi-tenant / shared-cluster mode. Auth. Leaderboards.
- Cloud-vendor-specific labs (GKE/EKS/AKS-only features).
- Real CKA exam content (CNCF NDA — automatic decert).

Every feature below is checked against this list. Anything that contradicts it is in *Anti-Features*.

---

## Feature Landscape

### Table Stakes (Users Expect These)

A CKA exam simulator that lacks any of these does not feel like a CKA simulator. Confidence: HIGH — these are derivable from the published CKA exam format and from PROJECT.md's Active requirements.

| # | Feature | Why Expected | Complexity | Notes |
|---|---------|--------------|------------|-------|
| TS-01 | **2-hour countdown timer** for exam mode, visible at all times | Real CKA is 2 hours; without a timer it isn't a simulator | LOW | `date +%s` arithmetic in a bash subshell; redraw HH:MM:SS on a status line. Must survive terminal resize. |
| TS-02 | **~17 questions per mock**, weighted to v1.35 blueprint (Storage 10 / Trbl 30 / Workloads 15 / Cluster 25 / Net 20) | Real CKA structure (PROJECT.md Active item, README Tracker references) | MEDIUM | A pack manifest declares the question IDs and the weighting check happens at pack-build time. |
| TS-03 | **Per-question `setup.sh`** — idempotent, creates lab namespace + broken state + required SSH context | PROJECT.md Active item; without setup, no question runs | MEDIUM | Idempotency is non-negotiable per Constraints; `kubectl apply` is mostly idempotent already; namespace `exercise-NN` per repo convention. |
| TS-04 | **Per-question `grade.sh`** — kubectl-driven binary pass/fail | PROJECT.md Active item; grading is the whole point | MEDIUM | Pass/fail by exit code; assertion library = a few bash helpers (`assert_exists`, `assert_field`, `assert_in_namespace`). |
| TS-05 | **Per-question `reset.sh`** — returns cluster to clean baseline | PROJECT.md Active item; without it, practice loops poison the cluster | MEDIUM | `kubectl delete ns exercise-NN --wait` covers ~80% of cases; node-level state (e.g. cordoned, taints, static pods) needs explicit teardown. |
| TS-06 | **Point value per question** + **end-of-exam grading** with total score | Real CKA reports a percentage; pass/fail is meaningless without a number | LOW | Sum points, divide, compare to 66% pass mark per PROJECT.md context. |
| TS-07 | **Per-domain score breakdown** in the report | Without it, "you scored 60%" doesn't tell the candidate where to drill | LOW | Each question carries a `domain` tag; aggregate at report time. |
| TS-08 | **Flag / skip / return** to a question during exam | Real CKA UX; candidates routinely defer hard questions | LOW | A `flagged.txt` per session; runner shows "[F]" next to flagged Q in the navigator. |
| TS-09 | **`ssh node-NN` UX** from the control plane | Real exam topology — questions say "ssh into node01" | MEDIUM | One-time keygen + `ssh-copy-id`; `~/.ssh/config` aliases `node-01`/`node-02` to internal IPs. |
| TS-10 | **Exam aliases preset** (`k`, `kn`, `kgp`, `$do`, `$now`) | Already in `scripts/exam-setup.sh`; candidates expect them | LOW | Already exists; needs idempotency fix (CONCERNS.md flagged duplicate vimrc appends). |
| TS-11 | **Preset vimrc** (2-space indent, expandtab, autoindent) | Editing YAML in vim under timer is the dominant exam motion | LOW | Already in `scripts/exam-setup.sh`; needs sentinel guard per CONCERNS.md. |
| TS-12 | **`ETCDCTL_API=3` exported** + etcdctl pre-installed | etcd backup/restore is a recurring CKA topic; v2 vs v3 is a classic trap | LOW | Already in setup; verify `etcdctl version` at runner start. |
| TS-13 | **kubeconfig context preset** for the right cluster | Real exam pre-sets the context per question; switching is a known gotcha | LOW | `kubectl config use-context kubernetes-admin@kubernetes` (or pack-defined) at session start. |
| TS-14 | **kubernetes.io / kubectl.io / helm.sh docs are reachable** during practice | Real exam permits exactly these three — practice should match | LOW | Out-of-the-box on a GCP VM with internet egress; documented prerequisite, not built. |
| TS-15 | **Mid-exam pause** (Ctrl-Z / runner command) | Real life intrudes; learners need to pause without losing session state | MEDIUM | Persist timer-remaining + flagged set + answered set to a session JSON; resume reads it back. |
| TS-16 | **End-of-exam grading runs all `grade.sh` scripts in order**, captures pass/fail per Q | Without batched grading, the candidate has to grade by hand | LOW | Drives the score report. |
| TS-17 | **Markdown score report** to `~/cka-sim/sessions/NNN/report.md` | Industry-standard durable artifact; reviewable later | LOW | Templated; readable in `less` or any editor on the CP node. |
| TS-18 | **Independent disclaimer** in every pack: "Not real CKA exam content" | CNCF NDA + PROJECT.md Out of Scope; CONCERNS.md notes existing mocks omit it | LOW | One header line per pack manifest. |
| TS-19 | **Pack-level domain organisation** — domain-pack per CKA domain (5 packs) | Differentiated drilling by weak domain is the canonical study loop | LOW | Five YAML/JSON pack manifests; reuses question IDs from a flat `questions/` dir. |
| TS-20 | **Single-question drill mode** (`cka-sim drill <pack> [<n>]`) | Daily practice surface; nobody runs a full 2h mock every day | LOW | Same runner machinery as exam mode without timer / grading aggregation. |

### Differentiators (Why This Beats killer.sh / KodeKloud / mumshad For This User)

These are *only* worth building if they ship. Each is justified by either PROJECT.md's Core Value, a CONCERNS.md gap, or a known weakness of the public landscape. Confidence on competitor weaknesses: MEDIUM (training-data based; web search unavailable this run).

| # | Feature | Value Proposition | Complexity | Notes |
|---|---------|-------------------|------------|-------|
| DF-01 | **Trap-aware grader** — `grade.sh` emits `Trap N: <named class of mistake>` for every detected wrong-but-plausible solution, not just pass/fail | The Core Value of the project. killer.sh tells you the right answer; this tells you the *class of mistake you keep making* across questions | HIGH | Each grader has a `traps[]` registry: name, detector function, descriptive diagnostic. Detectors are kubectl + jsonpath / `jq`. Examples: wrong namespace, default SA used, hostPath without nodeAffinity, `--as=` form wrong, RBAC scoped at wrong level, missing DNS egress, kubelet flag in wrong file, PSS error string mismatch. Hard part is *catalog discipline*: traps must be reusable across questions and frequency-tracked. |
| DF-02 | **Trap frequency aggregation across sessions** — "you've hit `wrong-namespace` in 6 of your last 10 sessions" | Turns one-off feedback into a *learning trajectory*. No public competitor does this at the level of named mistake-classes | MEDIUM | A trap-events log appended per session; aggregator script with `sort | uniq -c`. Storage = `~/cka-sim/state/trap-history.jsonl`. |
| DF-03 | **Suggested-next-drills routing** in the report — failed `Trbl-04` → "drill `troubleshooting` pack q3, q7, q11" | Closes the loop from "you got 60%" to "do these three labs tonight" | MEDIUM | Each question declares `prerequisites: [q-ids]` + `related: [q-ids]`. Failed Q → emit related Q list. |
| DF-04 | **Idempotent everything** — every `setup.sh` and `reset.sh` safe to re-run | Flagged as a Constraint in PROJECT.md; killer.sh portal handles this server-side, but *local* simulators (homegrown lab repos on GitHub) routinely fail this. Direct anti-pattern fix from CONCERNS.md ("vimrc append script ran N times"). | MEDIUM | Sentinel files (`.cka-sim/setup-applied`); `kubectl apply` (not `create`); `delete --wait`; explicit cleanup of node-state (cordon, taints). |
| DF-05 | **Real-cluster fidelity** — runs on the candidate's *own* 1 CP + 2 worker GCP cluster, not a sandboxed VM image | killer.sh gives you a disposable lab on their infra; KodeKloud uses a single-VM minikube/kind. Practising on the real multi-node topology you'll fail on (CRI, kubelet flags, PV nodeAffinity) is the single biggest fidelity win. CONCERNS.md flags hostPath without nodeAffinity as a real-cluster footgun. | LOW (already a constraint, not a feature) | Documented prerequisite. |
| DF-06 | **Trap catalog includes content-bug traps** — graders teach the *correct* PSS error string, the *correct* kubelet flags file, the *correct* dockershim removal version | PROJECT.md Context: "the trap catalog should call out the real-world content bugs already documented in CONCERNS.md". Ships fixes to learning material as detection rules. | MEDIUM | Each trap entry can carry a `correct_mental_model:` block printed on hit. |
| DF-07 | **Open source, self-hosted, free** — bash + kubectl, install in 5 min on the CP node | killer.sh is paid (bundled with Linux Foundation exam voucher). KodeKloud subscription. Differentiator for the maintainer's use case (PROJECT.md user is a single CKA candidate who already pays for GCP). | LOW | Outcome of stack choice, not a feature to build. |
| DF-08 | **Hint reveal on demand** (drill mode only, disabled in exam mode) | Drill mode is for learning; hints accelerate it. Exam mode must not allow them — the simulator would lie about readiness | LOW | `cka-sim drill --hint <pack>/<q>`; questions ship with `hints.md` (was `<details>` block in old exercises). |
| DF-09 | **Retake** with re-randomised question selection from a domain pack | Cheap to build, valuable for spaced repetition | LOW | Exam packs declare a *pool* + a *sampling rule* ("17 questions: 2 storage, 5 trbl, 2 workloads, 4 cluster, 4 net"). Same pack ID → different draw. |
| DF-10 | **Per-trap heatmap in report** (Markdown table: trap × domain × frequency) | Visual at-a-glance of weak mental models — does the candidate keep messing up RBAC scope, or always default-SA, or always wrong-namespace? | LOW | Pure post-processing of the trap log. |
| DF-11 | **Authoring template + lint** (`cka-sim author lint <q-dir>`) | Keeps the question corpus from drifting into the same content-accuracy mess CONCERNS.md documents (PSS error string, removed flags, broken cross-links) | MEDIUM | Lints: setup.sh shellcheck-clean; grade.sh has at least 1 trap registered; reset.sh leaves zero residual `exercise-NN` namespaces; question.yaml has `domain` ∈ {1..5}, `points`, `tags`, `disclaimer: "independent"`. |
| DF-12 | **Fixture validation** — dry-run setup against a clean cluster in CI / pre-commit | CONCERNS.md item: "CI doesn't validate exercise-embedded YAML." Catches bit-rot like the cri-dockerd flag bug | MEDIUM | A `cka-sim ci` mode runs every `setup.sh` then `reset.sh` against a `kind` ephemeral cluster, just to prove the scripts execute. Doesn't grade — proves shape. |
| DF-13 | **Crictl alias preset** instead of docker | CONCERNS.md flags `alias d='docker'` in current `exam-setup.sh` as misleading — Docker isn't on CKA. Replace with `crictl ps`, `crictl logs` aliases | LOW | One-line replacement in setup. |
| DF-14 | **kubeadm-flags.env reference card** | CONCERNS.md: candidates and the existing material confuse `/etc/kubernetes/kubelet.conf` (kubeconfig) with `/var/lib/kubelet/kubeadm-flags.env` (runtime flags). Ship a 1-page reference + a trap that detects the wrong-file edit. | LOW | Cheatsheet addition + a trap detector that diffs `kubeadm-flags.env` after each kubelet question. |
| DF-15 | **Existing-content banner / superseded pointer** in `exercises/`, `mock-exams/`, README | PROJECT.md Active item; preserves the "What tripped me up" prose without leaving learners on stale labs | LOW | Header markdown injection. |

### Anti-Features (Explicitly NOT Building)

Each row maps to a PROJECT.md Out-of-Scope item or to a known footgun the user has already chosen against. Confidence: HIGH (these are derived from PROJECT.md, not assumed).

| # | Anti-Feature | Why It Sounds Good | Why It's Out | Alternative |
|---|--------------|--------------------|----|-------------|
| AF-01 | **GUI / web portal** for running questions | Pretty UX; "modern feel" | PROJECT.md: terminal-only. Real CKA is shell anyway — UI moves you away from exam fidelity. Adds Node/React/whatever stack to a bash project. | Bash TUI: `tput`-based status bar, plain text question files in `$PAGER`. |
| AF-02 | **Multi-tenant / shared cluster** mode with auth, sessions per user | "Could share with a study group" | PROJECT.md Out of Scope. Single learner, own cluster. Auth + tenancy = order-of-magnitude complexity for zero core-value gain | Each user runs their own `cka-sim` on their own cluster. |
| AF-03 | **Cloud-vendor-specific labs** (GKE Autopilot, EKS Fargate, AKS Application Gateway) | "Realistic for a working DevOps engineer" | PROJECT.md Out of Scope. Real CKA is vendor-neutral kubeadm; vendor specifics drift fast and aren't tested. | Stay vendor-neutral kubeadm + containerd. GCP is just where the VMs live. |
| AF-04 | **Real CKA exam content** (verbatim or paraphrased) | "Most realistic possible practice" | PROJECT.md Out of Scope + CNCF NDA: certificate revocation. CONCERNS.md notes existing mocks already lack the disclaimer | Independently designed scenarios that target the same competencies. Ship a disclaimer in every pack. |
| AF-05 | **Browser / PSI-Bridge web terminal emulation** | "Pixel-perfect exam day rehearsal" | PROJECT.md Out of Scope. Functional fidelity (timer + ssh-node + kubectl + 3 doc sites) covers the actual skills tested; visual fidelity costs a Chromium embedding for ~zero learning value | Document the docs whitelist + 2h timer + ssh-node UX as the rehearsal target. |
| AF-06 | **killer.sh-style remote portal / VPN / leaderboard** | "Proven model" | PROJECT.md Out of Scope. Different product. The user already has a cluster they pay for. Building a portal is a startup, not a study tool | Local runner against local cluster. |
| AF-07 | **VM provisioning** (Terraform / `gcloud` automation) | "One-command setup" | PROJECT.md Out of Scope. The user provisions VMs once, manually. Automating it is friction, not value, for a single learner. | One-time manual `gcloud compute instances create` documented in prerequisites. |
| AF-08 | **kubeadm init / join automation** | "Fully reproducible cluster" | PROJECT.md Out of Scope. Cluster exists. Building bootstrap = a different project (`kubernetes-the-hard-way` already does it for free) | Document the kubeadm one-liners as prerequisite. |
| AF-09 | **CKAD / CKS / KCNA content** | "Cover all CNCF certs" | PROJECT.md Out of Scope. Scope creep ruins focus. CKA blueprint is its own job | Separate repos if ever wanted. |
| AF-10 | **Backporting to v1.34 or earlier** | "Helps people on older clusters" | PROJECT.md Out of Scope. v1.35 is the syllabus today (2026-05-07). Maintaining a matrix doubles work | Pin v1.35; bump in lockstep with CNCF blueprint. |
| AF-11 | **Anti-cheat / video proctoring** | "Real exam has it" | Out of scope by inference (no auth, no portal, no users). Self-practice — there's no one to cheat against | Trust the candidate; the score only matters to them. |
| AF-12 | **Question randomisation that breaks reproducibility** | "Each session is unique" | Reproducibility matters: candidate must be able to re-run the same draw to compare scores | Seeded sampling: `cka-sim exam <pack> --seed 42` → same draw. Default = random. |
| AF-13 | **Auto-fix / hint-on-fail / "show solution" in exam mode** | "Don't let the candidate get stuck" | Defeats the purpose; turns the exam into a tutorial. The score must be honest | Hints + solutions only in drill mode. Exam mode shows nothing until end. |
| AF-14 | **Time extensions / mid-question kubectl-undo** | "Real exam doesn't, but...nice" | Honest score requires honest constraints | None. Pause is fine; rewind is not. |
| AF-15 | **Multi-language support** (Spanish, Mandarin, ...) | "Wider reach" | Single user; English-only matches the exam's working language for this candidate | None. |
| AF-16 | **Auto-clusters via kind / minikube on the runner** | "Lower barrier to entry" | Drops fidelity. Multi-node behaviours (PV nodeAffinity, kube-proxy, NetworkPolicy across nodes) don't reproduce. CONCERNS.md flags hostPath as a real-cluster footgun specifically because single-node hides it | Require the documented 1+2 GCP cluster. |
| AF-17 | **Telemetry / phone-home** | "Improve the product" | Single-user, no service to improve, privacy debt. Trap history is local-only | All state under `~/cka-sim/state/`. Never leaves the box. |

### Coverage-Gap Features (Net-New Questions Required by the Tracker)

Cross-referencing the README Study Progress Tracker (lines 3201–3275) against the existing 31 exercises and against `CONCERNS.md` § Coverage Gaps. Each row below is a Tracker checkbox that is *not* well-served today and therefore needs a net-new exam-sim question. Confidence: HIGH (direct file evidence).

| # | Tracker Checkbox | Domain (weight) | Existing Coverage | Gap Verdict | Suggested New Question(s) |
|---|------------------|-----------------|-------------------|-------------|---------------------------|
| CG-01 | "CSI driver basics and troubleshooting" | Storage (10%) | None — ex-12 covers static PV/PVC only; no CSI | NET NEW | `storage-csi-snapshot`: take a `VolumeSnapshot`, restore PVC from it. Trap: missing `VolumeSnapshotClass`. |
| CG-02 | (Tracker silent) "VolumeSnapshot" — implied by "CSI driver basics" | Storage (10%) | None; `skeletons/` has no `volumesnapshot.yaml` (CONCERNS.md) | NET NEW | Same as CG-01. |
| CG-03 | "Troubleshoot CoreDNS" | Trbl (30%) | Indirect via ex-11; no dedicated CoreDNS lab | NET NEW | `trbl-coredns-corefile`: candidate must edit ConfigMap `coredns` to add a `forward . 8.8.8.8` stub zone. Trap: editing wrong ConfigMap (kube-dns vs coredns), forgetting to bounce pods. |
| CG-04 | "Use kubectl debug (ephemeral containers + node debug)" | Trbl (30%) | ex-17 covers ephemeral; node-debug variant absent | PARTIAL → ENHANCE | `trbl-node-debug`: `kubectl debug node/...` to inspect a node-level FS issue. Trap: forgetting `--image=busybox`, looking in wrong chroot path. |
| CG-05 | "Troubleshoot NetworkPolicy" | Trbl (30%) and Net (20%) | ex-05 creates NetPol; no explicit *trouble* lab | PARTIAL → ENHANCE | `trbl-netpol-deny-egress-dns`: an existing NetPol blocks DNS; pod can't resolve. Trap: forgetting UDP/53, forgetting `to: []` egress. |
| CG-06 | "HPA (autoscaling/v2)" | Workloads (15%) | ex-16 covers HPA but assumes metrics-server exists | NET NEW (prerequisite lab) | `cluster-metrics-server-bootstrap`: install metrics-server, fix the `--kubelet-insecure-tls` flag, verify `kubectl top nodes`. CONCERNS.md flags this gap. |
| CG-07 | "Static pods" | Workloads (15%) | ex-10 covers it | OK | (none needed) |
| CG-08 | (Implied 1.33 GA) "Native sidecar containers (`restartPolicy: Always` on initContainer)" | Workloads (15%) | Skeleton exists, no exercise (CONCERNS.md) | NET NEW | `workloads-native-sidecar`: convert a regular sidecar to a native sidecar, verify ordering. Trap: putting `restartPolicy: Always` on the *main* container. |
| CG-09 | "kube-scheduler customisation (KubeSchedulerConfiguration)" | Workloads (15%) | None | NET NEW (BORDERLINE) | `workloads-scheduler-profile`: write a `KubeSchedulerConfiguration` with a custom profile name; verify pods land on it via `schedulerName`. *Borderline because exam emphasis is unclear; keep as a stretch question, not in every mock.* |
| CG-10 | "Pod Security Standards (PSS) enforcement" | Cluster (25%) | ex-20 exists but contains content bugs (PSS error string, fictional pod-level exemption — CONCERNS.md) | REPLACE | `cluster-pss-restricted-namespace`: label a namespace `restricted` and observe correct rejection wording. Traps: relying on the fictional pod-level label, expecting a "Pending" pod (PSS rejects at admission, no pod is created). |
| CG-11 | (Tracker doesn't list) "Audit policy / `kubectl auth whoami`" | Cluster (25%) | None | NET NEW | `cluster-audit-policy`: add `--audit-policy-file` to kube-apiserver static manifest; verify entries appear. Trap: kube-apiserver fails to restart because of a YAML syntax error in the static pod. |
| CG-12 | (Tracker doesn't list) "CRDs basics" | Cluster (25%) | None standalone (CONCERNS.md); only via Argo CD ex-31 | NET NEW | `cluster-crd-basics`: apply a CRD, create a custom resource, list it via `kubectl get <kind>`. Trap: forgetting `--api-versions` printer column. |
| CG-13 | "Container runtime configuration (CRI-dockerd, containerd)" | Cluster (25%) | ex-18 + duplicate ex-26 — both contain the removed `--container-runtime=remote` flag bug (CONCERNS.md) | REPLACE | `cluster-cri-dockerd-setup`: write `--container-runtime-endpoint=unix:///run/cri-dockerd.sock` into `/var/lib/kubelet/kubeadm-flags.env`. Trap: editing `/etc/kubernetes/kubelet.conf` (which is a kubeconfig, not a flags file). |
| CG-14 | "kubeadm cluster upgrade" | Cluster (25%) | ex-09 exists | OK | (none needed) |
| CG-15 | "CNI plugin awareness" → kube-proxy modes | Net (20%) | ex-27 covers Calico install; no kube-proxy iptables vs ipvs vs nftables (CONCERNS.md) | NET NEW | `net-kube-proxy-mode`: read current mode from kube-proxy ConfigMap; switch from iptables to ipvs; verify with `iptables-save | grep KUBE-` vs `ipvsadm -L`. |
| CG-16 | "NetworkPolicy ingress + egress" → endPort + ipBlock.except | Net (20%) | ex-05 covers basics; no `endPort` / `ipBlock.except` (CONCERNS.md) | NET NEW | `net-netpol-endport`: write a NetPol with `endPort: 8090` for a port range. Trap: forgetting that `endPort` requires `port` and a `protocol`. |
| CG-17 | "Gateway API (Gateway + HTTPRoute)" | Net (20%) | ex-15 exists | OK | (none needed) |
| CG-18 | "Ingress TLS termination and IngressClass" | Net (20%) | ex-19 exists but cross-link 404s (CONCERNS.md) | OK + LINK FIX | (links fixed in pack manifest) |
| CG-19 | "Mock exam completed (>66%)" — Exam Readiness | (meta) | Two static mocks exist; both heavy on Trbl/Scheduling, light on Storage/Net (CONCERNS.md) | REBALANCE | Mock packs use weighted sampling per TS-02 to enforce the blueprint distribution. |
| CG-20 | "killer.sh session 1 / 2 completed" — Exam Readiness | (meta) | Out of project scope | DOCUMENT, DON'T BUILD | Tracker prerequisite, not a feature; still recommended in `README.md` since killer.sh ships with the LF voucher. |
| CG-21 | "ID verified and CNCF account name matches" — Exam Readiness | (meta) | Out of scope | DOCUMENT | Pre-flight checklist in README. |

**Summary count:** 13 net-new questions, 3 replacements/enhancements of existing exercises, 1 rebalance of mock packs. Existing 31 exercises cover ~22 of the ~35 Tracker checkboxes meaningfully; the gap is concentrated in Storage (CSI), Trbl (CoreDNS, NetPol-trbl, node-debug), Cluster (PSS, CRDs, audit, metrics-server), and Net (kube-proxy modes, NetPol endPort).

---

## Feature Dependencies

```
TS-03 setup.sh ──required by──> TS-04 grade.sh ──required by──> TS-05 reset.sh
                                       │
                                       ├──drives──> TS-16 batched grading ──drives──> TS-06 score, TS-07 domain breakdown, TS-17 report
                                       │
                                       └──extended by──> DF-01 trap-aware grader
                                                              │
                                                              ├──aggregated by──> DF-02 trap frequency
                                                              │                       │
                                                              │                       └──visualised by──> DF-10 trap heatmap
                                                              │
                                                              └──routes back to──> DF-03 suggested-next-drills

TS-19 domain packs ──reused by──> TS-02 weighted mock packs ──drawn by──> TS-08 flag/skip + TS-15 pause
                                                                                │
                                                                                └──persisted as──> session JSON

TS-09 ssh-node ──prerequisite for──> any question that touches kubelet / static pods / etcd
TS-10 aliases + TS-11 vimrc + TS-12 ETCDCTL_API + TS-13 kubeconfig
   └──all bundled in──> bootstrap-cluster-config script (PROJECT.md Active item)

DF-11 author lint ──gates──> DF-12 fixture CI ──gates──> question merging
                                  │
                                  └──prevents──> the exact content drift CONCERNS.md catalogs

DF-08 hint reveal ──conflicts with──> exam mode (allowed in drill only)
TS-14 docs whitelist ──documents──> prerequisites; not a build target
```

### Dependency Notes

- **TS-04 grade.sh requires TS-03 setup.sh:** grading checks state created by setup; without setup, grade.sh's first assertion fails on a missing namespace.
- **DF-01 traps require TS-04 grading harness:** the trap registry hangs off the same exit-code/assertion engine. Build the basic grader first, layer traps on.
- **DF-02 trap-frequency requires DF-01 traps + persistent session log:** can't aggregate what isn't recorded. Storage = `~/cka-sim/state/trap-history.jsonl`.
- **DF-03 next-drills requires DF-01 traps + TS-19 domain pack tagging:** routing logic is "for each failed-q's tags, list other unanswered q's with the same tag from the matching domain pack."
- **TS-02 weighted mocks require TS-19 domain packs:** mocks sample *from* domain packs. Build domain packs first.
- **DF-12 fixture CI requires DF-11 author lint:** lint defines the contract that CI verifies.
- **DF-08 hint reveal conflicts with exam mode:** the runner must refuse `--hint` when invoked via `cka-sim exam`. Single conditional, but a real conflict in UX.
- **TS-09 ssh-node is a prerequisite for any kubelet / static-pod / etcd question:** if the bootstrap script isn't run, those questions print a helpful preflight error rather than failing opaquely.

---

## MVP Definition

The Core Value (PROJECT.md §Core Value) is *"a 2-hour timed mock exam against your own cluster with trap-aware feedback."* Anything not on the path to that one experience is post-MVP.

### Launch With (v1) — must ship to honour Core Value

- [ ] **TS-03 / TS-04 / TS-05 runtime triplet** — without setup/grade/reset, no question runs.
- [ ] **TS-09 / TS-10 / TS-11 / TS-12 / TS-13 cluster bootstrap** — the runner can't simulate the exam without ssh-node and the aliases.
- [ ] **TS-19 five domain packs** — the simulator has nothing to drill without questions, organised by domain.
- [ ] **TS-02 weighted mock pack** (one mock to start) — the Core Value experience.
- [ ] **TS-01 / TS-08 / TS-15 / TS-16 exam mechanics** — timer, flag/skip, pause, end-of-exam grading. Without these, "exam" is a misnomer.
- [ ] **TS-06 / TS-07 / TS-17 score report** — the candidate must walk away knowing where they stand.
- [ ] **TS-20 drill mode** — a daily-practice on-ramp; needed to *get to* exam-readiness.
- [ ] **DF-01 trap-aware grader** — this is the Core Value differentiator. Skip this and you've built another mock-exam.md.
- [ ] **DF-04 idempotent setup/reset** — Constraint, not optional.
- [ ] **TS-18 disclaimer** — CNCF NDA + repo policy.
- [ ] **CG-01, CG-06, CG-08, CG-10 (replace), CG-11, CG-13 (replace), CG-15, CG-16** — the highest-impact coverage gaps. Without these, the Tracker checklist is wrong.
- [ ] **DF-15 superseded banner on existing content** — PROJECT.md Active item; cheap; unblocks confused future-self.

### Add After Validation (v1.x) — once the v1 loop is being used weekly

- [ ] **DF-02 trap-frequency aggregation** — needs ≥3 sessions of data to be useful; build only after sessions are happening.
- [ ] **DF-03 suggested-next-drills routing** — depends on DF-02.
- [ ] **DF-09 retake with re-randomised draw** — only matters once one mock has been done twice.
- [ ] **DF-11 / DF-12 author lint + fixture CI** — pays off when contributing a 2nd or 3rd pack; overhead at v1 of 1 author.
- [ ] **CG-03, CG-04, CG-05, CG-12 (CRDs), CG-21 second mock pack** — fill the rest of the Tracker.
- [ ] **DF-08 hint reveal in drill mode** — quality-of-life, not core.

### Future Consideration (v2+) — only if the user is still using this and external contributors arrive

- [ ] **DF-10 trap heatmap visualisation** — needs many sessions; ASCII-art table is fine, full visualisation is over-engineering for v1.
- [ ] **CG-09 kube-scheduler profile question** — borderline syllabus; defer until CKA blueprint clarifies.
- [ ] **A second mock pack with a different question pool** — only valuable when the candidate has memorised the first.
- [ ] **DF-14 kubeadm-flags reference card** — low priority polish; the trap message itself can carry the info inline.
- [ ] **External-contributor onboarding doc** — premature for a single-learner project.

### Explicitly NOT in MVP (anti-MVP guard)

Each of these is tempting because it sounds "v1" — they aren't.

- ~~Two mock packs at launch~~ — One mock + one re-randomised retake covers the launch use-case. Second pack is v1.x.
- ~~Trap heatmap visualisation~~ — A flat trap-frequency list is sufficient at v1; the heatmap is gratification, not data.
- ~~CI integration with GitHub Actions~~ — `validate-local.sh` works; CI is v1.x.
- ~~Auto-grader for fenced YAML inside README.md~~ — CONCERNS.md flags it, but it's about the *old* exercises. New exam-sim questions ship YAML in `setup.sh`/manifests, not fenced in markdown. Don't fix the old surface.
- ~~Per-question time budget displayed during exam~~ — real CKA doesn't show a per-Q budget. The candidate manages it. Showing one trains the wrong reflex.

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| TS-03/04/05 setup/grade/reset triplet | HIGH | MEDIUM | **P1** |
| TS-09 ssh-node UX | HIGH | MEDIUM | **P1** |
| TS-10/11/12/13 aliases / vim / etcdctl / context | HIGH | LOW | **P1** |
| TS-01 2-hour timer | HIGH | LOW | **P1** |
| TS-02 weighted mock pack (one) | HIGH | MEDIUM | **P1** |
| TS-08 flag/skip/return | HIGH | LOW | **P1** |
| TS-15 mid-exam pause | MEDIUM | MEDIUM | **P1** |
| TS-16 end-of-exam grading | HIGH | LOW | **P1** |
| TS-06/07/17 score + domain breakdown + report | HIGH | LOW | **P1** |
| TS-19 five domain packs | HIGH | MEDIUM | **P1** |
| TS-20 drill mode | HIGH | LOW | **P1** |
| TS-18 disclaimer | HIGH (legal) | LOW | **P1** |
| DF-01 trap-aware grader | HIGH | HIGH | **P1** |
| DF-04 idempotent setup/reset | HIGH | MEDIUM | **P1** |
| DF-15 superseded banner | MEDIUM | LOW | **P1** |
| CG-01 CSI VolumeSnapshot question | MEDIUM | MEDIUM | **P1** |
| CG-06 metrics-server bootstrap question | HIGH (HPA prereq) | MEDIUM | **P1** |
| CG-08 native sidecar question | MEDIUM | LOW | **P1** |
| CG-10 PSS replace (fix content bug) | HIGH | MEDIUM | **P1** |
| CG-11 audit policy question | MEDIUM | MEDIUM | **P1** |
| CG-13 cri-dockerd replace (fix content bug) | HIGH | MEDIUM | **P1** |
| CG-15 kube-proxy modes question | MEDIUM | MEDIUM | **P1** |
| CG-16 NetworkPolicy endPort question | MEDIUM | LOW | **P1** |
| DF-02 trap-frequency aggregation | HIGH | LOW | **P2** |
| DF-03 suggested-next-drills | HIGH | LOW | **P2** |
| DF-09 retake with re-randomised draw | MEDIUM | LOW | **P2** |
| DF-11 author lint | MEDIUM | MEDIUM | **P2** |
| DF-12 fixture CI | MEDIUM | MEDIUM | **P2** |
| DF-08 hint reveal | MEDIUM | LOW | **P2** |
| CG-03 CoreDNS troubleshoot | MEDIUM | MEDIUM | **P2** |
| CG-04 kubectl debug node | MEDIUM | LOW | **P2** |
| CG-05 NetPol troubleshoot | MEDIUM | LOW | **P2** |
| CG-12 CRD basics | MEDIUM | LOW | **P2** |
| Second mock pack | MEDIUM | MEDIUM | **P2** |
| DF-06 content-bug traps catalogued | MEDIUM | LOW | **P2** |
| DF-10 trap heatmap | LOW | LOW | **P3** |
| DF-14 kubeadm-flags reference card | LOW | LOW | **P3** |
| CG-09 scheduler profile question | LOW | MEDIUM | **P3** |
| External contributor onboarding | LOW | MEDIUM | **P3** |

**Priority key:**
- **P1** — Must have for the v1 Core-Value experience: a trap-aware 2-hour mock against the user's own cluster.
- **P2** — Should have, add as the v1 loop runs and reveals what's missing.
- **P3** — Nice to have; only worth building if the user is still actively using v1 six months in.

---

## Competitor Feature Analysis

Public landscape positioning. Confidence: MEDIUM (training-data based; web search unavailable this run; specific feature claims should be re-verified before any public marketing). The point isn't to copy any of these — it's to clarify why the project exists.

| Feature | killer.sh (CNCF official) | KodeKloud CKA labs | mumshad/CKA-Exercises (GH) | This Simulator |
|---------|---------------------------|---------------------|----------------------------|----------------|
| **Cluster topology** | Disposable HA cluster on their infra (ssh into nodes) | Single-VM kind/minikube per lab | None — text instructions only | **User's own 1+2 GCP cluster** (real multi-node fidelity) |
| **Hosting** | Hosted web portal, SSH gateway | Hosted web portal | GitHub repo only | **Self-hosted on the cluster** |
| **Pricing** | Bundled with LF voucher (paid) | Subscription | Free | **Free (open source)** |
| **Question count** | ~22-25 questions, 36h access | Hundreds of small labs | ~150 questions, prose-graded | **17/mock + ~75 across 5 domain packs** (matches real CKA size) |
| **Timer** | Yes — 2h built into portal | Per-lab, varies | None (markdown) | **Yes — exam mode** |
| **Pass/fail grading** | Yes, automated | Yes, automated | None — self-graded | **Yes — kubectl assertions** |
| **Per-domain breakdown** | Yes | Partial | None | **Yes** |
| **Trap diagnostics** | "Solution" text + community comments | "Hint" + solution | Solution at bottom of question | **Named, frequency-tracked traps** ← differentiator |
| **Cross-session learning** | Two sessions, no aggregation | Tracks lab completion | None | **Trap-frequency history across all sessions** ← differentiator |
| **Author / extend** | Closed | Closed | Fork the repo | **First-class authoring template + lint** |
| **Real exam fidelity** | High (visual + functional) | Medium (single VM) | Low (prose only) | **Functional only** (PROJECT.md scope) |
| **Source of cluster bugs** | Their infra | Their infra | N/A | **The user's real cluster** ← what they'll fail on at the real exam |

**Strategic takeaways for FEATURES.md:**
- killer.sh is the gold standard for *visual + access* fidelity but doesn't teach the *class of mistake*. The trap framework is the wedge.
- KodeKloud is great for grinding small skills but its single-VM hides multi-node footguns (hostPath nodeAffinity, NetworkPolicy across nodes, kube-proxy mode effects). Real-cluster fidelity is the wedge.
- mumshad's repo is structurally similar to *what this repo was before this project* — prose questions, no automation. The runner CLI + grader + trap framework is the wedge.
- This project does not try to win on UX, breadth, or hosting — it wins on **trap-aware feedback against a real multi-node cluster**.

---

## Sources

- `.planning/PROJECT.md` — Core Value, Active requirements, Out of Scope, Constraints, Key Decisions (HIGH).
- `.planning/codebase/ARCHITECTURE.md` — existing exercise/mock-exam structure, conventions (HIGH).
- `.planning/codebase/CONCERNS.md` — content-accuracy bugs, coverage gaps, script fragility (HIGH).
- `README.md` lines 3201–3275 — Study Progress Tracker, authoritative checklist (HIGH).
- Published CNCF CKA Curriculum v1.35 — domain weights (Storage 10 / Trbl 30 / Workloads 15 / Cluster 25 / Net 20), 2h / ~17q / 66% pass (MEDIUM — cited in PROJECT.md context, not re-verified this run).
- killer.sh / KodeKloud / mumshad CKA-Exercises feature claims — domain knowledge (MEDIUM — web search unavailable this run; flagged inline).

---
*Feature research for: CKA Exam Simulator (self-hosted, bash, kubectl, trap-aware)*
*Researched: 2026-05-07*

# Research Summary — CKA Exam Simulator v1.0

**Domain:** Bash-only CKA exam simulator on learner's own 1+2 kubeadm/Ubuntu 22.04 GCP cluster, Kubernetes 1.35
**Synthesized:** 2026-05-07
**Sources:** `.planning/research/STACK.md`, `FEATURES.md`, `ARCHITECTURE.md`, `PITFALLS.md` (all verified against v1.0 milestone scope)
**Downstream consumer:** gsd-roadmapper — phase structure, build order, quality gates

---

## Core Value Reminder

A candidate takes a 2-hour timed mock against their own 1+2 kubeadm cluster and receives an honest, trap-aware score telling them exactly which CKA domains and which classes of mistake they need to drill before sitting the real exam.

Every decision below serves that one experience.

---

## Stack — what to build on

**Load-bearing (HIGH confidence, zero novelty risk):**
- **GNU bash 5.1.x** (Ubuntu 22.04 default) — runner, all setup/grade/reset scripts
- **kubectl v1.35.x** — sole cluster API surface; client minor pinned to server minor
- **OpenSSH 8.9** — `ssh-keygen ed25519`, `~/.ssh/config` Host stanzas for `node-01`/`node-02`, `ssh-copy-id` for idempotent key distribution
- **etcdctl v3.5** + `ETCDCTL_API=3` — for etcd backup/restore lab questions
- **crictl v1.35** — CKA exam uses containerd; Docker aliases in existing `scripts/exam-setup.sh` are misleading and must be replaced
- **jq 1.6** (Ubuntu 22.04 apt main) — JSON parsing in graders where jsonpath can't reach
- **mikefarah yq v4** (Go static binary, NOT Python yq) — YAML edits in setup.sh
- **whiptail** (libnewt) — optional TUI menus, fallback to plain prompts
- **bats-core** + **shellcheck** + **yamllint** — dev/CI only, never on exam VM

**Hard rules (from PROJECT.md, reinforced by STACK):**
- No Go or Python runtime for the runner — must run on the candidate's VM with zero extra installs beyond `apt-get`-main
- Target OS locked to Ubuntu 22.04; do not assume 24.04 features (bash 5.2, jq 1.7, etc.)
- No `yq` (ambiguous — Python vs Go), no `expect`, no `dialog`, no `sshpass`, no krew plugin layout, no custom DSL for question files

---

## Feature Priority (v1 MVP — must ship to honour Core Value)

Full taxonomy in FEATURES.md. The MVP set, grouped for the roadmapper:

**Cluster bootstrap (prerequisite for everything else):**
- TS-09 `ssh node-NN` UX, TS-10 alias preset, TS-11 vimrc, TS-12 `ETCDCTL_API=3`, TS-13 kubeconfig context
- Idempotent key distribution, `/etc/hosts` population, BatchMode SSH verification
- Discovers nodes via `kubectl get nodes -o jsonpath=...` (no hard-coded IPs)

**Question runtime contract (the triplet):**
- TS-03 `setup.sh` — idempotent, creates lab namespace + broken state
- TS-04 `grade.sh` — kubectl-driven; emits `SCORE: N/M` + named traps
- TS-05 `reset.sh` — returns cluster to clean baseline
- DF-04 idempotent everything (a hard constraint, not a feature)

**Trap-aware grader (THE differentiator):**
- DF-01 every `grade.sh` emits `Trap N: <description>` lines on fail
- DF-06 trap catalog encodes CONCERNS.md content bugs: `pss-error-string-mismatch`, `psp-fictional-pod-label-exemption`, `kubelet-runtime-flag-in-kubeconfig`, `removed-container-runtime-flag`, `hostpath-pv-without-nodeaffinity`, `as-flag-format-wrong`, `default-sa-used`, `missing-dns-egress`

**Coverage (5 domain packs + 2 mock-exam packs):**
- TS-19 five domain packs mapped 1-to-1 against the v1.35 Study Progress Tracker
- TS-02 two mock-exam packs, each 17 questions / 120 min, weighted 10/30/15/25/20
- Net-new questions required (CG- items from FEATURES.md): CSI/VolumeSnapshot, metrics-server bootstrap, native sidecar, PSS-replacement, audit policy, CRI-dockerd-replacement, kube-proxy modes, NetworkPolicy endPort

**Runner CLI + scoring + reporting:**
- TS-01 2-hour countdown timer (bash, `date +%s` + `tput`, no background procs required)
- TS-08 flag/skip/return, TS-15 pause (Ctrl-Z), TS-16 end-of-exam batch grading
- TS-06/07 per-domain breakdown, TS-17 Markdown report to `~/.cka-sim/sessions/<ts>.md`
- TS-20 drill mode (single question, no timer)

**Polish / policy:**
- TS-18 disclaimer banner in every pack
- DF-15 superseded banner on `exercises/`, `mock-exams/`, root README

**Explicitly deferred to v1.x (FEATURES.md "Add After Validation"):**
- DF-02 trap-frequency aggregation across sessions
- DF-03 suggested-next-drills routing
- DF-09 retake with re-randomised draw
- DF-11/12 author lint + fixture CI
- Additional CG questions beyond the P1 set

**Anti-features (FEATURES.md AF-*, do not build):** GUI/web portal, multi-tenant, cloud-vendor-specific labs, real CKA exam content, PSI-Bridge emulation, killer.sh-style portal, VM provisioning, kubeadm bootstrap, CKAD/CKS, backport to v1.34.

---

## Architecture — shape and build order

**Top-level layout (ARCHITECTURE.md):**
```
cka-sim/
├── bin/cka-sim              # router, only file on $PATH
├── lib/
│   ├── cmd/{bootstrap,drill,exam,score,list,version}.sh
│   ├── schema.sh loader.sh runner.sh timer.sh state.sh preflight.sh
│   ├── traps.sh grade.sh score.sh report.sh log.sh colors.sh
├── packs/{storage,troubleshooting,workloads-scheduling,cluster-architecture,services-networking}/
│   └── NN-slug/{metadata.yaml,question.md,setup.sh,grade.sh,reset.sh}
├── exams/{blueprint-alpha,blueprint-bravo}/manifest.yaml
├── traps/catalog.yaml
└── tests/
```

**Key architectural patterns:**
1. **Composition over duplication** — exams reference questions by `pack/slug`; never copy question dirs into `exams/`
2. **Dot-sourced library** — `source lib/*.sh`, functions namespaced `cka_sim::*`; no re-exec subshells
3. **Trap detection is a shared library, not per-question** — `lib/traps.sh` exports reusable detectors; each `grade.sh` sources it and emits trap IDs; report renderer joins IDs to names from `traps/catalog.yaml`
4. **Idempotent setup, conservative reset** — runner ALWAYS runs `reset.sh` before `setup.sh` for the same question to avoid cross-session poison
5. **Session = one JSON doc + Ctrl-C trap** — `~/.cka-sim/sessions/<ts>.json` with `flock`; `SIGINT` persists state then exits 130; `exam --resume <ts>` rehydrates

**Coexistence with existing repo (hard constraint from PROJECT.md):**
- All new code goes under `cka-sim/` — zero files moved or renamed outside it
- `exercises/`, `skeletons/`, `mock-exams/`, `cheatsheet/`, `troubleshooting/` stay; banner-only updates route new learners to `cka-sim/`
- `scripts/exam-setup.sh` is SOURCED (not forked) by `cka-sim bootstrap` so the `k`/`$do`/`$now` alias contract is the same
- `scripts/validate-local.sh` + `.github/workflows/validate.yml` extended to also lint `cka-sim/**`
- Namespace convention diverges intentionally: existing uses `exercise-NN`, new uses `cka-sim-<domain>-NN` to prevent collision

**Critical build order (ARCHITECTURE.md 18 steps, compressed):**

| # | Step | Blocks |
|---|------|--------|
| 1–3 | Schema + router + bootstrap | All later work |
| 4 | Trap catalog + `lib/traps.sh` | First grader |
| 5 | `lib/grade.sh` assertion helpers | All graders |
| 6 | runner + state + timer | drill/exam commands |
| 7 | drill command + 1-2 reference questions per domain | Closes bootstrap → drill loop |
| 8–12 | Fill out 5 packs (storage, workloads-scheduling, services-networking, cluster-architecture, troubleshooting in that order) | Scoring pass |
| 13 | score + report libs | exam command |
| 14 | exam command + blueprint-alpha | Polish |
| 15 | blueprint-bravo | Polish |
| 16 | score history + trap-frequency (v1.x preview) | — |
| 17 | Superseded banners | — |
| 18 | CI extension (shellcheck + yamllint cka-sim/**) | — |

**Critical sequencing rule:** step 4 (trap catalog + `lib/traps.sh`) MUST land before step 7 (first reference questions). Authoring graders before trap helpers exist guarantees rework.

---

## Pitfalls — what the roadmap must prevent

14 pitfalls in PITFALLS.md. The ones that most shape phase structure:

**Pitfalls that demand a shared contract before any question ships:**
1. Non-idempotent setup → setup template + CI "run setup.sh twice" check
2. Grader false positives (existence-check instead of behavioural) → `lib/assert.sh` with `assert_can_i`, `assert_egress_allowed`, `assert_field`; CI lint forbids `kubectl get | grep`
3. Grader false negatives (noisy global state) → always `-n <ns>`, never `-A`; prefix cluster-scoped names with `q<NN>-`
4. Cross-question state leak → per-question name-spacing; end-of-exam grading reads from snapshot, not live cluster
14. Tool whitelist drift (yq, stern, etc.) → CI lint scans for non-whitelisted binaries; `jq` only, no `yq`

**Pitfalls that shape cluster bootstrap:**
8. Cluster-feature dependency (metrics-server, Gateway API CRDs) → question metadata `requires:`, `cka-sim install <component>`
10. Single-node practice habit → `cka-sim doctor` requires ≥3 nodes
13. SSH bootstrap fragility → `StrictHostKeyChecking=accept-new`, idempotent authorized_keys via `ssh-copy-id`, `BatchMode=yes` verification

**Pitfalls that shape the runner CLI:**
5. Bash signal handling — `trap` for SIGINT→flag, SIGTSTP→pause, EXIT→persist; `ControlMaster auto` in ssh config
6. Generic trap diagnostics → ≥3 named traps per question, authoring template enforces
7. Time budget mis-calibration → pack validator: 110-120 min total, 4-12 per Q

**Pitfalls that shape content authoring:**
9. YAML-from-memory practice instead of imperative-kubectl — solution template enforces imperative-first, YAML line-budget
11. Content drift to deprecated APIs — CI lint for deprecated-strings, question front-matter `verified_against: 1.35`
12. Missing v1.35 syllabus topics — coverage-matrix lint, 1-question-per-checkbox minimum

Each pitfall has a "Phase to address" hint in PITFALLS.md — the roadmapper should honour those.

---

## Watch Out For (flagged confidence gaps)

- **Tool version pins** — Ubuntu 22.04 apt ships jq 1.6, not 1.7; `scripts/validate-local.sh` assumes `python3`. Verify at install time.
- **Subagent spawning not available in current runtime** — the orchestrator must execute researcher/roadmapper responsibilities inline rather than delegate.
- **Git identity not configured** in this repo — commits in the workflow are currently blocked; artifacts are written to disk and committed manually.
- **killer.sh internals not directly verifiable** — competitor-pattern claims in FEATURES.md are training-data based, not live-verified.
- **PSI exam environment has historically been Ubuntu 22.04** — locked-in for fidelity. If PSI moves to 24.04 mid-milestone, re-evaluate.

---

## Recommended Phase Shape for v1.0 Roadmap

Derived from the architecture build order + pitfall phase-hints + feature priority. This is a research recommendation — the roadmapper finalizes.

| Phase | Goal | Key deliverables | Pitfalls addressed |
|-------|------|------------------|---------------------|
| **1. Cluster bootstrap + runner skeleton** | `cka-sim` invocable on the CP node; `cka-sim doctor` green against 1+2 cluster | `bin/cka-sim` router + `lib/{log,colors,state,schema,preflight}.sh` + `cmd/bootstrap.sh` + SSH config + alias integration | 10, 13 |
| **2. Trap framework + assertion library** | Shared `lib/traps.sh` + `lib/grade.sh` + `traps/catalog.yaml` seeded with ≥8 CONCERNS.md-derived traps | lib modules + catalog + ≥3 pilot traps with detection verified | 2, 3, 6, 14 |
| **3. Question runtime contract + drill mode** | End-to-end single-question loop works: `cka-sim drill <pack>` runs setup→grade→reset against one reference question per domain | `lib/{runner,timer}.sh` + `cmd/drill.sh` + 5 reference questions (one per domain) + setup template + CI "run setup.sh twice" gate | 1, 9 |
| **4. Storage + Workloads-Scheduling packs** | Full coverage of the 2 smaller-weight domains; includes CSI/VolumeSnapshot, native sidecar, metrics-server | ~8–10 questions + reference links to superseded exercises | 8, 11, 12 |
| **5. Services-Networking + Cluster-Architecture packs** | Full coverage of mid-weight domains; includes kube-proxy modes, NetworkPolicy endPort, PSS replacement, audit policy, CRI-dockerd-endpoint | ~10–12 questions | 11, 12 |
| **6. Troubleshooting pack (30%, largest)** | Full coverage of the highest-weighted domain; CoreDNS, NetPol-trbl, node-debug, etcd-endpoint | ~8–10 questions, cross-references other packs | 8, 12 |
| **7. Exam mode + blueprint-alpha** | `cka-sim exam blueprint-alpha` runs a 17-Q/120-min mock against real cluster; end-of-exam report renders | `lib/{score,report}.sh` + `cmd/exam.sh` + signal handling + session JSON + blueprint-alpha manifest | 4, 5, 7 |
| **8. blueprint-bravo + polish** | Second blueprint ships; banners on superseded content; CI extension for `cka-sim/**`; docs | blueprint-bravo + `cka-sim/README.md` + `AUTHORING.md` + `CONTRIBUTING.md` section + validate.yml extension | — |

**Requirement-to-phase mapping preview** (roadmapper will finalize REQ-IDs):
- Bootstrap + runner: phases 1, 3, 7
- Trap framework + content bugs: phase 2, 5
- Domain packs: phases 4–6
- Mock packs: phases 7–8
- Superseded banners + docs: phase 8

---

## Open questions for the roadmapper

1. Should the 5 domain packs be 5 separate phases (heavy roadmap) or grouped into 2–3 content phases (suggested above)? Trade-off: phase granularity vs phase count.
2. Should trap catalog seeding be part of phase 2 (framework) or distributed across content phases? Recommendation: seed the 8 CONCERNS.md-derived traps in phase 2, add domain-specific traps in their respective content phases.
3. `blueprint-alpha` and `blueprint-bravo` could be one phase (both blueprints ship together) or two (alpha in phase 7, bravo in phase 8). Recommendation: split for risk reduction — one exam is a meaningful milestone gate.

---

*Synthesized for milestone v1.0 CKA Exam Simulator MVP on 2026-05-07. All inputs verified against the locked milestone scope (Ubuntu 22.04, 5 domain packs + 2 mock-exam packs, reference-only use of existing exercises).*

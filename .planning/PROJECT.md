# CKA Exam Simulator

## What This Is

A bash-only, kubectl-driven CKA (Certified Kubernetes Administrator) exam simulator that runs against a learner's own 1-control-plane + 2-worker kubeadm cluster. Ships two timed 17-question mock exams (blueprint-alpha and blueprint-bravo), five domain packs (Storage, Workloads & Scheduling, Services & Networking, Cluster Architecture, Troubleshooting) with 38 total questions, a trap-aware grading framework that distinguishes setup state from candidate work, and CLI subcommands (`drill`, `exam`, `score`, `list`, `bootstrap`, `doctor`). Built for one CKA candidate preparing for the real v1.35 exam; verified end-to-end on a live 1+2 GCP Ubuntu cluster.

## Core Value

**A candidate can take a 2-hour timed mock exam against their own cluster and get an honest, trap-aware score telling them exactly which CKA domains and which classes of mistake they need to drill before sitting the real exam.** v1.0 delivered this end-to-end with grading honesty verified: empty submission scores 0/100, reference solutions score max/max.

## Current State

**Shipped v1.0 (2026-05-17):** Full CKA exam simulator operational on live cluster.
- 38 questions across 5 domain packs (Storage 10%, W&S 15%, S&N 20%, CA 25%, Troubleshooting 30%)
- 2 mock exam blueprints (alpha, bravo) — 17 questions / 130 minutes each
- Bash-only runtime (~1000 LOC core + 19000 LOC tests/fixtures/docs)
- Trap framework: 47 catalog entries, 8 root-cause detectors
- Live cluster UAT: 17/17 ref-solution round-trip PASS, empty=0/100 verified
- CI: shellcheck, lint-packs (298 checks), lint-traps (47 entries), test.sh (78 cases)

**Tech stack:** Pure Bash + kubectl + jq + standard Ubuntu 22.04 binaries. No external runtime dependencies beyond what `apt-get` ships.

## Requirements

### Validated (v1.0)

- ✓ Cluster bootstrap script — `cka-sim bootstrap` configures existing 1+2 cluster, SSH topology, doctor check — v1.0
- ✓ Domain coverage map — every v1.35 Study Progress Tracker checkbox mapped to ≥1 question — v1.0
- ✓ Five domain packs (Storage, W&S, S&N, CA, Troubleshooting) — 38 questions total — v1.0
- ✓ Per-question runtime triplet (`setup.sh` / `grade.sh` / `reset.sh`) — bash-only, idempotent — v1.0
- ✓ Trap-aware grader — 47 catalog entries with named `Trap N: <description>` diagnostics — v1.0
- ✓ Two mock-exam packs — blueprint-alpha + blueprint-bravo, 17 questions / 130 min each — v1.0
- ✓ Runner CLI (`cka-sim`) — `drill`, `exam`, `score`, `list`, `bootstrap`, `doctor` subcommands — v1.0
- ✓ Score report — Markdown with total, per-domain %, trap frequencies — v1.0
- ✓ Existing-content banner — superseded notices on legacy exercises/mock-exams — v1.0
- ✓ Documentation — README, AUTHORING, SCHEMA, CONTRIBUTING, GRADING-HONESTY — v1.0
- ✓ Grading honesty (Phase 07.1) — setup-state vs candidate-authored distinction; baseline capture + ownership gates — v1.0

## Current Milestone: v1.0.1 Full Audit Remediation

**Goal:** Fix all 15 audit findings (6 HIGH + 9 MED) from `.planning/forensics/report-20260517-091657-full-audit.md`, plus add CI lints to prevent recurrence.

**Target features:**
- Fix 6 HIGH-severity question bugs (storage/01-pvc-binding, services-networking/05-kube-proxy-mode, cluster-architecture/04-pss-enforce, cluster-architecture/08-priorityclass, troubleshooting/04-debug-node, troubleshooting/05-static-pod-manifest)
- Fix 9 MED-severity question bugs (3 metadata-orphan-trap, 3 grader-weaker-than-question, 2 question-framing, 1 grader-grep-pattern)
- Add lint: every `metadata.yaml` trap → matching `record_trap` call in `grade.sh`
- Add live-cluster CI step: `setup.sh && kubectl get ...` diff vs per-question expected-symptom YAML
- Fix library bug `lib/setup.sh:218` (`kubernetes.io\metadata.name` → `/`)

### Active (v2.0 — not yet planned)

Use `/gsd-new-milestone` to scope. Candidate ideas based on v1.0 outcomes:

- Domain coverage gap closure — any audit-escape questions from 07.1 that need file-baseline support (etcd snapshot, audit-policy YAML, node-level files)
- Real-cluster CI — github-hosted runner that spins up a kind/k3s cluster and runs grading-honesty UAT
- Optional candidate quality-of-life: aliases, kubectl-neat integration, time-tracking per question

### Out of Scope (carried from v1.0)

- Provisioning the GCP VMs (Terraform / `gcloud compute instances create`) — manual one-time step
- Bootstrapping the kubeadm cluster (kubeadm init/join) — cluster pre-exists
- Browser / PSI-like web-terminal emulation — terminal-only functional fidelity
- CKAD or CKS exam content — strictly CKA v1.35
- Multi-tenant / shared cluster mode — single learner
- Cloud-vendor-specific labs — vendor-neutral kubeadm
- Killer.sh-style exam portal / VPN / leaderboard
- Question content from the real CKA exam — CNCF NDA
- Pre-v1.35 Kubernetes versions

## Context

**Shipped scope (v1.0):** 9 phases, 88 plans, 89 SUMMARYs, 501 commits, 11.5 months elapsed. All work verified on live 1+2 Ubuntu 22.04 / Kubernetes 1.35 cluster on GCP. Phase 07.1 was inserted late as urgent gap-closure when Phase 07 UAT revealed setup-state leak (empty exam scored 10/100 instead of 0/100); rebuilt grading framework with baseline-capture + ownership gates; verified 17/17 round-trip on live cluster.

**Notable v1.0 incidents resolved during milestone:**
- Wave 3 + Wave 5 merge commits silently disappeared from git history during 07.1 execution — recovered via cherry-pick of 20 plan commits
- `assert_changed_since_setup` rv-fallback misfired when controllers updated resource status — fixed by making generation comparison authoritative
- kubectl short kinds (`pv`, `svc`) didn't match canonical baseline keys — added kind normalization helper
- 11 SUMMARY.md files were missing at milestone close — backfilled from feat commit messages

**Cluster topology (verified):** 1 control-plane + 2 workers, Ubuntu 22.04, GCP Compute Engine, kubeadm + containerd, Kubernetes 1.35. SSH topology validated; `cka-sim doctor` green.

## Constraints (carried from v1.0)

- **Tech stack:** Pure Bash + kubectl/etcdctl/crictl + jq, no Go/Python CLIs
- **Cluster topology:** 1 CP + ≥2 workers, Ubuntu 22.04, kubeadm + containerd, K8s 1.35
- **Provisioning:** GCP VMs pre-existing
- **Content scope:** v1.35 CKA Study Progress Tracker; no CKAD/CKS scope creep
- **Grading discipline:** Binary pass/fail AND named trap diagnostic per failure mode; setup-state must not score
- **No real exam content:** All questions independently authored
- **Single-learner mode:** One candidate, one cluster
- **Idempotent setup/reset:** Every loop safe to replay

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Rebuild from Study Progress Tracker rather than retrofit 31 exercises | Existing exercises had content drift; cleaner to author fresh | ✓ Good — 38 fresh questions ship with v1.0 |
| Configure existing cluster only (no Terraform/kubeadm bootstrap) | Manual one-time GCP step; not core value | ✓ Good — bootstrap.sh handles SSH/doctor only |
| Per-question `setup.sh` + `grade.sh` + `reset.sh`, all bash | Matches real exam shell; isolation enables replay | ✓ Good — pattern held across 38 questions |
| Grader emits named "trap" diagnostics, not just pass/fail | Trap-aware feedback differentiator | ✓ Good — 47 catalog entries deliver named diagnostics |
| Build both `cka-sim drill` AND `cka-sim exam` | Drill for targeted learning, exam for realistic stress | ✓ Good — both shipped, both verified |
| Build both domain packs AND mock-exam packs | Domain packs for drilling, mock packs for full exams | ✓ Good — 5 domain packs + 2 mock packs |
| SSH topology: candidate works from CP node | Common killer.sh topology; no 4th student VM | ✓ Good — verified on live cluster |
| Existing 31 exercises kept and labelled "superseded" | Preserves prose study material as reference | ✓ Good — banners added in Phase 08 |
| Bootstrap does NOT inject shell aliases or modify `~/.vimrc` | Muscle memory matches real exam minimal pre-config | ✓ Good — opt-in only |
| All K8s resource names conform to RFC 1123 | K8s rejects non-compliant names; CI-enforced | ✓ Good — 47 catalog entries pass lint |
| Decimal-version phase insertion (07.1) for urgent gap closure | Avoid renumbering 08; preserve audit trail | ✓ Good — pattern works, archived as Phase 07.1 |
| Distinguish setup state from candidate work via baseline capture | Original graders leaked points (10/100 on empty); honest scoring required for exam fidelity | ✓ Good — verified 0/100 on empty, 17/17 on ref-solution |
| `assert_changed_since_setup` uses generation-first comparison | rv comparison flaky for status-updating resources (Deployment status, PV binding) | ✓ Good — verified during 07.1 UAT |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-17 — v1.0.1 milestone opened (full audit remediation)*

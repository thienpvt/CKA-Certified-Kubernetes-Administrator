# CKA Exam Simulator

## What This Is

A complete, automated CKA (Certified Kubernetes Administrator) exam simulator that runs on a learner's own existing 1-control-plane + 2-worker Ubuntu cluster (provisioned manually on GCP). Each question ships with `setup.sh` (creates the broken state / preconditions), `grade.sh` (kubectl checks with named "trap" diagnostics for common candidate mistakes), and `reset.sh`, plus a runner CLI that supports both `cka-sim drill` (single-question domain practice) and `cka-sim exam` (timed 17-question / 2-hour mock with per-domain scoring). Built for one CKA candidate (the repo owner) preparing for the real CKA exam, with the existing 31-exercise study guide kept in place as superseded reference material.

## Core Value

**A candidate can take a 2-hour timed mock exam against their own cluster and get an honest, trap-aware score telling them exactly which CKA domains and which classes of mistake they need to drill before sitting the real exam.** Everything else in this project (domain packs, ssh-node scaffolding, individual graders) exists to feed that one experience.

## Current Milestone: v1.0 — CKA Exam Simulator MVP

**Goal:** Ship a trap-aware, bash-only CKA exam simulator that runs a 2-hour timed mock against the learner's own 1+2 kubeadm cluster.

**Target features:**
- Cluster bootstrap script for the existing 1+2 Ubuntu 22.04 GCP cluster (SSH `node-01`/`node-02`, aliases, vimrc, `ETCDCTL_API`, kubeconfig)
- Domain coverage map — every v1.35 Study Progress Tracker checkbox → ≥1 exam-sim question
- Five domain packs (Storage 10%, Troubleshooting 30%, Workloads & Scheduling 15%, Cluster Architecture 25%, Services & Networking 20%) — may reference existing `exercises/NN/` as prior art, never copy
- Per-question runtime triplet (`setup.sh` / `grade.sh` / `reset.sh`), idempotent, bash-only
- Trap-aware grader with named `Trap N: <description>` diagnostics; trap catalog encodes content-bug traps (PSS wording, kubelet flag file, hostPath `nodeAffinity`, `--as=` format) so the simulator teaches the correct mental model
- **Two** mock-exam packs — each 17 questions / 2 hours, weighted to the v1.35 CKA blueprint (30/25/20/15/10), composed by reference from the five domain packs
- Runner CLI (`cka-sim`) with `drill` + `exam` modes (flag/skip/pause, end-of-exam batch grading)
- Score report — Markdown: total, per-domain %, trap frequencies, suggested next drills
- Existing-content banner labelling `exercises/`, `mock-exams/`, root README as superseded (no deletion)
- Documentation — runner/cluster/trap docs + `CONTRIBUTING.md` question-authoring section

## Requirements

### Validated

<!-- From the existing codebase map (.planning/codebase/) — already shipped, kept as superseded study-guide reference. -->

- ✓ 31 hands-on exercises under `exercises/NN-slug/README.md` covering most CKA topics — existing
- ✓ 23 single-resource YAML skeletons under `skeletons/` — existing
- ✓ 2 paired mock exams under `mock-exams/` (15 questions each, prose-graded) — existing
- ✓ Symptom-indexed troubleshooting playbook (`troubleshooting/README.md`) — existing
- ✓ kubectl/cheatsheet quick-reference (`cheatsheet/cka-cheatsheet.md`) — existing
- ✓ Exam-setup helper (`scripts/exam-setup.sh`) defining the `k`/`kn`/`kgp`/`$do`/`$now` aliases — existing
- ✓ Local YAML lint (`scripts/validate-local.sh`) + matching CI workflow — existing
- ✓ Repository conventions (exercise template, commit prefixes, namespace `exercise-NN`) — existing

### Active

<!-- Current scope. All hypotheses until shipped. -->

- [ ] **Cluster bootstrap script** — configures an *existing* 1+2 Ubuntu cluster on GCP (no provisioning) so that from the control-plane node the candidate can `ssh node-01` / `ssh node-02` like the real PSI exam, with exam aliases / vimrc / `ETCDCTL_API=3` / kubeconfig context all pre-loaded.
- [ ] **Domain coverage map** — every checkbox in the README's Study Progress Tracker (Domains 1-5 + Exam Readiness) maps to one or more exam-sim questions; gaps from the current 31-exercise corpus get net-new questions.
- [ ] **Domain packs** — one pack per CKA domain (Storage 10%, Troubleshooting 30%, Workloads & Scheduling 15%, Cluster Architecture 25%, Services & Networking 20%) for targeted drilling.
- [ ] **Per-question runtime triplet** — every question ships `setup.sh` (idempotent, creates the lab namespace + any broken state + required SSH context), `grade.sh` (kubectl-driven pass/fail + named trap diagnostics), `reset.sh` (cleanup back to baseline). Pure bash, runnable in isolation against a clean cluster.
- [ ] **Trap-aware grader** — `grade.sh` actively detects top common mistakes per question (wrong namespace, missing DNS egress, wrong `--as=` form, default ServiceAccount used, RBAC scope wrong, hostPath without `nodeAffinity`, etc.) and prints `Trap N: <description>` so the candidate learns the *class* of mistake, not just pass/fail.
- [ ] **Mock-exam packs** — two realistic 17-question / 2-hour exam packs that mix domains by exam-weighting (matching the real CKA blueprint), reusing question content from the domain packs.
- [ ] **Runner CLI (`cka-sim`)** — `cka-sim drill <pack> [<n>]` for single-question practice and `cka-sim exam <pack>` for timed full-mock with flag/skip, end-of-exam grading, 100-point score, per-domain breakdown, and per-trap aggregation.
- [ ] **Score report** — at exam end, prints a Markdown summary: total score, per-domain percentage, list of traps hit (with frequencies), suggested domain packs to drill next.
- [ ] **Existing-content banner** — `exercises/`, `mock-exams/`, and the README get a "superseded — see exam-sim/" pointer that doesn't delete the prose but routes new learners to the simulator.
- [ ] **Documentation** — top-level README section explaining cluster prerequisites, the runner CLI, the trap framework, and how to add new questions. Plus a `CONTRIBUTING.md` update covering question-authoring conventions for the exam-sim.

### Out of Scope

<!-- Explicit boundaries with reasoning to prevent re-adding. -->

- **Provisioning the GCP VMs (Terraform / `gcloud compute instances create`)** — the user provisions VMs themselves and considers that a one-time, manual step.
- **Bootstrapping the kubeadm cluster (kubeadm init / join)** — assumes the cluster already exists; configuring it for SSH/aliases is in scope, building it is not.
- **Browser / PSI-like web-terminal emulation** — the runner is terminal-only; PSI's Chromebook environment is reproduced functionally (timer, ssh-node, kubectl) not visually.
- **CKAD or CKS exam content** — strictly CKA v1.35 syllabus; CKAD/CKS would be separate projects.
- **Multi-tenant / shared cluster mode** — a single learner runs against their own cluster; concurrent users not supported.
- **Cloud-vendor-specific labs (GKE/EKS/AKS-only features)** — content stays vendor-neutral kubeadm; GCP is incidental to where the VMs live, not to the curriculum.
- **Killer.sh-style exam VPN / portal infrastructure** — no remote portal, no auth, no leaderboard. The simulator runs locally against the candidate's cluster.
- **Question content from the real CKA exam** — only independently designed practice questions; sharing real exam content violates CNCF policy.
- **Content for older Kubernetes versions** — target is the v1.35 syllabus current at project start (2026-05-07); back-porting to 1.34 or earlier is out of scope.

## Context

**Repository state (from `.planning/codebase/`):** The repo is a study-guide for the CKA exam written by the previous owner — Markdown + YAML + Bash, no application code. It already contains 31 exercises, 23 skeletons, 2 mock exams, and a `scripts/validate-local.sh` lint, but `.planning/codebase/CONCERNS.md` flags content drift (PSP error strings, removed `--container-runtime=remote` flag, missing `priorityclass.yaml` skeleton, domain-link 404s, duplicate cri-dockerd exercises) and several gaps vs the v1.35 syllabus (CRDs, kube-proxy modes, metrics-server bootstrap, native sidecars, NetworkPolicy `endPort`, audit policy). The new exam-sim is the place to fix coverage; the existing exercises stay as superseded reference and don't have to be re-validated.

**Cluster topology (target):** 1 control-plane VM + 2 worker VMs, Ubuntu 22.04 LTS, on GCP Compute Engine, provisioned manually by the candidate. Kubernetes v1.35 via kubeadm. Internal IPs / hostnames `node-01`/`node-02`/`node-03` (or similar) reachable from the control-plane over SSH on the GCP VPC. Containerd runtime; Calico or default CNI.

**Real CKA exam reference (2026):** ~17 questions, 2 hours, PSI-Bridge web-Chromebook environment, candidate works from a "student" terminal and `ssh` into named cluster nodes, allowed only `kubectl.io/docs`, `kubernetes.io/docs`, `helm.sh/docs`. Pass mark 66%. The simulator targets functional fidelity to that experience, not visual fidelity.

**Existing concerns to address en route:** the trap catalog should call out the real-world content bugs already documented in `.planning/codebase/CONCERNS.md` (PSS error wording, kubeadm-flags.env vs kubelet.conf, hostPath nodeAffinity) so the new graders teach the right mental model from day one.

**Why this user is building this:** The owner is a CKA candidate (system context email confirms: `pvtcwd@gmail.com`). They've outgrown the existing prose-only practice format and want timed, automated, trap-aware feedback to identify their weak domains before sitting the real exam.

## Constraints

- **Tech stack**: Pure Bash + standard kubectl / `etcdctl` / `crictl` for the runner — no Go/Python CLIs, no extra dependencies beyond what `apt-get install` ships on Ubuntu 22.04 plus the Kubernetes-installed binaries. Why: keeps the runner installable on the same VM the candidate practices on, and matches the bash-only execution surface of the real exam.
- **Cluster topology**: 1 control-plane + minimum 2 workers, Ubuntu 22.04, kubeadm + containerd, Kubernetes 1.35. Why: matches the v1.35 syllabus and the real exam's multi-node topology with worker `ssh node-NN` access.
- **Provisioning**: GCP VMs are pre-existing and out of scope. Why: the candidate has already built and pays for the cluster manually; re-provisioning is friction, not value.
- **Content scope**: All v1.35 CKA Study Progress Tracker checkboxes covered, no CKAD/CKS scope creep. Why: a focused, *complete* CKA simulator is more valuable than a partial three-cert simulator.
- **Grading discipline**: Every grader must produce both a binary pass/fail AND at least one named trap diagnostic per failure mode it knows how to detect. Why: the core value is "honest, trap-aware feedback" — generic pass/fail is what `mock-exams/` already does and isn't differentiated.
- **No real exam content**: All questions independently authored; explicit disclaimer in each pack. Why: CNCF NDA — sharing real exam content is grounds for decertification.
- **Single-learner mode**: Designed for one candidate at a time on their own cluster. Why: avoids the auth/multi-tenant complexity of a service like killer.sh and matches how the user actually practices.
- **Idempotent setup**: Every `setup.sh` must be safe to re-run; every `reset.sh` must return the cluster to a known clean baseline. Why: practice loops are short — re-running a setup three times in a session must not poison the lab.

## Key Decisions

<!-- Decisions made during initial questioning (2026-05-07). -->

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Rebuild from the Study Progress Tracker checklist rather than retro-fit existing 31 exercises | Existing exercises have content drift and gaps; cleaner to author fresh, complete coverage than to repair piecemeal — the codebase map's CONCERNS.md backs this | — Pending |
| Configure existing cluster only (no Terraform / kubeadm bootstrap) | User provisions VMs manually as a one-time GCP step; building provisioning automation duplicates effort and isn't core value | — Pending |
| Per-question `setup.sh` + `grade.sh` + `reset.sh`, all bash, runnable in isolation | Bash-only matches the real exam shell; isolation lets a candidate replay any single question without resetting the whole pack | — Pending |
| Grader emits named "trap" diagnostics, not just pass/fail | Trap-aware feedback is the differentiator vs the existing prose mock exams; generic pass/fail teaches less than `Trap 3: missing DNS egress` | — Pending |
| Build both `cka-sim drill` (single Q) AND `cka-sim exam` (timed 2h mock) | Drill mode for targeted learning; exam mode for the realistic stress-test feedback loop. Exam mode is the core-value experience; drill mode is the daily practice surface | — Pending |
| Build both domain packs AND multiple full mock-exam packs | Domain packs serve drilling; mock-exam packs reuse domain questions in a weighted blueprint mix for full mocks | — Pending |
| SSH topology: candidate works from the control-plane node | Common killer.sh-style topology; no need to provision a 4th "student" VM; SSH key generated on CP, authorised on workers | — Pending |
| Existing 31 exercises kept and labelled "superseded", not deleted | Preserves the existing "What tripped me up" war stories as reference; avoids rewriting prose that already works for study | — Pending |
| Bootstrap does NOT inject shell aliases or modify `~/.vimrc` | Candidate practices full `kubectl`/`crictl`/`etcdctl` commands to build muscle memory; opt-in shortcuts are documented but not default. The real exam provides minimal pre-configuration, so practice should match | — Pending |
| All K8s resource names conform to RFC 1123 (`[a-z0-9-]`, ≤63 chars) | Kubernetes rejects non-compliant names; CI-enforced to prevent silent admission failures during question authoring. Also applies to trap IDs, pack IDs, blueprint IDs for consistency | — Pending |

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
*Last updated: 2026-05-07 — milestone v1.0 started*

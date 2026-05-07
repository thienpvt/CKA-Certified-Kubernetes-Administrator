<!-- refreshed: 2026-05-07 -->
# Architecture

**Analysis Date:** 2026-05-07

## System Overview

This repository is a **study guide / exercise collection** — not a runtime application. The "architecture" is the way Markdown content, YAML skeletons, and shell scripts are layered to support a learner moving from reference material, through hands-on practice, into timed exam simulation.

```text
┌─────────────────────────────────────────────────────────────┐
│                    Top-Level Entry Points                    │
├──────────────────┬──────────────────┬───────────────────────┤
│   README.md      │   TEMPLATES.md   │   CONTRIBUTING.md     │
│  (study guide)   │  (YAML index)    │   (PR rules)          │
└────────┬─────────┴────────┬─────────┴──────────┬────────────┘
         │                  │                     │
         ▼                  ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│                 Reference / Quick-Lookup Layer               │
│  `cheatsheet/cka-cheatsheet.md`     `skeletons/*.yaml`      │
│  `troubleshooting/README.md`         `TEMPLATES.md`          │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   Hands-On Practice Layer                    │
│            `exercises/NN-topic-name/README.md`               │
│        (31 exercises, one folder each, README-driven)        │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Timed Simulation Layer                    │
│       `mock-exams/MOCK-EXAM-0N.md` (questions)               │
│       `mock-exams/MOCK-EXAM-0N-SOLUTIONS.md` (answers)       │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   Tooling / Validation                       │
│   `scripts/exam-setup.sh`     `scripts/validate-local.sh`    │
│   `.github/workflows/validate.yml` (CI yamllint)             │
└─────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| Master study guide | Single-page CKA prep narrative, syllabus mapping, exam-day strategy, links to every other artifact | `README.md` |
| YAML template index | Browsable, collapsible Kubernetes resource templates for copy-paste during exercises and exam | `TEMPLATES.md` |
| Cheatsheet | One-page printable kubectl reference | `cheatsheet/cka-cheatsheet.md` |
| Exercise folder | One self-contained hands-on lab with tasks, hints, war story, verification, cleanup, and solution | `exercises/NN-topic/README.md` |
| YAML skeletons | Standalone `.yaml` files mirroring `TEMPLATES.md` entries for direct `kubectl apply -f` use | `skeletons/*.yaml` |
| Mock exam pair | 15-question/2-hour timed simulation plus separate solution file | `mock-exams/MOCK-EXAM-0N.md`, `mock-exams/MOCK-EXAM-0N-SOLUTIONS.md` |
| Troubleshooting playbook | Symptom-indexed lookup table for common failures (Pending, CrashLoop, NotReady, etc.) | `troubleshooting/README.md` |
| Exam environment setup | Aliases, vim config, kubectl completion, etcdctl env — sourced at start of practice | `scripts/exam-setup.sh` |
| Local validator | Python YAML parse + optional yamllint over `skeletons/` and `exercises/` | `scripts/validate-local.sh` |
| CI | yamllint + Python YAML syntax check on push/PR | `.github/workflows/validate.yml` |
| Contribution rules | Commit prefixes, validation requirement, content boundaries (CKA only, no real exam questions) | `CONTRIBUTING.md` |
| Issue intake | Bug report / content request / exam feedback templates | `.github/ISSUE_TEMPLATE/*.md` |

## Pattern Overview

**Overall:** Layered Markdown study guide — reference layer, exercise collection, mock-exam simulation, all linked from a single master `README.md`. Content is the primary artifact; YAML and shell scripts are supporting assets.

**Key Characteristics:**
- **README-as-router:** Top-level `README.md` is the authoritative entry point and indexes every other folder via anchor links and table-of-contents.
- **Per-exercise folder convention:** Every exercise lives in `exercises/NN-topic-name/` and contains exactly one `README.md`. No nested manifests folder, no per-exercise solution file — the solution is collapsed into the README via `<details>` tags.
- **Template duality:** YAML resources exist twice on purpose — once collapsed inside `TEMPLATES.md` for browsing, once as standalone files in `skeletons/` for direct apply. `skeletons/README.md` defers to `TEMPLATES.md` as the canonical source.
- **Question / solution split for mocks:** Mock exams enforce discipline by separating prompts (`MOCK-EXAM-0N.md`) from solutions (`MOCK-EXAM-0N-SOLUTIONS.md`) — learners are instructed not to open the latter until done.
- **No build step:** Pure Markdown + YAML + shell. Rendering happens in GitHub or any Markdown viewer.

## Layers

**Reference layer:**
- Purpose: Fast lookup during exercises and exam-day.
- Location: `cheatsheet/`, `skeletons/`, `TEMPLATES.md`, `troubleshooting/`
- Contains: kubectl one-liners, raw YAML templates, symptom-to-fix tables.
- Depends on: Nothing — pure content.
- Used by: Every exercise (cross-linked), mock-exam solutions, learners during real exam (kubernetes.io is the only allowed external doc; this repo is studied beforehand).

**Practice layer:**
- Purpose: Build muscle memory for one CKA topic per folder.
- Location: `exercises/`
- Contains: 31 exercise folders, each with a single `README.md`.
- Depends on: `skeletons/` (linked at top of each exercise), `README.md` domain anchors.
- Used by: Mock-exam study path (learners are told to do all 31 exercises before mocks).

**Simulation layer:**
- Purpose: Timed end-to-end exam rehearsal.
- Location: `mock-exams/`
- Contains: Two mock exams (questions + solutions), `README.md` with usage protocol.
- Depends on: All prior layers — assumes exercises completed.
- Used by: Final-prep stage, gates readiness ("12+/15 = ready for real exam").

**Tooling layer:**
- Purpose: Make the practice environment match exam conditions and prevent broken YAML from landing.
- Location: `scripts/`, `.github/workflows/`
- Contains: One setup script, one validator script, one CI workflow.
- Depends on: Nothing inside the repo (Python 3, optional yamllint).
- Used by: Contributors locally before pushing; CI on every push to `main` and PRs.

## Data Flow

### Primary Learner Path (intended traversal)

1. Land on `README.md` — read disclaimer, syllabus, study plan (`README.md` lines 1–195).
2. Run `bash scripts/exam-setup.sh` — get `k`, `$do`, `$now` aliases and vim config.
3. Open `cheatsheet/cka-cheatsheet.md` for kubectl reference.
4. Work through `exercises/01-pod-basics/README.md` → `exercises/31-argocd-gitops-setup/README.md` in order; copy YAML from `TEMPLATES.md` or `skeletons/` as needed.
5. When stuck, jump to `troubleshooting/README.md` symptom table.
6. Take `mock-exams/MOCK-EXAM-01.md` under 2-hour timer; review against `MOCK-EXAM-01-SOLUTIONS.md`.
7. Identify weak domains, revisit related exercises, take `mock-exams/MOCK-EXAM-02.md`.
8. Sit the real CKA exam.

### Contributor Path

1. Fork → branch (`fix/...` or `feat/...`).
2. Add or edit content (Markdown for narrative, YAML for skeletons/exercises).
3. Run `bash scripts/validate-local.sh` (`scripts/validate-local.sh:21–36`).
4. Commit with prefix from `CONTRIBUTING.md` (`fix:`, `feat:`, `docs:`, `chore:`).
5. Push → CI runs `.github/workflows/validate.yml` (yamllint + Python YAML syntax over `skeletons/` and `exercises/`).
6. Open PR using `.github/PULL_REQUEST_TEMPLATE.md`.

**State:**
- No persistent state — repo is static content.
- Reader state lives in `README.md`'s "Study Progress Tracker" (manual checklist) and individual learners' clusters.

## Key Abstractions

**Exercise folder:**
- Purpose: One topic, one self-contained lab.
- Examples: `exercises/01-pod-basics/`, `exercises/11-troubleshoot-cluster/`, `exercises/31-argocd-gitops-setup/`
- Pattern: `exercises/NN-kebab-topic/README.md` containing the sections `Tasks` → `Hints` (collapsed) → `What tripped me up` → `Verify` → `Cleanup` → `Solution` (collapsed). Top of file links to a related skeleton and the matching `README.md` domain anchor.

**YAML skeleton:**
- Purpose: Minimal valid Kubernetes manifest, ready to copy-paste-edit.
- Examples: `skeletons/pod.yaml`, `skeletons/deployment.yaml`, `skeletons/networkpolicy.yaml`, `skeletons/gateway-api.yaml`, `skeletons/validatingadmissionpolicy.yaml`
- Pattern: Single resource (or tightly-related pair) per file, opinionated defaults (`nginx:1.27`, `busybox:1.37`, `64Mi`/`100m` requests), inline comments for exam gotchas. Mirrored as a collapsible `<details>` block in `TEMPLATES.md`.

**Mock exam pair:**
- Purpose: Timed simulation under exam-realistic conditions.
- Examples: `mock-exams/MOCK-EXAM-01.md` + `mock-exams/MOCK-EXAM-01-SOLUTIONS.md`
- Pattern: Question file is opened alone; solutions file is opened only after the timer expires. 15 questions, 2 hours, 66% passing line.

**Troubleshooting entry:**
- Purpose: Symptom-first lookup during practice or under exam pressure.
- Examples: `troubleshooting/README.md` sections "Pod is Pending", "Pod is CrashLoopBackOff", "Node is NotReady", "etcd issues".
- Pattern: H2 heading = symptom; first paragraph = personal observation; cause/fix table; diagnostic kubectl block.

## Entry Points

**Reader entry — `README.md`:**
- Location: repo root.
- Triggers: GitHub renders it automatically; learners open it first.
- Responsibilities: Sells the resource, lays out 4-week study plan, indexes every other folder via TOC and inline links, embeds full exam-day reference (cheatsheet excerpts, decision flowchart).

**Practice entry — `scripts/exam-setup.sh`:**
- Location: `scripts/exam-setup.sh`.
- Triggers: `bash scripts/exam-setup.sh` (or sourced).
- Responsibilities: Set `k`/`kn`/`kgp`/etc. aliases, export `$do`/`$now`, enable kubectl bash completion for `k`, append vim YAML config, set `ETCDCTL_API=3`.

**YAML index entry — `TEMPLATES.md`:**
- Location: repo root.
- Triggers: Linked from `README.md`, `skeletons/README.md`, and most exercise files.
- Responsibilities: One-page collapsible browser for all 23 resource templates. Canonical source — `skeletons/*.yaml` files mirror it.

**Contributor entry — `CONTRIBUTING.md`:**
- Location: repo root.
- Triggers: Linked from `README.md` disclaimer and GitHub PR UI.
- Responsibilities: Commit-prefix rules, validation requirement, content boundaries (CKA only, no real exam questions, no AI filler), style guide.

**CI entry — `.github/workflows/validate.yml`:**
- Location: `.github/workflows/validate.yml`.
- Triggers: `push` to `main` and `pull_request` to `main` when paths touch `skeletons/**`, `exercises/**`, or any `*.yaml`/`*.yml`.
- Responsibilities: Run yamllint over `skeletons/` with project ruleset; Python YAML syntax check over `skeletons/*.yaml`.

## Architectural Constraints

- **Markdown-rendered-on-GitHub:** Every collapsible block uses `<details><summary>...</summary>` HTML. Anchors must be valid GitHub-rendered slugs (lowercase, hyphenated). Don't use features that break in plain Markdown viewers.
- **One README per exercise folder:** Convention enforced by every existing exercise. Do not create per-exercise sub-folders for manifests — paste manifests into the README's solution block or reference `skeletons/` and `TEMPLATES.md`.
- **Two sources for YAML:** `TEMPLATES.md` (browsing) and `skeletons/*.yaml` (apply). They must stay in sync. `skeletons/README.md` declares `TEMPLATES.md` canonical (`skeletons/README.md:3`), so changes start in `TEMPLATES.md` and propagate.
- **Question/solution separation for mocks:** Never inline a mock-exam answer inside the question file. The pairing is `MOCK-EXAM-0N.md` + `MOCK-EXAM-0N-SOLUTIONS.md`.
- **Kubernetes version pinning:** Content targets Kubernetes v1.35 (`README.md:5`, `TEMPLATES.md:750`). Don't add v1.34-only flags or dockershim-era references.
- **CKA-only scope:** No CKAD, CKS, KCNA content (`CONTRIBUTING.md:38`).
- **No real exam questions:** CNCF revokes certifications for sharing them — both `CONTRIBUTING.md:35` and `mock-exams/README.md:69` repeat the warning.
- **CI gating files:** `.github/workflows/validate.yml` only triggers on `skeletons/**`, `exercises/**`, and any `*.yaml`/`*.yml`. Markdown-only changes pass without YAML validation; that's intentional.

## Anti-Patterns

### Adding manifests as separate files inside an exercise folder

**What happens:** Contributor creates `exercises/NN-topic/manifests/pod.yaml` alongside the README.
**Why it's wrong:** Breaks the established "one folder, one README" convention every existing exercise follows (see `exercises/01-pod-basics/`, `exercises/27-cni-tigera-install/`). Adds noise and forces the reader to context-switch.
**Do this instead:** Embed the YAML inside the README's `<details><summary>Solution</summary>` block (see `exercises/01-pod-basics/README.md:56–104`). If the YAML is reusable, add it once to `skeletons/` and `TEMPLATES.md` and link from the exercise.

### Drifting `skeletons/*.yaml` and `TEMPLATES.md`

**What happens:** A skeleton is updated (e.g., new image version) but the matching `<details>` block in `TEMPLATES.md` is missed.
**Why it's wrong:** Two sources of truth diverge; readers using `TEMPLATES.md` get stale snippets.
**Do this instead:** Treat `TEMPLATES.md` as canonical (`skeletons/README.md:3`). Update both in the same commit and run `scripts/validate-local.sh` to confirm YAML still parses.

### Hand-writing answers into mock-exam question files

**What happens:** A clarification or answer leaks into `MOCK-EXAM-0N.md`.
**Why it's wrong:** Defeats the timed-simulation purpose. `mock-exams/README.md:9–12` explicitly tells the learner "Do NOT look at solutions until after you finish."
**Do this instead:** All answers and explanations go in `MOCK-EXAM-0N-SOLUTIONS.md`.

### Pasting real CKA exam questions

**What happens:** Contributor lifts wording from a real CKA session into an exercise or mock.
**Why it's wrong:** CNCF policy — certificate revocation. Stated in `CONTRIBUTING.md:35` and `mock-exams/README.md:69`.
**Do this instead:** Write independently-designed scenarios that target the same domain. Topic is fine; wording and screenshots are not.

### Adding emojis to content

**What happens:** Contributor sprinkles emojis through README, exercises, or commit messages.
**Why it's wrong:** Style guide says no emojis (`CONTRIBUTING.md:43`).
**Do this instead:** Keep tone first-person, casual, plain text.

## Error Handling

**Strategy:** Validation-at-the-edges. Markdown is unvalidated; YAML is gated by `scripts/validate-local.sh` (locally) and `.github/workflows/validate.yml` (CI).

**Patterns:**
- Local pre-push: `bash scripts/validate-local.sh` parses every `*.yaml` under `skeletons/` and `exercises/` with `python3 -c "import yaml; yaml.safe_load_all(...)"` and runs yamllint if installed (`scripts/validate-local.sh:27–47`).
- CI: yamllint with relaxed rules (`line-length: 200`, `truthy: disable`, `document-start: disable`) over `skeletons/`, plus the same Python parse loop (`.github/workflows/validate.yml:30–49`).
- Broken-link / dead-anchor handling: none automated. Reported via `.github/ISSUE_TEMPLATE/bug-report.md` or PRs with the `fix:` prefix.

## Cross-Cutting Concerns

**Linking:** Every exercise opens with a "Related" line linking back to the matching `README.md` domain anchor and to a relevant skeleton (e.g., `exercises/01-pod-basics/README.md:3`). This is how the layers stay glued together.

**Voice / tone:** First-person, casual, includes "What tripped me up" sections sharing real exam friction (`exercises/01-pod-basics/README.md:31–35`, `troubleshooting/README.md:14`). New content must match this voice (`CONTRIBUTING.md:42`).

**Discoverability:** `README.md` carries the canonical TOC. `skeletons/README.md` redirects to `TEMPLATES.md`. `troubleshooting/README.md` opens with a "Jump to:" anchor list. `mock-exams/README.md` documents the question/solution protocol.

**Kubernetes version drift:** Content is dated and pinned. The CI badge in `README.md:3` advertises validation; `README.md:5` pins v1.35. When the K8s release moves, image tags in `skeletons/` and `TEMPLATES.md` (e.g., `nginx:1.28`, `busybox:1.37`) and API versions need a coordinated sweep.

---

*Architecture analysis: 2026-05-07*

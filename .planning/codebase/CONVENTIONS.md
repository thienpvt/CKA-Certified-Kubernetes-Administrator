---
title: Conventions
focus: quality
last_mapped: 2026-05-07
---

# Conventions

Repo is YAML + Bash + Markdown only. There is no application source code, so "conventions" here means authoring contracts for exercises, skeletons, manifests, scripts, and Markdown — plus the lint rules that gate them.

## Repository layout (authoring contract)

| Directory | Contains | Authoring rule |
|-----------|----------|----------------|
| `exercises/NN-slug/README.md` | One Markdown file per exercise | Numbered prefix `01`–`31`, kebab-case slug, single `README.md` |
| `skeletons/<resource>.yaml` | Single-resource starter manifests | One kind per file, lowercase resource name |
| `mock-exams/MOCK-EXAM-NN.md` + `MOCK-EXAM-NN-SOLUTIONS.md` | Paired exam + solutions | Question file must NOT reveal answers |
| `scripts/*.sh` | Setup / validation Bash | LF endings, banner comment, `#!/bin/bash` |
| `troubleshooting/README.md` | Symptom-indexed playbook | Anchored "Jump to" index at top |
| `cheatsheet/cka-cheatsheet.md` | Quick-reference dump | Plain Markdown, no exercise structure |
| `TEMPLATES.md` | Master YAML quick reference | Each kind in a `<details>` block |

Naming patterns:
- Exercise folders: `NN-kebab-case` (e.g. `05-networkpolicy`, `25-storage-waitforfirstconsumer`).
- Lab namespace inside YAML: `exercise-NN`. This is load-bearing — `Cleanup` runs `k delete ns exercise-NN` to wipe the lab.
- Skeletons: lowercase singular kind, one file per resource (`pod.yaml`, `pvc.yaml`, `clusterrole.yaml`, `validatingadmissionpolicy.yaml`).

## Exercise README structure (mandatory shape)

Confirmed across the corpus — 31/31 exercises emit ≥4 of these `##` headings; 30/31 emit all five.

```markdown
# Exercise NN — <Title>

> Related: [<skeleton>](../../skeletons/<x>.yaml) | [README — <Domain>](../../README.md#<anchor>)

<one-line problem statement>

## Tasks
1. ...

## Hints
<details>
<summary>Stuck? Click to reveal hints</summary>
- ...
</details>

## What tripped me up
> first-person blockquote, casual, names minutes lost

## Verify
```bash
# kubectl assertion with expected result in a comment
```

## Cleanup
```bash
k delete ns exercise-NN
```

<details>
<summary>Solution</summary>
... full walkthrough ...
</details>
```

Reference implementations: `exercises/01-pod-basics/README.md`, `exercises/04-rbac/README.md`, `exercises/05-networkpolicy/README.md`, `exercises/11-troubleshoot-cluster/README.md`.

Rules embedded in this shape:
- **Hints and Solution always inside `<details>`** so the learner can opt-in. Never paste the solution outside a collapsible.
- **`What tripped me up` is a `>` blockquote, first person, casual, no emoji** (mandated in `CONTRIBUTING.md`: "First person, casual tone — matches the rest of the repo. No emojis").
- **`Verify` uses the `k …` alias** from `scripts/exam-setup.sh` and includes a comment line stating the expected outcome (`# Should return "yes"`, `# worker-1 shows NotReady after ~40 seconds`).
- **`Cleanup` always exists**, even if it just notes nothing needs cleaning (see `exercises/29-troubleshoot-etcd-endpoint/README.md`: "Cluster is now fixed. Nothing to clean up.").
- **Cross-links at the top** use the `> Related:` quoted line with relative `../../skeletons/...` and `../../README.md#anchor` paths.

## Difficulty / time / domain tagging

Authoritative table: `exercises/README.md`. Allowed values:
- **Difficulty:** `Easy` | `Medium` | `Hard` (no other levels).
- **Time:** integer minutes formatted `NN min`.
- **Domain:** must be one of `Troubleshooting (30%)`, `Cluster Architecture (25%)`, `Services & Networking (20%)`, `Workloads & Scheduling (15%)`, `Storage (10%)`, `Security`, `Cluster Maintenance`.

Some exercises also embed an inline tag header (`exercises/16-hpa/README.md` line 3: `> **Medium** | ~15 min | Domain: Workloads & Scheduling (15%)`). When present, it must agree with the table row.

## YAML manifest style

Enforced by `scripts/validate-local.sh` and `.github/workflows/validate.yml` (yamllint + `python3 yaml.safe_load_all`):

```yaml
extends: default
rules:
  line-length: {max: 200}
  truthy: disable
  document-start: disable
  comments-indentation: disable
  indentation: {indent-sequences: whatever}
```

Conventions visible across `skeletons/*.yaml` and exercise solution YAML:
- **2-space indent**; sequences may sit at parent indent or one further (`indent-sequences: whatever`). Match the surrounding file.
- **No leading `---` required**; use `---` only to separate multiple kinds in one file (`skeletons/rbac.yaml`, the StatefulSet+Headless block in `TEMPLATES.md`).
- **`apiVersion` pinned to current Kubernetes 1.35 stable** (per `TEMPLATES.md` Usage Tips):
  - Pods/Services/ConfigMaps/Secrets/PV/PVC/SA/ResourceQuota/LimitRange → `v1`
  - Deployments/StatefulSets/DaemonSets → `apps/v1`
  - Jobs/CronJobs → `batch/v1`
  - NetworkPolicy/Ingress → `networking.k8s.io/v1`
  - HPA → `autoscaling/v2`
  - StorageClass → `storage.k8s.io/v1`
  - RBAC → `rbac.authorization.k8s.io/v1`
  - Gateway / HTTPRoute → `gateway.networking.k8s.io/v1`
  - ValidatingAdmissionPolicy → `admissionregistration.k8s.io/v1`
- **Image pinning:** `nginx:1.27`/`nginx:1.28`, `busybox:1.36`/`busybox:1.37`. Never `:latest`.
- **Resources are baseline shape:** `skeletons/pod.yaml` ships both `requests` and `limits` with an inline rationale comment ("HPA won't work without requests, and OOMKill hits with no warning if you skip limits").
- **Labels mirror the resource name** in skeletons (`name: my-pod` → `labels: {app: my-pod}`); selectors must match exactly (`skeletons/deployment.yaml:11`: `# MUST match template.metadata.labels exactly`).
- **Namespace usage:** skeletons leave `default` (or omit `namespace`); exercise solutions always create `exercise-NN` first and pass `-n exercise-NN` to every command.
- **Memory units quoted strings** (`"64Mi"`); CPU may be quoted millicore (`"250m"`) or unquoted integer (`"4"`).
- **Inline gotcha comments encouraged:** `skeletons/networkpolicy.yaml` carries `# WARNING: these two selectors in the SAME from block = AND` and `# NEVER forget DNS egress`; `skeletons/rbac.yaml` carries `# Gotcha: create the ServiceAccount BEFORE the RoleBinding`. Adding more is the preferred way to encode failure modes.

## Bash / shell script style

Two scripts ship: `scripts/exam-setup.sh` (sourced helper) and `scripts/validate-local.sh` (CI-style YAML check).

- `#!/bin/bash` shebang on line 1.
- LF line endings only (`.gitattributes`: `*.sh text eol=lf`).
- Top-of-file banner comment with purpose + source URL (`scripts/exam-setup.sh:1-4`, `scripts/validate-local.sh:1-3`).
- `set -euo pipefail` on validation/CI scripts (`scripts/validate-local.sh:6`). Setup script that gets `source`d does NOT use `set -e` because it would abort the parent shell.
- ANSI color variables (`RED`, `GREEN`, `YELLOW`, `NC`) declared at the top, used through `echo -e` (`scripts/validate-local.sh:8-11`).
- `REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"` is the canonical "find repo root from `scripts/`" idiom.
- Quote everywhere; prefer `find ... -print0` + `while IFS= read -r -d ''` for filename safety (`scripts/validate-local.sh:27-35`).
- Explicit `exit 0` / `exit 1` at the end of validation scripts.
- **Aliases for the learner** (`scripts/exam-setup.sh:7-22`) are part of the public contract — exercises assume `k`, `kn`, `kgp`, `kgs`, `kgn`, `kd`, `kaf`, `kdel`, `$do` (`--dry-run=client -o yaml`), `$now` (`--force --grace-period=0`). Don't rename without sweeping every exercise.
- `ssh <node>` lines stand in for "do this on the node" (exercises 11, 18, 26, 29, 30). Not literally runnable; learner substitutes their node hostname.

## Markdown style

- `#` for the page title; `##` for the canonical sections (`Tasks`, `Hints`, `What tripped me up`, `Verify`, `Cleanup`); `###` for sub-scenarios inside a section (e.g. `### Scenario A: Broken kubelet` in exercise 11, `### Verify CNI is running` in exercise 5).
- **All fenced code blocks declare a language** (`bash`, `yaml`, or `text`). Never bare ` ``` `.
- Tables are GitHub-flavoured pipes with header separator (`| --- |`); used for the difficulty table, exit-code tables in `troubleshooting/README.md`, and cause/fix tables.
- `<details><summary>...</summary>` is the only collapsible mechanism — Hints, Solutions, and per-resource entries in `TEMPLATES.md`. Blank line between `<summary>` and content, and before `</details>`.
- Cross-links use relative paths, never absolute repo URLs.
- Tone: first person, casual, owns mistakes, names minutes lost. No emojis.
- `>` blockquotes reserved for the `Related:` link line and the `What tripped me up` narrative.

## Edge-case / failure-mode authoring

The repo deliberately encodes failure modes — that is its pedagogical core. When adding new content:
- Put the war story in `What tripped me up` (DNS egress missed, `--as=` format wrong, wrong namespace, OOMKilled exit 137, etc.). Hints point at the right command; "tripped me up" tells the story.
- Bake field-level gotchas into YAML as comments (see `skeletons/networkpolicy.yaml` AND/OR comment, `skeletons/deployment.yaml` selector match comment, `skeletons/pod.yaml` resources rationale).
- Cause/fix tables use real exit codes and real commands (`troubleshooting/README.md` exit-code table maps `137 → OOMKilled → increase memory limit`).
- Static-pod / control-plane fixes must instruct editing in place under `/etc/kubernetes/manifests/`, never via `kubectl apply` (`exercises/29-troubleshoot-etcd-endpoint/README.md` "What tripped me up").

## Commit conventions (`CONTRIBUTING.md`)

- `fix:` — broken command, bad YAML, typo, dead link
- `feat:` — new exercise, skeleton, troubleshooting scenario
- `docs:` — README edits, comments, wording changes
- `chore:` — CI, tooling, repo housekeeping

Recent history confirms (`5500f29 docs:`, `07e17f1 feat:`, `3634dc8 chore:`).

## Where to add new content

| New thing | Goes here | Also update |
|-----------|-----------|-------------|
| New exercise | `exercises/NN-kebab-slug/README.md` (next free `NN`) | Row in `exercises/README.md` table; domain bucket footer; flagship cross-link in root `README.md` |
| New YAML skeleton | `skeletons/<resource>.yaml` | Collapsible block in `TEMPLATES.md`; `> Related:` link from any exercise that uses it |
| New troubleshooting scenario | New `## ...` section in `troubleshooting/README.md` | Add anchor to "Jump to" index at the top |
| New mock-exam question | Append to `mock-exams/MOCK-EXAM-NN.md` AND add matching `## Solution N:` in `MOCK-EXAM-NN-SOLUTIONS.md` | Update question count / focus in `mock-exams/README.md` |
| New helper script | `scripts/<name>.sh` (LF, banner, `#!/bin/bash`) | Mention in `CONTRIBUTING.md` "Local Validation"; wire into `.github/workflows/validate.yml` if pre-merge |

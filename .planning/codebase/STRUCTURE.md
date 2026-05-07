---
title: Structure
focus: arch
last_mapped: 2026-05-07
---

# Structure

Directory layout, naming conventions, and entry points for a CKA study/exercise repository. Pure content (Markdown + YAML + Bash) — no application source.

## Top-level layout

| Path | Purpose |
|------|---------|
| `README.md` | Master entry point — curriculum overview, embedded cheat sheet, troubleshooting flowchart, install snippets (3,889 lines). |
| `TEMPLATES.md` | Browse-friendly YAML quick reference; one collapsible `<details>` block per kind. Companion to `skeletons/`. |
| `CHANGELOG.md` | Versioned release notes (Keep a Changelog format). |
| `CONTRIBUTING.md` | PR workflow, exercise authoring rules, commit conventions, local validation step. |
| `CODE_OF_CONDUCT.md` | Community standards. |
| `SECURITY.md` | Disclosure policy + the "not real exam content" disclaimer. |
| `LICENSE` | License text. |
| `.gitattributes` | Forces LF line endings on `*.sh`. |
| `assets/` | Static images (`cka.png` repo banner). |
| `cheatsheet/` | Standalone kubectl quick-reference. |
| `exercises/` | 31 numbered hands-on labs — the heart of the repo. |
| `skeletons/` | 23 single-resource YAML starter manifests. |
| `mock-exams/` | Two timed practice exams + paired solution files. |
| `scripts/` | Two Bash helpers: setup and YAML lint. |
| `troubleshooting/` | Symptom-indexed playbook. |
| `.github/` | Issue templates, PR template, CI workflow. |

## `exercises/` — 31 labs, one folder each

Every exercise is a single `README.md` inside `exercises/NN-kebab-slug/`. There are no per-exercise YAML files — solution YAML lives inline as fenced ` ```yaml ` blocks inside the README.

```
exercises/
├── README.md                          ← index + difficulty/time/domain table
├── 01-pod-basics/README.md
├── 02-multi-container-pod/README.md
├── 03-configmap-secret/README.md
├── 04-rbac/README.md
├── 05-networkpolicy/README.md
├── 06-deployment-rollout/README.md
├── 07-statefulset/README.md
├── 08-node-drain-cordon/README.md
├── 09-kubeadm-upgrade/README.md
├── 10-static-pod/README.md
├── 11-troubleshoot-cluster/README.md
├── 12-storage-pv-pvc/README.md
├── 13-helm-install-upgrade/README.md
├── 14-kustomize-overlays/README.md
├── 15-gateway-api/README.md
├── 16-hpa/README.md
├── 17-kubectl-debug/README.md
├── 18-cri-dockerd-setup/README.md
├── 19-ingress-classic/README.md
├── 20-pod-security-standards/README.md
├── 21-jobs-cronjobs/README.md
├── 22-priorityclass/README.md
├── 23-resource-requests-tuning/README.md
├── 24-priorityclass-patch/README.md
├── 25-storage-waitforfirstconsumer/README.md
├── 26-cri-dockerd-setup/README.md     ← duplicate slug with ex-18 (see CONCERNS.md)
├── 27-cni-tigera-install/README.md
├── 28-network-policy-complex/README.md
├── 29-troubleshoot-etcd-endpoint/README.md
├── 30-tls-configuration-update/README.md
└── 31-argocd-gitops-setup/README.md
```

**Folder naming:** `NN-kebab-case-slug`, where `NN` is a zero-padded sequential integer and the slug describes the topic. Numbers do not group by domain — domain grouping lives in the table at the bottom of `exercises/README.md`.

**Per-exercise file pattern:** every exercise folder contains exactly one file, `README.md`. Section structure is mandatory and identical across all 31 — see `CONVENTIONS.md` for the full template (Tasks → Hints → What tripped me up → Verify → Cleanup → Solution).

**Lab-namespace convention:** every exercise creates and tears down a namespace named `exercise-NN`. That string is the load-bearing isolation boundary — `Cleanup` blocks invariably contain `k delete ns exercise-NN`.

## `skeletons/` — 23 starter manifests

One Kubernetes resource per file, lowercase singular, no namespace pinned.

```
skeletons/
├── README.md                       ← orientation + relationship to TEMPLATES.md
├── clusterrole.yaml
├── configmap-secret.yaml           ← combo file (ConfigMap + Secret in one doc)
├── cronjob.yaml
├── daemonset.yaml
├── deployment.yaml
├── gateway-api.yaml                ← Gateway + HTTPRoute
├── hpa.yaml
├── ingress.yaml
├── job.yaml
├── limitrange.yaml
├── networkpolicy.yaml
├── pod.yaml
├── pv.yaml
├── pvc.yaml
├── rbac.yaml                       ← Role + RoleBinding + ServiceAccount
├── resourcequota.yaml
├── securitycontext.yaml
├── service.yaml
├── serviceaccount.yaml
├── sidecar-init-container.yaml     ← native sidecar pattern (restartPolicy: Always)
├── statefulset.yaml
├── storageclass.yaml
└── validatingadmissionpolicy.yaml
```

Skeletons embed inline gotcha comments (e.g. `networkpolicy.yaml`'s "AND vs OR" warning, `deployment.yaml`'s selector-match callout). They are the only standalone YAML files in the repo and the only files validated by CI.

## `mock-exams/` — paired exam + solution markdown

```
mock-exams/
├── README.md                        ← run protocol, scoring rubric
├── MOCK-EXAM-01.md                  ← 15 questions, 2-hour timer, no answers
├── MOCK-EXAM-01-SOLUTIONS.md        ← solutions + "Key insight" commentary
├── MOCK-EXAM-02.md
└── MOCK-EXAM-02-SOLUTIONS.md
```

**Pairing convention:** `MOCK-EXAM-NN.md` (questions only) **must** have a sibling `MOCK-EXAM-NN-SOLUTIONS.md`. The question file must not reveal answers. Inside both files, sections are `## Question N: <Title>` / `## Solution N: <Title>`.

## `troubleshooting/` — single playbook file

```
troubleshooting/
└── README.md                        ← symptom → cause → fix lookup, anchored "Jump to" index
```

Each section is a `## Symptom` heading with a cause/fix table and diagnostic command block. The "Jump to" anchor list at the top is the navigation surface.

## `cheatsheet/` — single quick-reference file

```
cheatsheet/
└── cka-cheatsheet.md
```

Plain Markdown dump of `kubectl` patterns, kubeadm install snippets, etcd commands, and exam-tempo tips. Intended to be read straight through.

## `scripts/` — two Bash helpers

```
scripts/
├── exam-setup.sh                    ← MUST be sourced; sets aliases (k, kn, kgp, …), $do, $now, vimrc, completions
└── validate-local.sh                ← walks skeletons/+exercises/ for *.yaml, runs python yaml.safe_load_all + optional yamllint
```

Both files use `#!/bin/bash`, LF line endings (`.gitattributes`), banner comments, and ANSI color helpers. `validate-local.sh` is the local mirror of CI; `exam-setup.sh` is the practice-session preflight.

## `assets/`

```
assets/
└── cka.png                          ← repo banner referenced from README.md
```

## `.github/`

```
.github/
├── PULL_REQUEST_TEMPLATE.md         ← required PR checklist
├── ISSUE_TEMPLATE/
│   ├── bug-report.md
│   ├── config.yml
│   ├── content-request.md
│   └── exam-feedback.md
└── workflows/
    └── validate.yml                 ← yamllint job; triggers on push/PR to main when YAML changes
```

CI is YAML-only — Markdown changes (the bulk of the repo) skip CI. See `CONCERNS.md` for the implications.

## Naming conventions (cross-cutting)

| Surface | Pattern | Example |
|---------|---------|---------|
| Exercise folder | `NN-kebab-case` | `25-storage-waitforfirstconsumer/` |
| Exercise namespace | `exercise-NN` | `exercise-25` |
| Skeleton file | `<lowercase-singular-kind>.yaml` | `validatingadmissionpolicy.yaml` |
| Mock-exam pair | `MOCK-EXAM-NN.md` + `MOCK-EXAM-NN-SOLUTIONS.md` | `MOCK-EXAM-02.md` |
| Lab image pin | `<image>:<minor>` (no `latest`) | `nginx:1.27`, `busybox:1.36` |
| Commit prefix | `fix:`/`feat:`/`docs:`/`chore:` | `feat: add exercise 31 — Argo CD GitOps setup` |

## Key entry points

**For a learner starting fresh:**
1. `README.md` — read the curriculum overview and v1.35 syllabus mapping.
2. `cheatsheet/cka-cheatsheet.md` — keep open in a tab during practice.
3. `scripts/exam-setup.sh` — `source` it before each session.
4. `exercises/README.md` — pick by domain/difficulty.
5. `mock-exams/README.md` — when ready to self-test.
6. `troubleshooting/README.md` — when verification fails.

**For a contributor:**
1. `CONTRIBUTING.md` — workflow, commit conventions, local validation step.
2. `TEMPLATES.md` — copy the right kind, paste into a new exercise.
3. `skeletons/<kind>.yaml` — single-file equivalent for `> Related:` cross-links.
4. `exercises/README.md` — claim the next free `NN`, add a row to the table.
5. `scripts/validate-local.sh` — run before pushing.
6. `.github/workflows/validate.yml` — CI mirror of `validate-local.sh`.
7. `.github/PULL_REQUEST_TEMPLATE.md` — required PR checklist.

**For a maintainer:**
- `CHANGELOG.md` — bump on release.
- `CONCERNS.md` (this folder) — running list of accuracy/coverage debt to burn down.

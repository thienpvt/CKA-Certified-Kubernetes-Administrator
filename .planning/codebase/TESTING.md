---
title: Testing
focus: quality
last_mapped: 2026-05-07
---

# Testing (verification approach)

## No traditional test framework

**There is no unit-test or integration-test framework in this repo.** No `pytest`, `jest`, `go test`, `bats`, etc. The only automated check is YAML syntax/lint, run by `scripts/validate-local.sh` locally and `.github/workflows/validate.yml` in CI.

"Testing" in this codebase means three distinct activities:
1. **YAML validation** — does the manifest parse and lint?
2. **Per-exercise self-verification** — does the learner's solution produce the expected `kubectl` output?
3. **Mock-exam self-test** — can the learner clear 10/15 in 2 hours unaided?

Each is described below.

## 1. YAML validation (the only automated check)

**Local script:** `scripts/validate-local.sh`

```bash
bash scripts/validate-local.sh
```

What it does:
- Walks `skeletons/` and `exercises/` for `*.yaml` files (`scripts/validate-local.sh:21-36`).
- Runs `python3 -c "import yaml, sys; list(yaml.safe_load_all(open('$f')))"` on each — confirms the file parses as one or more YAML documents (multi-doc files separated by `---` are supported).
- Optionally runs `yamllint` if installed, with this relaxed config:

  ```
  extends: default
  rules:
    line-length: {max: 200}
    truthy: disable
    document-start: disable
    comments-indentation: disable
    indentation: {indent-sequences: whatever}
  ```

- Prints `OK`/`FAIL` per file with ANSI colors; `exit 1` on any failure.

**CI workflow:** `.github/workflows/validate.yml` (job `yamllint`)
- Triggers on push/PR to `main` when paths under `skeletons/**`, `exercises/**`, `**.yaml`, `**.yml` change.
- Installs `yamllint` via pip, runs the same yamllint config above, then runs the same Python YAML parse check on `skeletons/*.yaml`.
- Adds `new-lines: {type: platform}` to the yamllint config in CI.

**Pre-push contract:** `CONTRIBUTING.md` step 4 — "Run `bash scripts/validate-local.sh` to lint any YAML you added".

**Coverage:** validation only checks `skeletons/` and (locally) `exercises/`. Mock exams, troubleshooting, and cheatsheet are Markdown-only and not validated. There is no link checker, no spell checker, no kubectl dry-run validation in CI.

## 2. Per-exercise self-verification (the `## Verify` contract)

Every exercise contains a `## Verify` section with a fenced `bash` code block. This is the canonical learner self-test and is the closest analog to a test suite.

Pattern (`exercises/01-pod-basics/README.md:39-48`):

```bash
# Pod should be Running
k get pod web -n exercise-01

# Should show app=web,version=v1
k get pod web -n exercise-01 --show-labels

# Should show IP
k get pod web -n exercise-01 -o wide
```

Conventions inside `## Verify`:
- **`k …` alias** assumed (sourced from `scripts/exam-setup.sh`).
- **Each command is preceded by a comment stating the expected outcome** (`# Should return "yes"`, `# worker-1 shows NotReady after ~40 seconds`, `# Should show app=web,version=v1`). The comment IS the assertion — there is no script that diffs actual against expected.
- **Connectivity tests use `k exec ... -- curl -m2 http://$IP`** with a 2-second timeout (`exercises/05-networkpolicy/README.md:42-48`). The expected outcome ("should work" / "should time out") is in a comment.
- **RBAC tests use `k auth can-i` with the full `--as=system:serviceaccount:<ns>:<sa>` form** (`exercises/04-rbac/README.md:50-71`). Expected `yes`/`no` is commented.
- **DNS tests use `k run test-dns --image=busybox:1.36 --rm -it -- nslookup ...`** (`exercises/11-troubleshoot-cluster/README.md:72`).
- **Audit-log assertions pipe `jq` over `/var/log/audit/audit.log`** (exercise 11 Scenario D).
- **Cluster-health assertions are `k get nodes`, `k get pods -A`, `k api-resources`** (`exercises/29-troubleshoot-etcd-endpoint/README.md:58-61`).
- **Storage persistence is verified by killing and recreating the pod, then `k exec ... -- cat <file>`** (`exercises/12-storage-pv-pvc/README.md:54-55`).

**Cleanup is paired with Verify** — every exercise ends with `## Cleanup` containing the inverse `kubectl delete` commands so the cluster returns to a clean state before the next exercise. The dominant pattern is `k delete ns exercise-NN`, with extra deletes for cluster-scoped resources (e.g. `k delete clusterrole node-viewer` in exercise 04, `k delete pv my-pv` in exercise 12).

## 3. Mock-exam self-test (integration verification)

Mock exams are the only end-to-end "test suite" in the repo. They live in `mock-exams/`:

| File | Role |
|------|------|
| `mock-exams/MOCK-EXAM-01.md` | 15 questions, 2-hour timer, no answers visible |
| `mock-exams/MOCK-EXAM-01-SOLUTIONS.md` | Per-question solution + "Key insight" commentary |
| `mock-exams/MOCK-EXAM-02.md` | Different scenario set, same shape |
| `mock-exams/MOCK-EXAM-02-SOLUTIONS.md` | Solutions for exam 02 |
| `mock-exams/README.md` | Run rules, scoring rubric |

Question structure (`MOCK-EXAM-01.md`):
- `## Question N: <Title>`
- 1–4 line scenario context
- Numbered task list (1, 2, 3, ...)
- `**Time: N minutes**` budget for that question

Solution structure (`MOCK-EXAM-01-SOLUTIONS.md`):
- `## Solution N: <Title>`
- Imperative `kubectl` commands or YAML
- `Verify:` block with kubectl checks
- `**Key insight:** ...` paragraph teaching the underlying concept

Run protocol (`mock-exams/README.md`):
1. Read ONLY the question file.
2. Set a 2-hour timer.
3. Solve in your own cluster.
4. Don't peek at solutions until done.
5. Score: 10/15 = pass (66%), 12/15 = strong, 15/15 = exam-ready.
6. Both exams 12+/15 → ready for the real CKA.

Real-exam tip surface (`mock-exams/README.md` "Tips for Mock Exam Success"):
- Use imperative commands, not YAML from memory.
- Always verify with `kubectl get`/`describe`/`logs` after each task.
- Call `kubectl` not `k` (real exam only allows `k`).
- Allocate 7–8 min/question.
- Flag and skip if a question takes >10 min.

## CKA exam-objective coverage

The repo explicitly maps to the seven CKA domains. The matrix lives at the bottom of `exercises/README.md`:

| Domain | Weight | Exercises |
|--------|--------|-----------|
| Troubleshooting | 30% | 11, 17, 29 |
| Cluster Architecture | 25% | 04, 08, 09, 13, 14, 18, 20, 26, 31 |
| Services & Networking | 20% | 05, 15, 19, 27, 28 |
| Workloads & Scheduling | 15% | 01, 02, 03, 06, 07, 10, 16, 21, 22, 23, 24 |
| Storage | 10% | 12, 25 |
| Security | — | 30 |
| Cluster Maintenance | — | (referenced from `troubleshooting/README.md` and exercise 29) |

When adding an exercise, place it in the right domain bucket; the count per bucket should remain proportional to the weight column.

## Setup script as preflight check

`scripts/exam-setup.sh` is part of the verification surface. Sourcing it at the start of every practice session:
1. Defines aliases the exercises depend on (`k`, `kn`, `kgp`, `kgs`, `kgn`, `kd`, `kaf`, `kdel`).
2. Exports `$do` (`--dry-run=client -o yaml`) and `$now` (`--force --grace-period=0`).
3. Loads `kubectl completion bash` and binds it to `k`.
4. Writes a 5-line `~/.vimrc` (2-space tabs, expandtab, line numbers, autoindent) — required for fast YAML editing during the exam.
5. Sets `ETCDCTL_API=3`.
6. Runs `k get nodes` as a smoke test confirming the cluster is reachable before the learner starts.

If `k get nodes` at the bottom of `exam-setup.sh` fails, the learner knows their cluster is broken before they sink time into an exercise.

## Symptom-indexed troubleshooting playbook

`troubleshooting/README.md` is the "if your verification fails, look here" surface. It is structured as a symptom → cause → fix lookup with a "Jump to" anchor index at the top. Sections include:

- Pod is Pending / CrashLoopBackOff / ImagePullBackOff
- Node is NotReady
- Service Has No Endpoints / Service reachable but wrong response
- DNS not resolving
- NetworkPolicy blocking traffic
- etcd issues
- Control plane down
- Helm release stuck or failed
- Gateway API misconfigured
- Native sidecar not starting
- kubectl debug not working
- CSI volume mount failure
- Kustomize apply not working
- Quick diagnostic commands

Each section uses a cause/fix table plus a code block of diagnostic commands, with first-person `>` blockquotes encoding war stories (e.g. exit 137 → OOMKilled, kubelet log on the broken node not the control plane).

## Verification gaps (where there is no automated check)

- **No kubectl dry-run / server-side validation in CI.** Manifests are only YAML-parsed; `apiVersion`/`kind`/field correctness is not verified against a Kubernetes schema.
- **No Markdown link checker.** The `> Related:` cross-links and `[skeleton](../../skeletons/x.yaml)` references can rot silently.
- **No exercise-driven cluster runner.** Solutions are not executed against a real or kind cluster in CI; correctness depends on the contributor having actually run the commands (`CONTRIBUTING.md` step 5: "Test any commands on Kubernetes v1.35 — if you haven't actually run the command, don't submit it").
- **No mock-exam grader.** Scoring is manual; the learner self-grades against `MOCK-EXAM-NN-SOLUTIONS.md`.
- **No spelling / prose linter.** Markdown is hand-curated; the casual first-person voice is enforced socially via PR review.

## Where to add new "tests"

| Verification need | Add it here |
|-------------------|-------------|
| New per-exercise check | A line in that exercise's `## Verify` block, with a `# expected outcome` comment |
| New manifest schema check | Extend `scripts/validate-local.sh` (e.g. add `kubectl --dry-run=server`); mirror in `.github/workflows/validate.yml` |
| New troubleshooting symptom | New `## <Symptom>` section in `troubleshooting/README.md` plus an entry in the "Jump to" anchor index |
| New end-to-end scenario | A new question + solution pair in the next available `mock-exams/MOCK-EXAM-NN.md` slot |
| New domain coverage gap | Cross-check the domain table in `exercises/README.md`; add an exercise to the under-weighted domain |

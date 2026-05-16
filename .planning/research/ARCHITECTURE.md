# Architecture Research

**Domain:** CKA exam simulator — bash-only runner for an existing 1+2 kubeadm cluster
**Researched:** 2026-05-07
**Verified against v1.0 milestone scope on 2026-05-07** — 1+2 GCP cluster pre-existing, triplet runtime, cka-sim bin/lib split, 5 domain packs + 2 mock-exam packs composed by reference. Build order (18 steps) still valid.
**Confidence:** HIGH for structure / data-flow / build order (constraints in PROJECT.md are explicit and tight); MEDIUM on bootstrap's pubkey-distribution mechanism (two viable paths, recommended one below)

## Standard Architecture

### System Overview

```
┌────────────────────────────────────────────────────────────────────────────┐
│                       Learner (single user, on CP node)                    │
└──────────────────────────────────┬─────────────────────────────────────────┘
                                   │  invokes
                                   ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                       Runner CLI Layer  (cka-sim/bin/)                     │
│  ┌──────────────┐                                                          │
│  │  cka-sim     │  single dispatcher entrypoint, on $PATH                  │
│  │  (router)    │  parses argv → dispatches subcommand                    │
│  └──────┬───────┘                                                          │
│         │                                                                   │
│  ┌──────┴────────┬───────────┬──────────┬──────────┬──────────┐           │
│  ▼               ▼           ▼          ▼          ▼          ▼           │
│ bootstrap      drill        exam      score      list      version        │
│ (cmd module)   (cmd)        (cmd)     (cmd)      (cmd)     (cmd)          │
└────┬─────────────┬───────────┬──────────┬──────────┬──────────────────────┘
     │             │           │          │          │
     │             │           │          │          │ reads
     │             ▼           ▼          ▼          ▼
     │       ┌──────────────────────────────────────────────────┐
     │       │            Library Layer (cka-sim/lib/)          │
     │       │  schema.sh   loader.sh   runner.sh   timer.sh    │
     │       │  traps.sh    grade.sh    score.sh    report.sh   │
     │       │  state.sh    log.sh      preflight.sh            │
     │       └────────────┬─────────────────────────────────────┘
     │                    │ orchestrates
     │                    ▼
     │       ┌──────────────────────────────────────────────────┐
     │       │            Content Layer (read-only data)        │
     │       │  packs/storage/      packs/networking/  ...      │
     │       │   ├ manifest.yaml    (pack metadata + Q list)    │
     │       │   └ NN-slug/                                     │
     │       │       ├ metadata.yaml  (id, weight, time, traps) │
     │       │       ├ question.md    (candidate-facing prompt) │
     │       │       ├ setup.sh       (idempotent precondition) │
     │       │       ├ grade.sh       (kubectl checks + traps)  │
     │       │       └ reset.sh       (cleanup to baseline)     │
     │       │                                                  │
     │       │  exams/blueprint-A/manifest.yaml  (17×Q refs)    │
     │       │  exams/blueprint-B/manifest.yaml                 │
     │       └────────────┬─────────────────────────────────────┘
     │                    │ executes against
     ▼                    ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                Cluster + Local State (the side-effect surface)             │
│  ┌─────────────────────────┐    ┌──────────────────────────────────────┐   │
│  │   Kubernetes cluster    │    │   ~/.cka-sim/                        │   │
│  │   CP + node-01 node-02  │    │   ├ sessions/<ts>.json (live exam)   │   │
│  │   (kubectl, etcdctl,    │◀──▶│   ├ history/<ts>.json (completed)    │   │
│  │    ssh node-NN, crictl) │    │   ├ reports/<ts>.md   (Markdown)     │   │
│  └─────────────────────────┘    │   └ logs/<ts>.log     (debug trail)  │   │
│                                 └──────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| `cka-sim` (router) | Parse argv, dispatch subcommand, surface `--help`, exit codes | Single bash file in `cka-sim/bin/` |
| `bootstrap` cmd | One-time/idempotent prep of the existing cluster (SSH, aliases, env, deps) | `cka-sim/lib/cmd/bootstrap.sh` |
| `drill` cmd | Pick one (or N) questions from a domain pack, run setup → wait → grade | `cka-sim/lib/cmd/drill.sh` |
| `exam` cmd | Run a 17-question/2-hour timed exam, manage skip/flag/return, batch-grade at end | `cka-sim/lib/cmd/exam.sh` |
| `score` cmd | Re-display a past report; aggregate trap frequencies across history | `cka-sim/lib/cmd/score.sh` |
| `list` cmd | Show available packs, exam blueprints, completed sessions | `cka-sim/lib/cmd/list.sh` |
| `schema.sh` | Validate pack/exam/question YAML against an inline schema (yq-driven) | Library |
| `loader.sh` | Resolve pack/exam ids → absolute paths to question dirs | Library |
| `runner.sh` | Per-question lifecycle: source setup, prompt, source grade, capture result | Library |
| `timer.sh` | 2-hour countdown, `SIGUSR1` warnings, `Ctrl-C` trap → save state | Library |
| `traps.sh` | Shared trap-detection helpers reused by every `grade.sh` | Library |
| `grade.sh` (lib) | Common assertion helpers (`assert_resource_exists`, `assert_label_eq`, etc.) | Library |
| `score.sh` | Aggregate per-question results → 100-point total + per-domain percentages | Library |
| `report.sh` | Render JSON session → Markdown report | Library |
| `state.sh` | Read/write `~/.cka-sim/sessions/<ts>.json` with `flock` | Library |
| `preflight.sh` | Verify `kubectl get nodes`, `ssh node-01 true`, required binaries | Library |
| Per-question `setup.sh` | Create namespace, broken state, fixtures — idempotent | Per question |
| Per-question `grade.sh` | Source `lib/traps.sh` + `lib/grade.sh`, run checks, emit pass/fail + trap codes | Per question |
| Per-question `reset.sh` | `kubectl delete ns exercise-<id>` + any node-side cleanup over `ssh` | Per question |
| Pack `manifest.yaml` | Domain id, weight, list of question slugs, trap catalogue id | YAML data |
| Exam `manifest.yaml` | Blueprint name, time limit, ordered list of `pack/<slug>` references | YAML data |
| `~/.cka-sim/` | Per-user state, history, reports, logs (NOT in repo) | Filesystem |

## Recommended Project Structure

```
<repo-root>/
├── README.md                      # gets a "Use cka-sim/ for the simulator" banner up top
├── TEMPLATES.md                   # untouched, still canonical YAML quick-reference
├── CONTRIBUTING.md                # gains a "Authoring exam-sim questions" section
├── CHANGELOG.md
├── scripts/
│   ├── exam-setup.sh              # untouched (sourced by cka-sim/lib/cmd/bootstrap.sh)
│   └── validate-local.sh          # extended to also lint cka-sim/**/*.yaml + shellcheck *.sh
│
├── cka-sim/                       # NEW — the simulator subtree (everything additive)
│   ├── README.md                  # quickstart: bootstrap, drill, exam
│   ├── AUTHORING.md               # how to add a new question / pack / blueprint
│   ├── SCHEMA.md                  # canonical reference for metadata.yaml + manifest.yaml
│   │
│   ├── bin/
│   │   └── cka-sim                # router; only file the user invokes
│   │
│   ├── lib/
│   │   ├── cmd/
│   │   │   ├── bootstrap.sh       # subcommand: bootstrap
│   │   │   ├── drill.sh           # subcommand: drill <pack> [N]
│   │   │   ├── exam.sh            # subcommand: exam <blueprint>
│   │   │   ├── score.sh           # subcommand: score [<session>]
│   │   │   ├── list.sh            # subcommand: list packs|exams|history
│   │   │   └── version.sh
│   │   ├── schema.sh              # YAML schema validation (yq)
│   │   ├── loader.sh              # pack/exam discovery + path resolution
│   │   ├── runner.sh              # setup → wait → grade lifecycle
│   │   ├── timer.sh               # countdown, signals, Ctrl-C trap
│   │   ├── traps.sh               # SHARED trap-detection helpers (the differentiator)
│   │   ├── grade.sh               # SHARED assertion helpers (assert_*)
│   │   ├── score.sh               # weighted score aggregation
│   │   ├── report.sh              # Markdown rendering
│   │   ├── state.sh               # session JSON r/w with flock
│   │   ├── preflight.sh           # cluster + binaries readiness check
│   │   ├── log.sh                 # leveled logging, ANSI colors (matches existing style)
│   │   └── colors.sh              # RED/GREEN/YELLOW/NC (mirrors scripts/validate-local.sh)
│   │
│   ├── packs/                     # domain packs — drillable units
│   │   ├── storage/               # CKA Storage 10%
│   │   │   ├── manifest.yaml
│   │   │   ├── 01-pvc-pending-waitforfirstconsumer/
│   │   │   │   ├── metadata.yaml
│   │   │   │   ├── question.md
│   │   │   │   ├── setup.sh
│   │   │   │   ├── grade.sh
│   │   │   │   └── reset.sh
│   │   │   ├── 02-hostpath-nodeaffinity-missing/
│   │   │   └── ...
│   │   ├── troubleshooting/       # CKA Troubleshooting 30%
│   │   ├── workloads-scheduling/  # CKA Workloads & Scheduling 15%
│   │   ├── cluster-architecture/  # CKA Cluster Architecture 25%
│   │   └── services-networking/   # CKA Services & Networking 20%
│   │
│   ├── exams/                     # mock exams — composed from packs, never duplicated
│   │   ├── blueprint-alpha/
│   │   │   └── manifest.yaml      # ordered refs: storage/01, troubleshooting/04, ...
│   │   ├── blueprint-bravo/
│   │   └── blueprint-charlie/
│   │
│   ├── traps/
│   │   ├── catalog.yaml           # canonical trap registry (id → name → description)
│   │   └── README.md              # author guide for adding new traps
│   │
│   └── tests/                     # smoke tests for the runner itself
│       ├── test-router.sh
│       ├── test-schema.sh
│       └── test-trap-detection.sh
│
├── exercises/                     # KEPT — banner added (see "Coexistence" below)
│   └── ...                        # 31 existing folders untouched
├── skeletons/                     # KEPT, harvested as fixtures by some setup.sh scripts
├── mock-exams/                    # KEPT — banner added
├── cheatsheet/                    # KEPT — referenced by exam blueprint preflight
├── troubleshooting/               # KEPT — referenced from question.md hint sections
│
└── .github/workflows/
    └── validate.yml               # extended: yamllint cka-sim/**/*.yaml + shellcheck cka-sim/**/*.sh
```

### Structure Rationale

- **`cka-sim/` as a single new top-level dir:** Total isolation from the existing study-guide tree. No file under `exercises/`, `skeletons/`, `mock-exams/`, `cheatsheet/`, `troubleshooting/` is moved or renamed; only their `README.md` files gain a banner. Reverting the simulator means `rm -rf cka-sim/` plus dropping the banners — zero entanglement.
- **`bin/` vs `lib/`:** Mirrors POSIX convention. `bin/cka-sim` is the only thing meant to be on `$PATH`; `lib/` contains dot-sourced bash modules. Subcommands are fully isolated bash files in `lib/cmd/` so adding `cka-sim foo` is a one-file change.
- **`packs/<domain>/NN-slug/` directory-of-files (NOT one big YAML):** `metadata.yaml` is small and structured (great for yq); `question.md` is candidate-facing prose (great as Markdown); `setup.sh`/`grade.sh`/`reset.sh` are executable bash. Mixing these inside one YAML file would force base64 / heredoc gymnastics and would be unreadable. The directory-of-files form is also what kubernetes-the-hard-way and killercoda use, and it lets `shellcheck`/`yamllint` lint each file natively.
- **`exams/` separate from `packs/`:** An exam blueprint is metadata only — it references questions by `pack/slug` id. Composition not duplication (see Data Flow below). This is the same pattern Kubernetes uses for kustomize bases vs overlays.
- **`traps/catalog.yaml` central, helpers in `lib/traps.sh`:** Trap *identity* (id + name + description + remediation pointer) is data, in YAML; trap *detection logic* is bash, in `lib/traps.sh`. Each `grade.sh` sources `lib/traps.sh` and emits trap ids; the report renderer joins ids back to names from `catalog.yaml`. This decouples "what traps exist" from "how we detect them in question N".
- **`~/.cka-sim/` outside the repo:** Sessions, history, and reports are user state, not project content. Putting them in `$HOME` follows XDG-ish conventions and keeps `git status` clean during practice.

## Schema Decisions (chosen, not enumerated)

### Pack `manifest.yaml`

```yaml
schemaVersion: 1
id: storage
name: Storage
weight: 10            # CKA blueprint percentage
domain: Storage       # matches existing CONVENTIONS.md domain strings
trapCatalog: ../../traps/catalog.yaml
questions:
  - 01-pvc-pending-waitforfirstconsumer
  - 02-hostpath-nodeaffinity-missing
  - 03-storageclass-default-misset
```

### Question `metadata.yaml`

```yaml
schemaVersion: 1
id: storage/01-pvc-pending-waitforfirstconsumer  # globally unique = pack/slug
title: PVC stuck Pending with WaitForFirstConsumer
domain: Storage
weight: 7              # points within a 100-point exam
estimatedMinutes: 7
namespace: cka-sim-storage-01    # NOT exercise-NN — see "Coexistence" below
nodes: [node-01]                 # which workers this question touches over ssh
preflight:               # required cluster state before setup may run
  - kubectl get nodes
  - ssh node-01 true
traps:                   # ids registered in traps/catalog.yaml
  - WRONG_NAMESPACE
  - DEFAULT_STORAGECLASS_MISSING
  - PVC_BOUND_BUT_WRONG_STORAGECLASS
references:              # links surfaced in the post-exam report
  - exercises/25-storage-waitforfirstconsumer/README.md
  - troubleshooting/README.md#pvc-stuck-pending
```

### Exam `manifest.yaml`

```yaml
schemaVersion: 1
id: blueprint-alpha
name: Mock Exam Alpha
timeLimitMinutes: 120
passMark: 66
questions:                # 17 entries; ordered, weighted to match CKA blueprint
  - ref: troubleshooting/04-kubelet-down-on-worker
    weight: 8
  - ref: cluster-architecture/02-rbac-impersonation
    weight: 6
  - ref: storage/01-pvc-pending-waitforfirstconsumer
    weight: 7
  # ... 14 more, summing to 100
```

**Why YAML for manifests + Markdown for question prose:** YAML is the lingua franca of this repo (skeletons, kubernetes manifests, CI), parseable with `yq` which is a small dependency the bootstrap installs. Markdown for `question.md` matches the prose style of every existing exercise and renders correctly in any pager (`bat`, `less -R` with `mdcat`, or just `cat`).

**Why a `schemaVersion`:** lets `lib/schema.sh` reject manifests it doesn't understand instead of silently mis-parsing.

## Architectural Patterns

### Pattern 1: Composition over duplication for exams

**What:** Exam blueprints reference question dirs by `pack/slug` id; question content lives exactly once under `packs/`.
**When to use:** Always. Never copy a question into `exams/<blueprint>/`.
**Trade-offs:** A breaking change to a question can cascade into multiple exams (mitigated by `cka-sim list exams --uses storage/01` and by `schemaVersion`). Benefit: fix a bug once, every blueprint heals.

```bash
# lib/loader.sh
resolve_question() {
  local ref="$1"                                  # "storage/01-pvc-pending-..."
  local path="${CKA_SIM_ROOT}/packs/${ref}"
  [[ -d "$path" ]] || die "unknown question: $ref"
  echo "$path"
}
```

### Pattern 2: Dot-sourced library, never re-exec

**What:** `cka-sim` and every command module use `source` to pull in `lib/*.sh`. Helpers are bash functions, not separate scripts.
**When to use:** Always inside this project. Spawning subshells for trivial helpers loses environment (PATH, KUBECONFIG, ETCDCTL_API) and slows the runner.
**Trade-offs:** Functions must be namespaced (`cka_sim::trap::detect_wrong_ns`) to avoid collisions; `set -euo pipefail` interactions must be reviewed per-file (matches the existing `scripts/validate-local.sh` discipline).

```bash
# bin/cka-sim (excerpt)
#!/bin/bash
set -euo pipefail
CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"   # mirrors existing REPO_ROOT idiom
export CKA_SIM_ROOT
# shellcheck source=../lib/log.sh
source "${CKA_SIM_ROOT}/lib/log.sh"
source "${CKA_SIM_ROOT}/lib/cmd/${1:-help}.sh"
"cmd::${1}::main" "${@:2}"
```

### Pattern 3: Trap detection as a shared helper library, called from every grader

**What:** `lib/traps.sh` exports `cka_sim::trap::*` functions; each `grade.sh` calls only the ones it cares about and emits trap ids. The runner reconciles ids with `traps/catalog.yaml` to render names in the report.
**When to use:** Every grader. Reimplementing "did the candidate use the wrong namespace?" in 17 graders is the single largest architectural risk.
**Trade-offs:** Coupling — graders depend on `lib/traps.sh` API stability. Benefit: a fix to "detect missing DNS egress" propagates to every grader that calls it.

```bash
# lib/traps.sh (excerpt)
cka_sim::trap::wrong_namespace() {
  local expected="$1" actual
  actual="$(kubectl config view --minify -o jsonpath='{..namespace}')"
  if [[ "$actual" != "$expected" ]]; then
    echo "WRONG_NAMESPACE"
  fi
}

cka_sim::trap::missing_dns_egress() {
  local netpol_ns="$1" netpol_name="$2"
  if ! kubectl -n "$netpol_ns" get netpol "$netpol_name" -o yaml \
       | grep -qE 'port:\s*53'; then
    echo "MISSING_DNS_EGRESS"
  fi
}

# packs/services-networking/03-netpol-deny-all/grade.sh
source "${CKA_SIM_LIB}/traps.sh"
hits=()
hits+=("$(cka_sim::trap::wrong_namespace cka-sim-net-03)")
hits+=("$(cka_sim::trap::missing_dns_egress cka-sim-net-03 frontend-policy)")
# emit non-empty hits as trap ids on stdout, exit 0/1 for pass/fail
```

### Pattern 4: Idempotent setup, conservative reset, never both at once

**What:** `setup.sh` is `kubectl apply`-shaped (re-running is safe and converges). `reset.sh` is `kubectl delete ns <namespace>` plus any explicit node-side cleanup. The runner ALWAYS runs `reset.sh` before `setup.sh` for the same question id, so a half-finished previous attempt doesn't poison the next.
**When to use:** Every question. Matches the existing `Cleanup: k delete ns exercise-NN` convention from CONVENTIONS.md.

### Pattern 5: Session as a JSON doc + Ctrl-C trap

**What:** A live exam writes one JSON file at `~/.cka-sim/sessions/<ts>.json` containing pack ref, question index, flagged ids, skipped ids, start time, deadline, per-question status. `lib/state.sh` reads/writes with `flock`. `bin/cka-sim` installs a `trap '_save_state; exit 130' INT` so Ctrl-C persists state cleanly. Resuming is `cka-sim exam --resume <ts>`.
**When to use:** Exam mode only — drill mode is single-question, no resume needed.
**Trade-offs:** JSON-in-bash is awkward; we use `jq` (already a soft dep) for reads and a small `state::set` helper for writes.

## Data Flow

### End-to-end question lifecycle (drill or exam)

```
[learner: cka-sim drill storage]
    │
    ▼
[router] ─► [cmd::drill::main]
                │
                ▼ load
        [loader] ── reads ──▶ packs/storage/manifest.yaml
                │
                ▼ pick (random or arg)
        [runner] ─ source ─▶ packs/storage/01-.../setup.sh
                │              │
                │              └─▶ kubectl apply ... (creates broken state)
                ▼
        [runner] prints question.md → waits for "done" / "skip" / "flag"
                │
                ▼
        [runner] ─ source ─▶ packs/storage/01-.../grade.sh
                                │
                                ├─ source lib/traps.sh
                                ├─ source lib/grade.sh
                                ├─ run kubectl assertions
                                └─ emit: PASS|FAIL + trap-ids on stdout
                │
                ▼
        [score] aggregate → write ~/.cka-sim/sessions/<ts>.json
                │
                ▼ (drill: immediate; exam: deferred to end)
        [report] render Markdown → ~/.cka-sim/reports/<ts>.md
                │
                ▼
        [runner] ─ source ─▶ packs/storage/01-.../reset.sh
                                └─▶ kubectl delete ns + ssh node-01 cleanup
```

### Mock-exam flow (17 questions, composition)

```
[exams/blueprint-alpha/manifest.yaml]
        │ 17 refs
        ▼
[loader::expand_blueprint]
        │  for each ref:
        ▼
[packs/<domain>/<slug>/]   ←── no copy, just resolved paths
        │
        ▼
[runner loop]                timer running in lib/timer.sh
   for q in questions:
     setup → present → wait (skip/flag/done)
        │
        ▼ when timer hits 0 OR all done
[grade pass]                 batch-grade in question order
   for q in questions:
     grade → record trap-ids and pass/fail
        │
        ▼
[score::aggregate]           weighted sum, per-domain bucket
        │
        ▼
[report::render]             Markdown: total / per-domain / trap frequencies / refs
        │
        ▼
[reset pass]                 reset.sh for each question, then ns sweep
```

### Bootstrap flow (idempotent, runs against existing cluster)

```
cka-sim bootstrap
    │
    ▼
[preflight]
    ├─ which kubectl jq yq
    ├─ kubectl get nodes (must show 3 Ready)
    └─ /etc/kubernetes/admin.conf readable
    │
    ▼
[ssh-keygen if absent]      ~/.ssh/id_ed25519
    │
    ▼
[distribute pubkey]         see decision below
    │
    ▼
[~/.ssh/config]             append idempotent Host node-01 / node-02 stanzas
    │                       (HostName <internal-ip>, User <whoever>, IdentityFile)
    ▼
[bashrc integration]        append guarded block:
    │                         # >>> cka-sim >>>
    │                         source <repo>/scripts/exam-setup.sh
    │                         export ETCDCTL_API=3
    │                         export PATH="$PATH:<repo>/cka-sim/bin"
    │                         # <<< cka-sim <<<
    │
    ▼
[install missing deps]      apt-get install -y yq jq (with sudo prompt)
    │
    ▼
[smoke test]                ssh node-01 hostname; kubectl get nodes
```

**Decision: pubkey distribution.** Recommended: SCP via the GCP internal IPs the user already has, not a DaemonSet. A DaemonSet to write `authorized_keys` would require host-mounted `/root/.ssh` or `/home/<user>/.ssh`, which is a security smell, and would only work after kubelet auth — but the whole point of bootstrap is to make ssh work *before* the candidate trusts kubelet RBAC. SCP is one line per node, requires the candidate's existing GCP-issued login (which they used to install kubeadm in the first place), and is idempotent with `ssh-copy-id -f`. Keep it simple.

```bash
# cka-sim/lib/cmd/bootstrap.sh (excerpt)
for node in node-01 node-02; do
  ip="$(_resolve_internal_ip "$node")"
  ssh-copy-id -f -i ~/.ssh/id_ed25519.pub -o StrictHostKeyChecking=accept-new \
              "${CKA_SIM_USER}@${ip}"
done
```

### State management

| State | Where | Lifecycle | Format |
|-------|-------|-----------|--------|
| Live exam session | `~/.cka-sim/sessions/<ts>.json` | written every Q boundary; deleted on completion | JSON (jq r/w, flock) |
| Completed session | `~/.cka-sim/history/<ts>.json` | append-only on exam end | JSON |
| Rendered report | `~/.cka-sim/reports/<ts>.md` | written once on exam end | Markdown |
| Debug log | `~/.cka-sim/logs/<ts>.log` | tee'd during run, rotated >30d | Plain text |
| Cluster state | The Kubernetes cluster itself | mutated by setup.sh, reverted by reset.sh | n/a |
| Ephemeral runner vars | bash env (KUBECONFIG, ETCDCTL_API) | dies with the shell | n/a |
| User config | `~/.cka-sim/config` | edited by `cka-sim bootstrap`; rarely changed | Bash key=value |

**Ctrl-C semantics:** `bin/cka-sim` installs `trap _on_int INT TERM`. `_on_int` calls `state::flush`, prints `[interrupted — resume with: cka-sim exam --resume <ts>]`, and `exit 130`. The session JSON contains enough to pick up at the next question (current question id, deadline absolute timestamp, flagged/skipped sets).

**Why JSON not bash assoc-array dump:** assoc-arrays don't survive serialization in bash 4 portably; jq + JSON is one well-known idiom. jq is already implicitly required by kubectl-heavy graders (extracting `.status.phase`).

## Build Order — maps to roadmap phases

The order is forced by dependencies: bootstrap must work before any setup.sh can run; the trap library must exist before any grade.sh can be authored without rework; the schema must be locked before any pack manifest is written.

| # | Component | Depends On | Phase Hint |
|---|-----------|------------|------------|
| 1 | `cka-sim/SCHEMA.md` + `lib/schema.sh` | nothing | Foundation phase 1 |
| 2 | `cka-sim/bin/cka-sim` router + `lib/log.sh`, `lib/colors.sh` | nothing | Foundation phase 1 |
| 3 | `lib/cmd/bootstrap.sh` + preflight | (1), (2), exam-setup.sh | Foundation phase 1 |
| 4 | `lib/traps.sh` + `traps/catalog.yaml` (initial trap set) | (1) | Foundation phase 2 |
| 5 | `lib/grade.sh` (assertion helpers) | (4) | Foundation phase 2 |
| 6 | `lib/runner.sh` + `lib/state.sh` + `lib/timer.sh` | (2), (5) | Foundation phase 2 |
| 7 | `lib/cmd/drill.sh` + first 1–2 reference questions per domain | (3)–(6) | Foundation phase 2 (closes the bootstrap → drill loop) |
| 8 | Pack: storage (full) | (7) | Content phase A |
| 9 | Pack: workloads-scheduling (full) | (7) | Content phase A |
| 10 | Pack: services-networking (full) | (7) | Content phase B |
| 11 | Pack: cluster-architecture (full) | (7) | Content phase B |
| 12 | Pack: troubleshooting (full, largest at 30%) | (7), (8)–(11) for cross-references | Content phase C |
| 13 | `lib/score.sh` + `lib/report.sh` | (6), (12) | Content phase C |
| 14 | `lib/cmd/exam.sh` + first blueprint | (8)–(13) | Simulation phase |
| 15 | Additional blueprints (bravo, charlie) | (14) | Simulation phase |
| 16 | `lib/cmd/score.sh history`, trap-frequency analytics | (15) | Polish phase |
| 17 | Banners on `exercises/`, `mock-exams/`, root README; CONTRIBUTING.md exam-sim section | none (cosmetic) | Polish phase |
| 18 | CI extension: shellcheck cka-sim/**/*.sh, yamllint cka-sim/**/*.yaml | (1)–(17) | Polish phase |

**Critical sequencing rule:** Step 4 (trap catalog + lib/traps.sh) MUST land before step 7 (first reference questions). Authoring graders before the trap helpers exist guarantees rework — every grader will have to be revisited once the helpers exist, and "trap-aware grading" is the project's stated differentiator vs the existing prose mock exams.

**Critical foundation rule:** Steps 1–3 form a single phase that ends with the candidate able to run `cka-sim bootstrap` against their cluster and have ssh + aliases + ETCDCTL_API working. Without that, no later step can be smoke-tested.

## Coexistence with the Existing Repo

This is a hard constraint from PROJECT.md ("Existing 31 exercises kept and labelled 'superseded', not deleted"). Concrete plan:

| Existing artifact | Treatment | Mechanism |
|-------------------|-----------|-----------|
| `exercises/` (31 folders) | Banner-only, no deletion. Some graders may *cite* an exercise as a "see also" reference in `metadata.yaml.references[]` | Add 6-line banner block at the top of `exercises/README.md` and each exercise's `README.md` is left untouched (banner only at the index) |
| `skeletons/*.yaml` | Reused as fixtures by some `setup.sh` (e.g. a Storage question can `kubectl apply -f ../../../skeletons/pvc.yaml`). Canonical source remains TEMPLATES.md | No changes to the files; `setup.sh` references via `${CKA_SIM_ROOT}/../skeletons/...` (or copy on first use into the exercise namespace) |
| `mock-exams/MOCK-EXAM-0[12].md` | Banner-only at the top of `mock-exams/README.md` pointing to `cka-sim exam blueprint-alpha`. Solution files untouched | Banner |
| `cheatsheet/` | Untouched. `question.md` files may link into it for hint references | None |
| `troubleshooting/` | Untouched. `metadata.yaml.references[]` may point at specific symptoms | None |
| `scripts/exam-setup.sh` | Untouched. `cka-sim bootstrap` *sources* it as part of `~/.bashrc` integration — so the existing alias contract (`k`, `$do`, `$now`) is the same alias contract the simulator's `question.md` prose assumes | Bootstrap appends a guarded block to `~/.bashrc` |
| `scripts/validate-local.sh` | Extended to also walk `cka-sim/**/*.yaml` and run `shellcheck` over `cka-sim/**/*.sh` | Add a second find-loop |
| `.github/workflows/validate.yml` | Extended path triggers to include `cka-sim/**`; jobs gain shellcheck step | Edit `paths:` and add a `shellcheck` step |
| `TEMPLATES.md` | Untouched (canonical YAML source) | None |
| `CONTRIBUTING.md` | Add a section "Authoring exam-sim questions" referencing `cka-sim/AUTHORING.md` | Append-only |
| `README.md` (root) | Add a top section "Quick path: take a mock exam" pointing at `cka-sim/`. Existing study-guide flow stays as-is below | Insert one section near top |

**Namespace convention divergence (intentional):** existing exercises use `exercise-NN`. New simulator questions use `cka-sim-<domain>-NN`. This prevents a candidate's running drill from clobbering a half-finished prose exercise namespace, and makes log greps unambiguous.

**No content harvesting in v1:** PROJECT.md Key Decision says "Rebuild from the Study Progress Tracker checklist rather than retro-fit existing 31 exercises". So existing exercise YAML/prose is *referenced* (via `metadata.yaml.references[]`) but not *imported*. If later phases want to harvest, the directory-of-files schema is wide open to it — a future tool could read an exercise README and emit a starter question dir.

## Anti-Patterns (specific to this project)

### Anti-Pattern 1: Per-question copy of trap detection logic

**What people do:** Each `grade.sh` implements its own "is the namespace right?" check.
**Why it's wrong:** 17+ questions × 8+ traps = >100 places where a fix has to land. The whole point of `lib/traps.sh` is one canonical implementation per trap.
**Do this instead:** Add the trap once to `lib/traps.sh` and `traps/catalog.yaml`; every `grade.sh` sources and calls.

### Anti-Pattern 2: Duplicating question content into exam blueprints

**What people do:** Copy `setup.sh`/`grade.sh` from `packs/storage/01-.../` into `exams/blueprint-alpha/Q03/`.
**Why it's wrong:** Exams diverge from packs over time; bug-fixes only land in one place; doubles the maintenance surface.
**Do this instead:** `exams/<id>/manifest.yaml` references questions by `pack/slug`. Always. If a blueprint needs a tweaked variant, *that* becomes a new question dir under `packs/`, and the blueprint references it.

### Anti-Pattern 3: Making `setup.sh` non-idempotent

**What people do:** `setup.sh` calls `kubectl create ns ...` (errors on second run), or seeds random data without a clean check.
**Why it's wrong:** PROJECT.md constraint: "Every `setup.sh` must be safe to re-run". Practice loops are short — re-running setup three times in a session must not poison the lab.
**Do this instead:** `kubectl apply` over `kubectl create`; `kubectl get ns X >/dev/null 2>&1 || kubectl create ns X`. If randomness is needed, seed from `metadata.yaml.id` for determinism.

### Anti-Pattern 4: Logging trap *names* instead of trap *ids*

**What people do:** `grade.sh` echoes "missing DNS egress" as freeform text.
**Why it's wrong:** The trap catalog is the source of truth for human-readable names. Freeform strings can't be aggregated across runs ("how often did I hit MISSING_DNS_EGRESS this month?"). Renames in the catalog won't propagate.
**Do this instead:** `grade.sh` emits stable ids (`MISSING_DNS_EGRESS`); the report renderer joins them against `traps/catalog.yaml` at render time.

### Anti-Pattern 5: Holding session state in shell variables only

**What people do:** Track `flagged_questions=()` purely in bash arrays, never persist.
**Why it's wrong:** Ctrl-C, terminal disconnect, or a crashed kubelet kills the whole 2-hour exam with no recovery — directly contradicts the realism this project is selling.
**Do this instead:** `lib/state.sh` writes `~/.cka-sim/sessions/<ts>.json` after every question boundary. `cka-sim exam --resume <ts>` rehydrates from disk.

### Anti-Pattern 6: Reaching into the existing `exercises/` tree from setup.sh

**What people do:** A simulator question's `setup.sh` calls `bash exercises/05-networkpolicy/...` to seed state.
**Why it's wrong:** Couples the simulator to "superseded reference" content. Breaks the coexistence story (should be able to delete `exercises/` and have the simulator still work).
**Do this instead:** Reuse `skeletons/*.yaml` (canonical fixtures) but never *execute* anything from `exercises/`. References from `metadata.yaml.references[]` are link-only, not invocation.

## Integration Points

### External tooling (binaries the runner shells out to)

| Tool | Used by | Notes |
|------|---------|-------|
| `kubectl` | every grade.sh, setup.sh; preflight | Pinned to the cluster's 1.35 server version |
| `etcdctl` | grader for cluster-architecture/etcd questions | `ETCDCTL_API=3` set by exam-setup.sh |
| `crictl` | grader for runtime/static-pod questions | Optional preflight check |
| `ssh` | every node-side fixture; bootstrap | Config in `~/.ssh/config` after bootstrap |
| `yq` | schema validation, manifest reading | apt-installed by bootstrap if missing |
| `jq` | session state r/w, kubectl JSON parsing | apt-installed by bootstrap if missing |
| `flock` | session file concurrency | util-linux, present on Ubuntu 22.04 |
| `shellcheck` | CI only | Not required at runtime |
| `yamllint` | CI only | Existing dep |

### Internal boundaries (who calls whom)

| Boundary | Direction | Mechanism |
|----------|-----------|-----------|
| `bin/cka-sim` ↔ `lib/cmd/<x>.sh` | one-way dispatch | `source` + `cmd::<x>::main` |
| `lib/cmd/*` ↔ `lib/{runner,state,timer,score,report}.sh` | one-way call | `source` + namespaced functions |
| `lib/runner.sh` ↔ per-question `setup.sh`/`grade.sh`/`reset.sh` | one-way `source` (NOT exec) | preserves CKA_SIM_* env, KUBECONFIG, namespace |
| Per-question `grade.sh` ↔ `lib/traps.sh`, `lib/grade.sh` | one-way `source` | every grader sources both libraries first |
| Runtime ↔ `~/.cka-sim/` | r/w via `lib/state.sh` only | flock-guarded; no other module writes there |
| Runtime ↔ cluster | r/w via kubectl/ssh only | no client-go, no helm SDK — bash-only constraint |
| CI ↔ everything | read-only validation | yamllint, shellcheck, schema.sh in `--check` mode |

## Sources

- PROJECT.md (constraints, key decisions, out-of-scope)
- .planning/codebase/ARCHITECTURE.md (existing layered study-guide model — the surface we coexist with)
- .planning/codebase/STRUCTURE.md (existing top-level layout; namespace convention `exercise-NN`)
- .planning/codebase/CONVENTIONS.md (bash style, YAML lint rules, alias contract from `scripts/exam-setup.sh`)
- killer.sh / killercoda question-pack folder convention (one dir per scenario with `setup`/`solve`/`verify` files) — well-known industry pattern this design mirrors deliberately
- Kubernetes-the-hard-way and kubeadm docs (composition-of-manifests pattern, idempotent kubectl apply)

---
*Architecture research for: CKA exam simulator (bash-only runner, single-learner, existing GCP cluster)*
*Researched: 2026-05-07*

---
phase: 05-services-networking-cluster-architecture-packs
plan: 01
subsystem: cka-sim scaffolding
tags: [bash-lint, helper-library, trap-catalog, ci]
requires: []
provides:
  - cka_sim::setup::seed_netpol_skeleton
  - cka_sim::setup::read_node_worker
  - 11 Phase 5 trap catalog entries
  - lint-packs pass F hardcoded-node guard
  - lint-deprecated-strings.sh CI lint
affects:
  - cka-sim/lib/setup.sh
  - cka-sim/traps/catalog.yaml
  - cka-sim/scripts/lint-packs.sh
  - cka-sim/scripts/lint-traps.sh
  - cka-sim/scripts/lint-deprecated-strings.sh
  - cka-sim/scripts/test.sh
  - .github/workflows/validate.yml
key_files_created:
  - cka-sim/scripts/lint-deprecated-strings.sh
  - cka-sim/tests/cases/setup_helpers_seed_netpol_skeleton.sh
  - cka-sim/tests/cases/setup_helpers_read_node_worker.sh
  - cka-sim/tests/cases/lint_deprecated_strings.sh
  - cka-sim/tests/fixtures/setup_helpers/seed_netpol_skeleton/basic.json
  - cka-sim/tests/fixtures/setup_helpers/read_node_worker/worker.json
  - cka-sim/tests/fixtures/setup_helpers/read_node_worker/empty.json
  - cka-sim/tests/fixtures/lint_deprecated_strings/hit.md
  - cka-sim/tests/fixtures/lint_deprecated_strings/miss.md
  - .planning/phases/05-services-networking-cluster-architecture-packs/deferred-items.md
key_files_modified:
  - cka-sim/lib/setup.sh
  - cka-sim/traps/catalog.yaml
  - cka-sim/scripts/lint-packs.sh
  - cka-sim/scripts/lint-traps.sh
  - cka-sim/scripts/test.sh
  - .github/workflows/validate.yml
  - cka-sim/packs/workloads-scheduling/06-static-pod/setup.sh
  - cka-sim/packs/workloads-scheduling/06-static-pod/grade.sh
  - cka-sim/packs/workloads-scheduling/06-static-pod/ref-solution.sh
decisions:
  - lint-packs pass F includes a conspicuous file-level sentinel for legitimate hostname-bound static-pod files only.
  - lint-traps summary now emits `entries schema OK` so the plan's 36-entry acceptance regex matches deterministically.
metrics:
  completed_date: 2026-05-12
  tasks_completed: 3
  task_commits: 3
  final_verification: passed
---

# Phase 05 Plan 01: Library + Catalog + Lint Extensions + CI Wiring Summary

Phase 5 scaffolding landed: shared setup helpers, 11 trap catalog entries, BUG-3 hardcoded-node lint guard, deprecated-strings CI lint, and 3 new unit cases. This enables later Services-Networking and Cluster-Architecture authoring plans to consume stable primitives instead of re-implementing shell/YAML patterns.

## Tasks Completed

| Task | Name | Commit | Result |
| --- | --- | --- | --- |
| 1 | Extend lib/setup.sh with 2 helpers + 2 unit test cases | d2be0ff | 2 helpers appended; test suite 29 -> 31 green |
| 2 | Extend traps/catalog.yaml with 11 entries + lint-packs pass F | e6c8a5b | catalog 25 -> 36 entries; hardcoded node lint active |
| 3 | Create lint-deprecated-strings.sh + wire test.sh/GHA + 1 test case | ed3a303 | deprecated-strings lint executable + CI step + test suite 32 green |

## Helper Signatures for P02-P15

```bash
cka_sim::setup::seed_netpol_skeleton <ns> <name> <selector-key=value>
cka_sim::setup::read_node_worker
```

### `seed_netpol_skeleton`

Creates a `networking.k8s.io/v1` NetworkPolicy with:

- `policyTypes: [Ingress, Egress]`
- `podSelector.matchLabels` parsed from `key=value`
- DNS egress allow rule to namespace label `kubernetes.io/metadata.name: kube-system`
- UDP/53 and TCP/53 ports

Use when seeding NetworkPolicy labs that must not accidentally trigger `missing-dns-egress`.

### `read_node_worker`

Runs:

```bash
kubectl get nodes -l '!node-role.kubernetes.io/control-plane' --no-headers -o jsonpath='{.items[0].metadata.name}'
```

Echoes the first non-control-plane node, or dies with:

```text
read_node_worker: no non-control-plane worker node found
```

Use instead of literal `node-01` or `node-02` in future pack setup scripts.

## New Trap IDs

| ID | Domain | Severity | Activating Plan |
| --- | --- | --- | --- |
| kube-proxy-mode-mismatch-ipvs-iptables | services-networking | warn | 05-06 kube-proxy mode |
| netpol-endport-missing-protocol | services-networking | error | 05-07 netpol endPort |
| coredns-forward-to-invalid-upstream | services-networking | error | 05-04 CoreDNS resolution |
| ingress-missing-ingressclass | services-networking | warn | 05-05 ingress path/host |
| etcd-snapshot-without-env-set | cluster-architecture | error | 05-09 etcd backup/restore |
| etcd-restore-wrong-data-dir | cluster-architecture | error | 05-09 etcd backup/restore |
| kubeadm-upgrade-skip-plan | cluster-architecture | warn | 05-10 kubeadm upgrade |
| audit-policy-wrong-stage-verbosity | cluster-architecture | warn | 05-12 audit policy |
| crd-missing-scope-field | cluster-architecture | error | 05-13 CRD basics |
| cri-endpoint-unix-prefix-missing | cluster-architecture | error | 05-14 CRI-dockerd endpoint |
| priorityclass-globaldefault-conflict | cluster-architecture | error | 05-15 PriorityClass |

Catalog total is now 36 entries. `cka-sim/scripts/lint-traps.sh` reports `catalog lint passed (36 entries schema OK).`

## lint-packs Pass F

New pass:

```text
pass F: BUG-3 pre-empt — no hardcoded node-01/node-02 in packs/**/*.sh
```

Fails future pack shell code when a non-comment line contains literal `node-01` or `node-02`:

```bash
ssh node-02 true
```

Passes when the line is a comment:

```bash
# Historical bug: node-02 was hardcoded here before Phase 5.
```

Preferred fix is dynamic discovery:

```bash
worker=$(cka_sim::setup::read_node_worker)
```

A file-level sentinel exists for legitimate hostname-bound drills only:

```bash
# cka-sim-lint: allow-node-literal
```

It is currently used only on `workloads-scheduling/06-static-pod`, where the drill is explicitly bound to the kubeadm control-plane hostname and a full dynamic retrofit is deferred.

## Deprecated-Strings Lint

Invocation:

```bash
bash cka-sim/scripts/lint-deprecated-strings.sh
```

CI wiring:

- Dedicated GitHub Actions step: `Lint deprecated strings`
- Aggregate `cka-sim/scripts/test.sh` also runs it after `lint-coverage.sh` and before unit cases.

Forbidden strings under `cka-sim/packs/**`:

| String | Reason |
| --- | --- |
| `PodSecurityPolicy` | removed in v1.25; PSS wording required |
| `--container-runtime=remote` | removed in v1.27; use `--container-runtime-endpoint` |
| `policy/v1beta1` | removed API version |
| `gitRepo:` | removed volume plugin pattern |
| `dockershim` | removed in v1.24 |

Carveouts:

- YAML/sh comment lines starting with `#` are allowed.
- Markdown prose outside fenced `yaml`, `bash`, `sh`, or `shell` code blocks is allowed.
- Hits inside fenced `yaml`, `bash`, `sh`, or `shell` blocks fail.

## Verification

Required full suite passed:

```bash
bash cka-sim/scripts/test.sh && \
  bash cka-sim/scripts/lint-packs.sh && \
  bash cka-sim/scripts/lint-traps.sh && \
  bash cka-sim/scripts/lint-coverage.sh && \
  bash cka-sim/scripts/lint-deprecated-strings.sh
```

Test count changed from 29 baseline cases to 32 cases:

- `setup_helpers_seed_netpol_skeleton`
- `setup_helpers_read_node_worker`
- `lint_deprecated_strings`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking Issue] lint-packs pass F exposed pre-existing static-pod node literals**
- **Found during:** Task 2
- **Issue:** `workloads-scheduling/06-static-pod` contains load-bearing `node-01` references because the drill SSHes to the kubeadm control-plane host and grades mirror pod suffix `q06-static-nginx-node-01`.
- **Fix:** Added a file-level `# cka-sim-lint: allow-node-literal` sentinel to the three static-pod shell files and taught pass F to skip files with that sentinel in the first 10 lines.
- **Files modified:** `cka-sim/scripts/lint-packs.sh`, `cka-sim/packs/workloads-scheduling/06-static-pod/setup.sh`, `grade.sh`, `ref-solution.sh`, `.planning/phases/05-services-networking-cluster-architecture-packs/deferred-items.md`
- **Commit:** e6c8a5b

**2. [Rule 3 - Blocking Issue] lint-traps summary did not match plan regex**
- **Found during:** Task 2 acceptance verification
- **Issue:** The existing summary was `catalog lint passed (36 entr(ies)).`, which did not match the plan's required regex `36 (catalog )?entr(y|ies) schema OK`.
- **Fix:** Updated success summary to `catalog lint passed (36 entries schema OK).`
- **Files modified:** `cka-sim/scripts/lint-traps.sh`
- **Commit:** e6c8a5b

## Deferred Issues

| Item | File(s) | Reason |
| --- | --- | --- |
| Static-pod dynamic hostname retrofit | `cka-sim/packs/workloads-scheduling/06-static-pod/{setup,grade,ref-solution}.sh` | Out of scope for 05-01; needs a new control-plane discovery helper and mirror-pod suffix lookup. Tracked in `.planning/phases/05-services-networking-cluster-architecture-packs/deferred-items.md`. |

## Known Stubs

| File | Stub | Reason |
| --- | --- | --- |
| `cka-sim/tests/fixtures/setup_helpers/seed_netpol_skeleton/basic.json` | Placeholder reference JSON | Existing unit-case convention; helper test stubs kubectl inline and captures heredoc output. |
| `cka-sim/tests/fixtures/setup_helpers/read_node_worker/worker.json` | Placeholder reference JSON | Existing unit-case convention; helper test stubs kubectl inline. |
| `cka-sim/tests/fixtures/setup_helpers/read_node_worker/empty.json` | Placeholder reference JSON | Existing unit-case convention; helper test stubs kubectl inline. |

These stubs are test fixtures only and do not block the plan goal.

## Threat Flags

| Flag | File | Description |
| --- | --- | --- |
| threat_flag: ci-lint-surface | `cka-sim/scripts/lint-deprecated-strings.sh` | New CI enforcement script scans pack content and exits non-zero on deprecated API strings outside carveouts. |

## Self-Check: PASSED

- Created files exist:
  - `cka-sim/scripts/lint-deprecated-strings.sh`
  - `cka-sim/tests/cases/setup_helpers_seed_netpol_skeleton.sh`
  - `cka-sim/tests/cases/setup_helpers_read_node_worker.sh`
  - `cka-sim/tests/cases/lint_deprecated_strings.sh`
  - `.planning/phases/05-services-networking-cluster-architecture-packs/deferred-items.md`
- Commits exist:
  - `d2be0ff` task 1 helper library
  - `e6c8a5b` task 2 catalog + pass F
  - `ed3a303` task 3 deprecated-strings lint
- Full required verification suite passed.
- No `STATE.md` or `ROADMAP.md` modifications made.

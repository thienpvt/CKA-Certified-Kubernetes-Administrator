# Phase 1: Cluster Bootstrap + Runner Skeleton — Context

**Gathered:** 2026-05-07
**Status:** Ready for planning
**Mode:** Smart discuss (batch grey-area acceptance)

<domain>
## Phase Boundary

Candidate runs `cka-sim bootstrap` on their control-plane node and ends up with a working simulator skeleton: passwordless SSH to `node-01`/`node-02`, environment set up, and `cka-sim doctor` reporting green against the 1+2 cluster. Router dispatches all subcommands (`bootstrap`, `doctor`, `list`, `version`, `--help`), with later-phase subcommands (`drill`, `exam`, `score`) stubbed so discovery doesn't error.

### Success criteria (from ROADMAP.md)
1. After `cka-sim bootstrap` on a fresh control-plane, `ssh -o BatchMode=yes node-01 hostname` returns the node hostname without any prompt
2. Running `cka-sim bootstrap` a second time produces no duplicates (no extra `Host node-*` blocks, no duplicated env exports)
3. `cka-sim doctor` exits 0 on a healthy 1+2 cluster; exits non-zero with a clear error when `kubectl get nodes` shows <3 nodes or any worker is unreachable via SSH
4. `cka-sim --help`, `cka-sim doctor`, `cka-sim list`, `cka-sim version` all dispatch correctly from a single entry-point script

### Requirements in scope
BOOT-01, BOOT-02, BOOT-03, BOOT-04, BOOT-05, BOOT-06, BOOT-07, RUN-01

### Requirements explicitly not in scope for phase 1
- RUN-02 (drill mode) — phase 3
- RUN-03..06 (exam mode, timer, session JSON, signals) — phase 7
- Any trap / grader / content work — phases 2+
</domain>

<decisions>
## Implementation Decisions (from smart discuss)

| # | Decision |
|---|----------|
| 1 | `cka-sim` symlinked from `/usr/local/bin/cka-sim` → `<repo>/cka-sim/bin/cka-sim`, created by bootstrap (requires one-time sudo). Source stays in repo. |
| 2 | Env exports (`ETCDCTL_API=3`, `CONTAINER_RUNTIME_ENDPOINT=unix:///run/containerd/containerd.sock`) land in `~/.bashrc` inside a `# === cka-sim BEGIN/END ===` sentinel block. Sentinel guards idempotency. |
| 3 | Dedicated SSH key `~/.ssh/cka_sim_ed25519` (never `~/.ssh/id_ed25519`). Named key is auditable and rotatable. |
| 4 | Router = thin dispatcher (`bin/cka-sim` parses `$1`, `exec`s `cka-sim/lib/cmd/<sub>.sh`). Each subcommand script is self-contained and sources shared helpers from `cka-sim/lib/*.sh`. |
| 5 | Host resolution via `HostName <ip>` in `~/.ssh/config` only. No `/etc/hosts` edits. IPs discovered via `kubectl get nodes -o jsonpath='...InternalIP...'`. |
| 6 | Missing-dependency policy: auto-install `jq` via `sudo apt-get install -y jq` if absent. Fail loudly with actual `apt-get` error on sudo/network failure. |
| 7 | State root at `$HOME/.cka-sim/{sessions,history,reports,logs}`. Bootstrap `mkdir -p` on every run (idempotent). |
| 8 | `cka-sim doctor` is read-only preflight. Checks: kubectl reachable, ≥3 nodes, SSH BatchMode works to every worker, `jq`/`etcdctl`/`crictl`/`kubectl` on PATH, kubeconfig readable. Exits 0/1 with actionable message. No auto-fix. |
| 9 | Subcommands in v1.0 Phase 1: `bootstrap`, `doctor`, `list`, `version`, `--help`. `drill`/`exam`/`score` exist as stub scripts that print "Not implemented yet — phase N". |
| 10 | Explicit sudo policy: bootstrap prompts before any sudo call (symlink install, optional jq install). Declined sudo prints the manual command the candidate must run. |

</decisions>

<code_context>
## Existing Code Insights

- `scripts/exam-setup.sh` already writes aliases + env exports to the shell. **Phase 1 does NOT source or fork it** — per BOOT-04, bootstrap does not inject any aliases. The env-export mechanism (sentinel-fenced block in ~/.bashrc) is new and specific to cka-sim.
- `scripts/validate-local.sh` shows the canonical bash style: `set -euo pipefail`, `REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"` idiom, ANSI color variables at the top, `#!/bin/bash` shebang. Phase 1 code follows the same style.
- `.gitattributes` pins LF line endings on `*.sh`. All new shell files respect this.
- The existing 1+2 GCP cluster is already kubeadm-installed with K8s 1.35 (per PROJECT.md Context). Bootstrap does NOT provision or init anything.
</code_context>

<specifics>
## Specific Ideas / Concrete Choices

### Layout
```
cka-sim/
├── bin/
│   └── cka-sim                    # router, the only $PATH-visible entry
├── lib/
│   ├── log.sh                     # die(), info(), warn(), ok(), header()
│   ├── colors.sh                  # RED, GREEN, YELLOW, NC
│   ├── preflight.sh               # shared dependency / node check helpers
│   └── cmd/
│       ├── bootstrap.sh           # Phase 1: full implementation
│       ├── doctor.sh              # Phase 1: full implementation
│       ├── list.sh                # Phase 1: stub printing "no packs yet — phase 4"
│       ├── version.sh             # Phase 1: prints cka-sim v1.0 + checksum
│       ├── drill.sh               # Phase 1: stub ("Not implemented yet — phase 3")
│       ├── exam.sh                # Phase 1: stub ("Not implemented yet — phase 7")
│       └── score.sh               # Phase 1: stub ("Not implemented yet — phase 7")
└── README.md                      # minimal quickstart (full version in phase 8)
```

### `bin/cka-sim` router shape
```bash
#!/bin/bash
set -euo pipefail
CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CKA_SIM_ROOT

# shellcheck disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
source "$CKA_SIM_ROOT/lib/log.sh"

cmd="${1:-help}"
case "$cmd" in
  -h|--help|help)    shift || true; exec "$CKA_SIM_ROOT/lib/cmd/help.sh" "$@" ;;
  bootstrap|doctor|list|version|drill|exam|score)
                     shift; exec "$CKA_SIM_ROOT/lib/cmd/$cmd.sh" "$@" ;;
  *) die "unknown subcommand: $cmd — run 'cka-sim --help'" ;;
esac
```

### Sentinel-fenced `~/.bashrc` block
```bash
# === cka-sim BEGIN (managed by cka-sim bootstrap; do not edit inside this block) ===
export ETCDCTL_API=3
export CONTAINER_RUNTIME_ENDPOINT=unix:///run/containerd/containerd.sock
# === cka-sim END ===
```

Bootstrap's idempotency pattern: `sed -i` to remove any existing block between markers, then append fresh block. One grep on the BEGIN marker controls whether to rewrite.

### `cka-sim doctor` check list
1. `kubectl version --client` succeeds, server reachable via `kubectl get --raw /livez`
2. `kubectl get nodes` returns ≥3 Ready nodes, ≥1 control-plane label, ≥2 workers
3. For each worker: `ssh -o BatchMode=yes -o ConnectTimeout=3 node-NN hostname` succeeds in <3s
4. `command -v jq kubectl etcdctl crictl` all succeed
5. `test -r "$KUBECONFIG"` (defaulting to `/etc/kubernetes/admin.conf` or `~/.kube/config`)
6. `~/.cka-sim/` directory structure exists

On any failure: print exactly one actionable line explaining what's wrong + the fix command. Exit 1.

### Platform
- Target: Ubuntu 22.04 (bash 5.1, OpenSSH 8.9, coreutils)
- Dev: shellcheck + bats-core available locally (not installed on cluster)
</specifics>

<deferred>
## Deferred Ideas (outside Phase 1)

- `cka-sim doctor --fix` (auto-remediate missing deps/missing keys) — v1.x
- `cka-sim bootstrap --dry-run` — v1.x
- Windows WSL compatibility layer — out of scope per PROJECT.md
- Automatic retry/backoff if ssh-copy-id fails — bootstrap just errors out for now
</deferred>

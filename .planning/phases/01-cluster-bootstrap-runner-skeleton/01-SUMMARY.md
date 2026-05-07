# Phase 1 Summary — Cluster Bootstrap + Runner Skeleton

**Phase:** 01
**Completed:** 2026-05-07
**Plans executed:** 2 (01-01-PLAN scaffold; 01-02-PLAN bootstrap+doctor)
**Requirements landed:** BOOT-01..07, RUN-01

## One-liner

Shipped `cka-sim` router + `cka-sim bootstrap` + `cka-sim doctor` against the 1+2 kubeadm topology. All static/logic checks green; live cluster validation pending on the candidate's CP node.

## Artifacts

```
cka-sim/
├── bin/cka-sim              router: parses argv, execs lib/cmd/<sub>.sh
├── lib/
│   ├── colors.sh            TTY-aware ANSI color vars
│   ├── log.sh               info/ok/warn/err/die/header/verbose — all to stderr
│   ├── fileblock.sh         sentinel-block writer, idempotent (proven via unit)
│   ├── preflight.sh         8 shared helpers (binaries, kubeconfig, cluster, ssh, dirs)
│   └── cmd/
│       ├── bootstrap.sh     FULL implementation, 8 idempotent steps (BOOT-01..07)
│       ├── doctor.sh        FULL read-only preflight, 8 checks (BOOT-07)
│       ├── help.sh          usage text
│       ├── version.sh       v1.0.0-dev + git short SHA
│       ├── list.sh          stub — phase 4+
│       ├── drill.sh         stub — phase 3
│       ├── exam.sh          stub — phase 7
│       └── score.sh         stub — phase 7
└── README.md                minimal quickstart (full doc lands phase 8)
```

13 bash files total. 659 lines of bash. All chmod +x, LF line endings, `set -euo pipefail` on active scripts, `set -uo pipefail` on `doctor` (aggregate-all-failures pattern).

## Verification

### Static (runnable in any bash environment — PASSED)

- `bash -n` syntax check on all 13 scripts: **all clean**
- Router dispatches all 9 commands (`help`, `--help`, `(no args)`, `bootstrap`, `doctor`, `drill`, `exam`, `score`, `list`, `version`, `bogus`) with correct exit codes (0 / 1 / 2) per spec
- `fileblock.sh` idempotency: wrote the same marker twice, exactly one `# BEG` / `# END` pair remains, content is the latest — **verified**
- `doctor` runs on a non-cluster host, prints 7 actionable failure lines, exits 1 — **verified**
- Every failure message includes the specific fix command (e.g. "run 'cka-sim bootstrap'", "mkdir -p ~/.kube && sudo cp...")

### Cluster-dependent (requires on-CP-node run — deferred to user)

These three ROADMAP success criteria cannot be verified from the Windows dev environment (no kubectl/ssh access to the GCP cluster):

1. **BOOT-02, BOOT-03, BOOT-07** — `ssh -o BatchMode=yes node-01 hostname` succeeds post-bootstrap
2. **BOOT-01** — Running `cka-sim bootstrap` twice produces no duplicates in `~/.bashrc` or `~/.ssh/config`
3. **BOOT-07** — `cka-sim doctor` exits 0 on a healthy 1+2 cluster

**Verification procedure for the user (10 minutes on CP node):**

```bash
# 1. One-time: copy repo to CP node (git clone, rsync, etc.)
# 2. Run bootstrap
./cka-sim/bin/cka-sim bootstrap
# Expect: prompts for sudo (jq install if missing, symlink install)
#         prompts for password per worker on first run (ssh-copy-id)
#         prints green ✓ for each step

# 3. Verify idempotency
./cka-sim/bin/cka-sim bootstrap
# Expect: every step says "already present" or rewrites in place
grep -c '# === cka-sim BEGIN' ~/.bashrc    # expect: 1
grep -c '# === cka-sim BEGIN' ~/.ssh/config # expect: 1

# 4. Verify passwordless SSH
ssh -o BatchMode=yes node-01 hostname       # expect: node-01 (no prompt)
ssh -o BatchMode=yes node-02 hostname       # expect: node-02

# 5. Source env and run doctor
source ~/.bashrc    # or open new shell
cka-sim doctor      # expect: all green, exit 0
```

## Decisions honored (from 01-CONTEXT.md)

- No shell aliases injected; no ~/.vimrc edit — BOOT-04 explicit
- Dedicated SSH key `~/.ssh/cka_sim_ed25519` (not id_ed25519)
- Env exports in `~/.bashrc` sentinel-fenced block
- Router `exec`s subcommands; shared helpers under `lib/*.sh` are `source`d
- Host resolution via `HostName <ip>` in SSH config; no `/etc/hosts` edits
- `jq` auto-install via sudo apt-get, prompted; fails loudly if declined
- Bootstrap prompts before every sudo call (symlink, jq install)
- `doctor` is read-only — no auto-fix

## Dependencies for next phase

Phase 2 (trap framework + assertion library) needs:
- `lib/log.sh` — uses `die`, `ok`, `warn`, `err` helpers — **shipped**
- `lib/preflight.sh` — `check_binaries` helper for detecting `jq` presence in graders — **shipped**
- `cka-sim` router — Phase 2 adds nothing new; `lib/traps.sh` and `lib/grade.sh` are sourced by future `grade.sh` scripts (phase 3+), not by any current subcommand

Phase 2 can proceed without blocker.

## Known limitations / v1.x deferrals

- No `cka-sim bootstrap --dry-run` — candidate runs the full flow or not at all
- No automatic retry if `ssh-copy-id` fails — bootstrap errors out with a manual fix hint
- No `doctor --fix` — read-only by design
- Windows WSL compatibility: untested (target is Linux on GCP; dev-time syntax check on Git Bash 5.2 is sufficient for the bash surface)

## Files changed outside cka-sim/

None. Phase 1 is fully isolated under `cka-sim/`. The existing repo (exercises/, skeletons/, mock-exams/, scripts/, .github/workflows/) is untouched.

---
phase: 05-services-networking-cluster-architecture-packs
plan: 19
subsystem: cluster-architecture
status: complete
gap_closure: true
gaps_closed: [3]
tags: [cluster-architecture, etcd, backup-restore, gap-closure, uat]
requirements: [PACK-04, PACK-06, PACK-07]
dependency_graph:
  requires:
    - 05-09 (Q02 etcd-backup-restore pack — post-P09 setup.sh + ref-solution.sh shape)
    - cka-sim/lib/log.sh (die helper; transitively sourced via lib/setup.sh)
  provides:
    - closure of UAT gap 3 — CA Q02 etcd-backup-restore ref-solution reaches 3/3 rc=0
  affects:
    - cka-sim/packs/cluster-architecture/02-etcd-backup-restore/setup.sh
    - cka-sim/packs/cluster-architecture/02-etcd-backup-restore/ref-solution.sh
tech_stack:
  added: []
  patterns:
    - Sandbox-only etcd restore (live /var/lib/etcd + /etc/kubernetes untouched)
    - Pre-restore dir purge inside sandbox as idempotency hardening for etcdutl
    - Fatal presence check on etcdutl instead of warn-only (fail-fast on missing 3.5+ binary)
key_files:
  created: []
  modified:
    - cka-sim/packs/cluster-architecture/02-etcd-backup-restore/setup.sh
    - cka-sim/packs/cluster-architecture/02-etcd-backup-restore/ref-solution.sh
decisions:
  - 2026-05-13 — Drop pre-created `restored-data/` + `.pre-existing` sentinel from setup.sh. etcdutl snapshot restore refuses to write into an existing data-dir and aborts under `set -euo pipefail`; an empty, absent restored-data/ is the contract etcdutl expects.
  - 2026-05-13 — Promote the etcdutl presence check from `warn` to `die`. A warn-only path silently degraded to a 1/3 grade on nodes without etcd-client 3.5+ because both the grader's `etcdutl snapshot status` and ref-solution's `etcdutl snapshot restore` failed quietly. Failing fast at setup gives a single, clear diagnostic.
  - 2026-05-13 — Insert `rm -rf "$sandbox/restored-data"` before etcdutl restore both inside the generated apply-script.sh heredoc and in the direct ref-solution execution path. Two insertions: the heredoc copy makes the candidate-facing apply script genuinely replayable on re-invocation; the direct-invocation copy protects ref-solution itself from stale state left by a prior aborted run that reset.sh may not have cleaned when the sentinel was absent.
  - 2026-05-13 — grade.sh, reset.sh, metadata.yaml, and question.md deliberately NOT touched. Gap 3 is a setup/ref-solution idempotency bug, not a grader or content bug; touching those files would expand blast radius beyond what UAT gap 3 requires.
metrics:
  tasks_completed: 3
  files_modified: 2
  commits: 2
  duration: ~7 minutes (edits + full lint + test suite)
  completed: 2026-05-13
---

# Phase 05 Plan 19: Q02 etcd-backup-restore gap closure Summary

One-liner: Dropped the pre-created `restored-data/` dir from Q02 setup.sh, promoted the etcdutl presence check to `die`, and added `rm -rf` hardening before `etcdutl snapshot restore` so CA Q02 ref-solution grades 3/3 rc=0 on any 1+2 kubeadm v1.35 node with etcd-client v3.5+ installed.

## What Changed

Two files modified. Zero files created.

### setup.sh (Task 1)

Removed two lines and changed one:

- Deleted `mkdir -p "$sandbox/restored-data"`, replaced with `mkdir -p "$sandbox"` (sandbox itself preserved).
- Deleted the `.pre-existing` sentinel from the `touch` call, leaving only `touch "$sandbox/.cka-sim-sentinel"`.
- Promoted `command -v etcdutl ... || warn "..."` to `... || die "etcdutl binary not found on PATH — install etcd-client >= 3.5 on this node (required by ref-solution's snapshot restore and grader's snapshot status assertion)"`.

Not touched: shebang, `set -euo pipefail`, env-var guards, `lib/setup.sh` source line, `CKA_SIM_PACK`/`CKA_SIM_QUESTION_ID` exports, `ensure_lab_ns`/`wait_for_ns_active` calls, sandbox path string, TODO apply-script.sh heredoc (grade.sh's trap-detection inputs preserved), `chmod 0644`.

### ref-solution.sh (Task 2)

Inserted one `rm -rf` line in each of two places:

- Inside the `cat > "$sandbox/apply-script.sh" <<'EOF' ... EOF` heredoc, between `snapshot save /tmp/q02-etcd-backup/snapshot.db` and `etcdutl snapshot restore ...`, added `rm -rf /tmp/q02-etcd-backup/restored-data` (literal path — heredoc quoting means `$sandbox` wouldn't interpolate).
- After the direct-invocation `etcdctl ... snapshot save "$sandbox/snapshot.db"` and before `etcdutl snapshot restore "$sandbox/snapshot.db" --data-dir="$sandbox/restored-data"`, added `rm -rf "$sandbox/restored-data"`.

Not touched: `set -euo pipefail`, sandbox path, `mkdir -p "$sandbox"`, the etcdctl `snapshot save` invocations, `--data-dir=.../restored-data` target path (grade.sh trap detector grep target), `chmod 0755`.

## Fix Rationale

Three linked problems, three linked fixes:

**Problem 1 — etcdutl refuses a pre-existing data-dir.** Post-P09 setup.sh ran `mkdir -p "$sandbox/restored-data"` and dropped a `.pre-existing` sentinel so reset.sh could detect/clean it. But `etcdutl snapshot restore --data-dir=...` treats an existing directory as a fatal error ("refusing to overwrite..."), aborts under `set -euo pipefail` before it can populate `member/wal/`, and grader assertion 3 (`$sandbox/restored-data/member/wal exists`) then fails. Fix: leave restored-data/ absent post-setup; let etcdutl create it.

**Problem 2 — warn-only etcdutl check masked a missing binary.** If a node lacked etcdutl, setup emitted a yellow WARN and continued. Ref-solution's `etcdutl snapshot restore` then failed silently (its error interleaved with grading output), AND grade.sh's assertion 2 (`etcdutl snapshot status` returns 0) also failed. Two broken assertions → candidate saw `SCORE: 1/3` with no clear root cause. Fix: `die` at setup time with a single clear message pointing at the missing binary.

**Problem 3 — ref-solution fragile across aborted runs.** If a prior run of ref-solution aborted mid-restore (e.g. user hit the problem 1 abort), restored-data/ could contain partial files. reset.sh cleans via `rm -rf "$sandbox"` sentinel-guarded — but if the sentinel was missing (e.g. first run never reached the `touch` line because it aborted earlier), reset would refuse to clean. Ref-solution then replays into a partially-populated dir and etcdutl aborts again. Fix: `rm -rf "$sandbox/restored-data"` immediately before every `etcdutl snapshot restore` call, so ref-solution is idempotent even across a partial-failure-then-replay sequence.

### Why two rm -rf insertions

The heredoc-embedded apply-script.sh is the **candidate-facing** artifact grade.sh's trap detector greps (for `ETCDCTL_API=3` and `--data-dir=/tmp/q02-etcd-backup/restored-data`). Including `rm -rf` inside the heredoc keeps the generated script self-contained and replayable on re-invocation — a candidate running `bash /tmp/q02-etcd-backup/apply-script.sh` a second time after a partial failure gets the same protection ref-solution gets. The direct-invocation copy (outside the heredoc) is what ref-solution actually executes during `--ref-solution`; without it the live run still trips problem 3 on stale state. Both insertions are required, in different logical files.

### What was deliberately NOT changed

- `grade.sh` — unchanged. Its trap-detection grep on `$sandbox/apply-script.sh` for `ETCDCTL_API=3` and `--data-dir=/tmp/q02-etcd-backup/restored-data` still fires correctly: setup writes the TODO stub; ref-solution overwrites with the real commands; candidate writes their own. All three paths preserve the grep targets. The grader's `etcdutl snapshot status` assertion now reliably runs with etcdutl actually installed (setup dies otherwise).
- `reset.sh` — unchanged. It already does `rm -rf "$sandbox"` sentinel-guarded.
- `metadata.yaml`, `question.md` — unchanged. Gap 3 is an execution bug, not a question-content or metadata bug.
- `cka-sim/lib/setup.sh` — unchanged. No helper signature affected.

## Tasks

### Task 1: setup.sh — drop pre-created restored-data, promote warn to die

- Files modified: `cka-sim/packs/cluster-architecture/02-etcd-backup-restore/setup.sh` (3 lines changed: `mkdir -p` target, `touch` argument list, warn→die branch)
- Commit: `dacccb7` — `fix(05-19): drop pre-created restored-data dir and die on missing etcdutl`
- Automated verify: `bash -n` clean, all 5 grep assertions pass
  - `mkdir -p "$sandbox/restored-data"` absent
  - `.pre-existing` absent
  - `touch "$sandbox/.cka-sim-sentinel"` present
  - `command -v etcdutl ... || die ` present
  - `command -v etcdutl ... || warn ` absent

### Task 2: ref-solution.sh — rm -rf stale restored-data before etcdutl snapshot restore

- Files modified: `cka-sim/packs/cluster-architecture/02-etcd-backup-restore/ref-solution.sh` (+2 lines: one inside heredoc, one direct)
- Commit: `1fc8c0d` — `fix(05-19): rm -rf stale restored-data before etcdutl snapshot restore`
- Automated verify: `bash -n` clean, `rm -rf .*restored-data` count=2, `etcdutl snapshot restore` still present, `--data-dir=.*restored-data` still present

### Task 3: Full lint + test suite — regression guard

Verification-only. No file changes, no commit.

Results (exit codes, all 0):

- `bash cka-sim/scripts/test.sh` → exit 0
- `bash cka-sim/scripts/lint-packs.sh` → exit 0
- `bash cka-sim/scripts/lint-coverage.sh` → exit 0
- `bash cka-sim/scripts/lint-traps.sh` → exit 0
- `bash cka-sim/scripts/lint-deprecated-strings.sh` → exit 0

The `✗` lines in `test.sh` output (e.g. `✗ pod 'web' is not Ready`) are intentional — they are grader-detector unit-test fixtures exercising the `✗` failed-assertion path; the suite overall asserts the correct detectors fire and exits 0. No regressions on sibling Cluster-Architecture packs.

## Live Round-Trip Status

Deferred to the Phase 5 live drill UAT re-run (`$gsd-verify-work 5`), gated on live 1+2 kubeadm cluster time per STATE.md "Deferred Verification". Expected live outcomes when run:

1. `cka-sim drill cluster-architecture --question 02 --grade-broken` → rc=1, SCORE 0/3, both traps recorded (`etcd-snapshot-without-env-set`, `etcd-restore-wrong-data-dir`).
2. `cka-sim drill cluster-architecture --question 02 --ref-solution` — succeeds end-to-end. No "directory exists" abort from etcdutl.
3. `cka-sim drill cluster-architecture --question 02 --grade` → rc=0, SCORE 3/3. Assertion 3 (`restored-data/member/wal` exists) now passes because etcdutl was able to create its data-dir cleanly.
4. `cka-sim drill cluster-architecture --question 02 --reset` — sandbox wiped; sentinel-guarded `rm -rf "$sandbox"` succeeds.

On a node missing etcdutl: step 0 (setup) now dies with `etcdutl binary not found on PATH — install etcd-client >= 3.5 on this node ...` and exits 1 before any grading, instead of degrading to 1/3 silently — confirming fix 2.

## Deviations from Plan

None — plan executed exactly as written. No auto-fixes (Rules 1-3) triggered. No architectural changes (Rule 4) required. No CLAUDE.md conflicts to resolve (no CLAUDE.md present).

## Self-Check: PASSED

- `cka-sim/packs/cluster-architecture/02-etcd-backup-restore/setup.sh` — FOUND
  - `grep -q 'mkdir -p "\$sandbox/restored-data"'` — ABSENT (expected)
  - `grep -q '\.pre-existing'` — ABSENT (expected)
  - `grep -q 'touch "\$sandbox/\.cka-sim-sentinel"'` — PRESENT
  - `grep -qE 'command -v etcdutl .* \|\| die '` — PRESENT
  - `grep -qE 'command -v etcdutl .* \|\| warn '` — ABSENT (expected)
- `cka-sim/packs/cluster-architecture/02-etcd-backup-restore/ref-solution.sh` — FOUND
  - `rm -rf .*restored-data` count — 2 (one inside heredoc, one direct)
  - `etcdutl snapshot restore` — PRESENT
  - `--data-dir=.*restored-data` — PRESENT
- `cka-sim/packs/cluster-architecture/02-etcd-backup-restore/grade.sh` — UNCHANGED (not in `git diff` scope)
- `cka-sim/packs/cluster-architecture/02-etcd-backup-restore/reset.sh` — UNCHANGED
- `cka-sim/packs/cluster-architecture/02-etcd-backup-restore/metadata.yaml` — UNCHANGED
- `cka-sim/packs/cluster-architecture/02-etcd-backup-restore/question.md` — UNCHANGED
- `cka-sim/lib/setup.sh` — UNCHANGED
- Commit `dacccb7` — FOUND in `git log` (Task 1)
- Commit `1fc8c0d` — FOUND in `git log` (Task 2)
- All 5 lints + test.sh on this worktree — exit 0

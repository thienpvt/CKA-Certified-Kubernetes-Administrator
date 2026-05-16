# Phase 7 Research — Exam Mode + Blueprint Alpha + Reporting

**Phase:** 07
**Researcher:** orchestrator-direct (gsd-phase-researcher hit transient classifier errors twice; written from CONTEXT.md + codebase reads)
**Date:** 2026-05-13

> Notes on context: CONTEXT.md (07-CONTEXT.md, 27 locked decisions) is the source of truth for *what* to build. This RESEARCH.md focuses on *how* — bash idioms, signal/timer mechanics, JSON state, blueprint composition algorithm, validation surface, and pitfalls.

---

## Validation Architecture

**Required by gsd-plan-phase Nyquist gate.** Every Phase 7 requirement gets at least one automated verification anchor.

| REQ-ID | Verification Anchor | Test Type | Location |
|---|---|---|---|
| RUN-03 | `cka-sim exam blueprint-alpha` end-to-end run with mock graders + fast-clock env returns a session.json with 17 question entries, status=completed, and a final_report_path on disk | Integration (golden) | `cka-sim/tests/exam/exam_end_to_end.sh` |
| RUN-04 | Unit test of the timer subshell: spawn it with `CKA_SIM_TIMER_FAST=1` (1s = 100ms scale), capture stdout for 5 ticks, assert each line matches `^.*[0-2][0-9]:[0-5][0-9]:[0-5][0-9].*$` and decrements monotonically | Unit | `cka-sim/tests/exam/timer_render.sh` |
| RUN-05 | Spawn `exam` to a fixture state mid-question, send SIGINT, assert session.json has `current_question.flagged=true` and `current_question_idx` unchanged. Then `--resume <ts>` re-reads JSON, verify deadline_ts arithmetic against frozen `date +%s` mock | Integration | `cka-sim/tests/exam/resume_after_int.sh` |
| RUN-06 | Three test cases: (a) SIGINT mid-question → flagged + persisted, exam continues; (b) SIGTSTP → state persisted with `paused_at` set, parent receives SIGSTOP (test by checking `kill -0 $$` from a wrapper); (c) SIGTERM → EXIT trap fires, JSON has `status=killed` | Unit | `cka-sim/tests/exam/signal_handlers.sh` |
| MOCK-01 | `lint-packs.sh` extension validates `exams/blueprint-alpha/manifest.yaml`: exactly 17 questions, weighting fields present + values 10/30/15/25/20, every (pack, slug) pair resolves to an existing question dir, no duplicate (pack, slug) pairs, sum of estimatedMinutes ∈ [120, 130] (note: deviation from REQUIREMENTS.md [110, 120] per D-15) | Lint | `cka-sim/scripts/lint-packs.sh` (new pass H) |
| MOCK-03 | Lint that `exams/blueprint-alpha/README.md` contains the exact disclaimer string "Not real CKA exam content; independently authored" AND `manifest.yaml` `exam.disclaimer` field contains the same | Lint | `cka-sim/scripts/lint-packs.sh` (new pass H, sub-rule) |
| REPORT-01 | Golden-file test: feed `tests/fixtures/exam/session-fixture.json` (a fully-completed session with deterministic scores) to `cka_sim::report::render`, diff against `tests/fixtures/exam/expected-report.md`. Fixture covers every report section: total/pass-fail, per-domain table sorted lowest-first, top-5 traps with raw counts, bottom-3 next-drills | Integration (golden) | `cka-sim/tests/exam/report_golden.sh` |
| REPORT-02 | Unit test: `cka-sim score <ts>` reads fixture session.json + writes report.md if missing, prints contents to stdout. `cka-sim list history` walks fixture sessions dir, returns table with N rows | Unit | `cka-sim/tests/exam/score_command.sh`, `tests/exam/list_history.sh` |

**Test patterns (concrete):**

1. **Mock graders** — fixtures under `cka-sim/tests/fixtures/exam/mock-packs/` providing fake `setup.sh`/`grade.sh`/`reset.sh` triplets. Each mock `grade.sh` emits a deterministic `SCORE: N/M` and known `Trap N: <id>: <description>` lines so the report golden test is reproducible.
2. **Time freezing** — `CKA_SIM_NOW_OVERRIDE=<unix_ts>` env var; `cka_sim::exam::now()` returns this when set, else `date +%s`. Lets tests assert deadline_ts arithmetic without sleeping.
3. **JSON assertions** — use `jq -e` to fail-fast on missing fields; tests pipe expected→actual through `diff <(jq -S . expected) <(jq -S . actual)`.
4. **Skip terminal-rendering tests** — `tput sc/rc` is environment-dependent (TERM, terminal size). Test the *data* feeding the timer (deadline arithmetic, paused_seconds delta), not the rendered output. Add a smoke test that runs the timer subshell in a `script -q` capture for 3 seconds and asserts ≥3 stdout lines.
5. **Signal tests** — use `bash -c '... &; pid=$!; kill -INT $pid; wait $pid'` patterns. Test in a subshell so trap state is isolated.

---

## Architecture & Module Layout

Total estimated bash LOC: ~1400-1700 across 5 new/modified files. Below the existing drill.sh (338 LOC) precedent.

### File breakdown

```
cka-sim/lib/cmd/exam.sh        ~550 LOC  (main exam loop, signal handlers, prompts)
cka-sim/lib/cmd/score.sh       ~120 LOC  (re-display + on-demand regenerate)
cka-sim/lib/cmd/list.sh        ~100 LOC  (extend Phase 1 stub: history subcommand)
cka-sim/lib/exam-state.sh      ~250 LOC  (JSON read/write, atomic updates)
cka-sim/lib/exam-blueprint.sh  ~150 LOC  (manifest parser, question resolver)
cka-sim/lib/exam-report.sh     ~280 LOC  (Markdown report renderer)
cka-sim/lib/exam-timer.sh      ~120 LOC  (background timer subshell, signal-safe)
exams/blueprint-alpha/manifest.yaml  ~80 LOC
exams/blueprint-alpha/README.md      ~40 LOC
cka-sim/scripts/lint-packs.sh  +120 LOC  (new pass H — blueprint manifest)
cka-sim/tests/exam/*.sh        ~500 LOC across ~10 case files
cka-sim/tests/fixtures/exam/   ~300 LOC across mock packs + session-fixture.json + expected-report.md
```

Keeping `lib/cmd/exam.sh` as the orchestrator that sources `lib/exam-*.sh` helpers mirrors how `drill.sh` keeps everything in one file. The split here is necessary because exam.sh has 5+ responsibilities (loop, signals, timer, state, prompt) and one file would exceed 800 LOC.

### Function decomposition (cka_sim:: namespace)

**`lib/cmd/exam.sh`** (orchestrator):
- `cka_sim::exam::usage` — print help
- `cka_sim::exam::main` — entry point, dispatches `exam <blueprint>` vs `exam --resume <ts>`
- `cka_sim::exam::start_new` — create new session, init state, run main loop
- `cka_sim::exam::resume` — load existing session, re-setup current question, recompute deadline, run main loop
- `cka_sim::exam::question_loop` — the 17-iteration loop (or partial on resume)
- `cka_sim::exam::present_question` — show header + question.md, return action token
- `cka_sim::exam::handle_action` — branch on Enter/f/s/n/p/q
- `cka_sim::exam::on_int` — INT trap: flag current question, persist
- `cka_sim::exam::on_tstp` — TSTP trap: persist with paused_at, then `kill -STOP $$`
- `cka_sim::exam::on_cont` — CONT trap: re-spawn timer, recompute remaining
- `cka_sim::exam::on_exit` — EXIT trap: persist, clean up timer subshell, run reset.sh for any active question namespaces
- `cka_sim::exam::batch_grade` — end-of-exam: run grade.sh against each set-up question, capture into state
- `cka_sim::exam::confirm_submit` — pre-grade summary screen with flagged/skipped counts

**`lib/exam-state.sh`** (JSON state):
- `cka_sim::state::init <blueprint_path>` — create new ~/.cka-sim/sessions/<ts>.json
- `cka_sim::state::load <ts>` — read session into in-memory shell vars (jq -r extraction)
- `cka_sim::state::save` — atomic write back to disk (mktemp+mv)
- `cka_sim::state::set_question_status <idx> <status>` — pending|flagged|skipped|answered
- `cka_sim::state::record_grade <idx> <rc> <stdout_capture>` — parse SCORE+Trap lines, store
- `cka_sim::state::set_pause` — record paused_at timestamp
- `cka_sim::state::add_pause_delta` — on resume, add (now - paused_at) to paused_seconds
- `cka_sim::state::session_path <ts>` — return ~/.cka-sim/sessions/<ts>.json
- `cka_sim::state::log_path <ts>` — return ~/.cka-sim/sessions/<ts>.log
- `cka_sim::state::transcript_append <idx> <id>` — append `=== question NN: <id> ===` divider + grader stdout to .log
- `cka_sim::state::list_sessions` — `ls ~/.cka-sim/sessions/*.json | sort -r`

**`lib/exam-blueprint.sh`** (manifest):
- `cka_sim::blueprint::load <path>` — parse exams/<id>/manifest.yaml using same pure-bash YAML walker pattern from drill.sh::_parse_manifest, extending it for blueprint shape
- `cka_sim::blueprint::resolve_question <pack> <slug>` — return absolute path to packs/<pack>/<slug>/, verify 6 required files exist
- `cka_sim::blueprint::validate <manifest_path>` — count==17, weights present, no duplicates (used by lint and runtime)
- `cka_sim::blueprint::estimated_minutes_sum` — return sum from in-memory parsed list

**`lib/exam-report.sh`** (Markdown rendering):
- `cka_sim::report::render <session_json_path> <output_md_path>` — top-level
- `cka_sim::report::header` — title, blueprint, started/completed/duration, total/pass-fail
- `cka_sim::report::domain_table` — domain breakdown sorted percentage-asc
- `cka_sim::report::trap_table` — top-5 raw count
- `cka_sim::report::next_drills` — bottom-3 weak domains
- `cka_sim::report::question_detail` — full Q-by-Q table
- `cka_sim::report::compute_total` — sum (q_score/q_max)*weight per domain → /100

**`lib/exam-timer.sh`** (background timer):
- `cka_sim::timer::spawn <deadline_ts>` — fork subshell, return PID into $CKA_SIM_TIMER_PID
- `cka_sim::timer::stop` — kill -TERM $CKA_SIM_TIMER_PID; wait
- `cka_sim::timer::redraw_loop` — internal subshell function: every 1s `tput sc; tput cup ...; printf '⏱ %s'; tput rc`

### exams/ directory

```
exams/
└── blueprint-alpha/
    ├── manifest.yaml      # exam metadata + 17 question references
    └── README.md          # candidate-facing intro + MOCK-03 disclaimer
```

`exams/` lives at repo root alongside `cka-sim/`, NOT inside `cka-sim/`. Rationale: blueprints are top-level CKA artifacts that compose by reference from packs — semantically equivalent to `mock-exams/` (the existing superseded one). Keeps the candidate's mental model simple: "blueprints are here, packs are inside cka-sim."

This contradicts a possible read of MOCK-01 ("`exams/blueprint-alpha/manifest.yaml`") — confirmed: REQUIREMENTS.md says `exams/`, ROADMAP success criterion 3 confirms the same. Repo-root location.

---

## Critical Implementation Details

### 1. Timer subshell + `tput sc/rc`

**Status line at row = `$(tput lines)` minus 1, full width:**

```bash
cka_sim::timer::redraw_loop() {
  local deadline=$1
  local row col now remaining
  row=$(( $(tput lines) - 1 ))
  while :; do
    now=$(cka_sim::exam::now)
    remaining=$(( deadline - now ))
    (( remaining < 0 )) && remaining=0
    local hh=$(( remaining / 3600 ))
    local mm=$(( (remaining % 3600) / 60 ))
    local ss=$(( remaining % 60 ))
    tput sc                              # save cursor
    tput cup "$row" 0                    # move to status line
    tput el                              # clear to end of line
    printf '⏱  %02d:%02d:%02d remaining' "$hh" "$mm" "$ss"
    tput rc                              # restore cursor
    sleep 1
  done
}

cka_sim::timer::spawn() {
  local deadline="$1"
  cka_sim::timer::redraw_loop "$deadline" &
  CKA_SIM_TIMER_PID=$!
}
```

**Gotchas:**
- `tput sc/rc` work only on terminals supporting them (matches CKA exam env — bash on Ubuntu, xterm-256color). On dumb terminals the timer prints inline, ugly but functional. Don't bail.
- Terminal resize (SIGWINCH) — re-read `tput lines` on each tick (cheap).
- Narrow terminal: `tput cols < 30` → emit `⏱ HH:MM:SS` without "remaining" suffix.
- The timer subshell does NOT inherit traps from parent (per bash semantics). Its only failure mode is parent dying — `wait $!` in parent's EXIT trap kills it cleanly.
- Write to **stdout**, not stderr. Stderr is shared with grader subprocesses and would interleave.

### 2. Signal trap composition

```bash
# In cka_sim::exam::start_new and ::resume, before entering question loop:
trap 'cka_sim::exam::on_int' INT
trap 'cka_sim::exam::on_tstp' TSTP
trap 'cka_sim::exam::on_cont' CONT
trap 'cka_sim::exam::on_exit' EXIT
```

**INT handler:**
```bash
cka_sim::exam::on_int() {
  cka_sim::state::set_question_status "$CKA_SIM_EXAM_CUR_IDX" flagged
  cka_sim::state::save
  printf '\n\033[33m✓ Q%d flagged. Continuing…\033[0m\n' \
    "$CKA_SIM_EXAM_CUR_IDX" >&2
  # Do NOT exit — return to main loop. The current `read` was interrupted;
  # main loop re-prompts.
  return 0
}
```

**Critical:** bash delivers signals during built-in `read` by interrupting (returning non-zero rc). The main loop must `read || true` and check whether the question was flagged inside the trap. Pattern:

```bash
while :; do
  printf '> '
  read -r action || action="(signaled)"
  if [[ "$action" == "(signaled)" ]]; then
    # trap already updated state; re-prompt
    continue
  fi
  cka_sim::exam::handle_action "$action"
done
```

**TSTP handler — the tricky one:**
```bash
cka_sim::exam::on_tstp() {
  cka_sim::state::set_pause   # records paused_at
  cka_sim::state::save
  cka_sim::timer::stop        # kill timer subshell
  # Reset TSTP to default so kill -STOP propagates to us
  trap - TSTP
  kill -STOP $$
  # When user `fg`s, SIGCONT fires → on_cont trap below
  trap 'cka_sim::exam::on_tstp' TSTP   # re-arm
}

cka_sim::exam::on_cont() {
  cka_sim::state::add_pause_delta   # adds (now - paused_at) to paused_seconds, clears paused_at
  cka_sim::state::save
  cka_sim::timer::spawn "$CKA_SIM_EXAM_DEADLINE_TS"
  printf '\n\033[32m✓ Resumed.\033[0m\n' >&2
}
```

Pause works because `kill -STOP` halts the entire process group (including the timer subshell — bash sends STOP to job group). When the user `fg`s, the kernel sends SIGCONT to the group; our parent's CONT trap fires; child timer subshells are killed and respawned by us.

**The `paused_seconds` accumulator** is what makes the timer look "paused" — when re-spawned, it computes `deadline_ts - now() + paused_seconds`, so wall-clock time spent paused is added back.

Wait — that's wrong. If `deadline_ts` is set absolutely at exam start, then `remaining = deadline_ts - now()` decrements whether or not we're paused. To pause, we need to *advance* the deadline by `(now - paused_at)` on resume:

```bash
cka_sim::exam::on_cont() {
  local pause_delta
  pause_delta=$(( $(cka_sim::exam::now) - CKA_SIM_EXAM_PAUSED_AT ))
  CKA_SIM_EXAM_DEADLINE_TS=$(( CKA_SIM_EXAM_DEADLINE_TS + pause_delta ))
  cka_sim::state::add_pause_delta "$pause_delta"   # add to total paused_seconds
  cka_sim::state::save
  cka_sim::timer::spawn "$CKA_SIM_EXAM_DEADLINE_TS"
}
```

Now the timer just runs `deadline_ts - now()` and never knows about pauses. The `paused_seconds` field in JSON exists for audit (how long was the candidate paused total) but isn't load-bearing for arithmetic.

### 3. Atomic JSON write

```bash
cka_sim::state::save() {
  local tmp
  tmp=$(mktemp -t "cka-sim-state.XXXXXX")
  # Marshal in-memory state → JSON via jq invocations (incremental updates)
  jq -n \
    --arg version 1 \
    --arg blueprint_id "$CKA_SIM_EXAM_BLUEPRINT_ID" \
    --argjson questions "$CKA_SIM_EXAM_QUESTIONS_JSON" \
    '{ version: $version, blueprint: { id: $blueprint_id }, ...}' \
    > "$tmp"
  # Validate before move
  jq empty "$tmp" 2>/dev/null || { rm -f "$tmp"; die "state save: invalid JSON"; }
  mv -f "$tmp" "$(cka_sim::state::session_path "$CKA_SIM_EXAM_TS")"
}
```

**On failure:**
- `mktemp` fails → die with disk-space error.
- `jq` fails → tmp is invalid → caught by `jq empty` → die without overwriting state.
- `mv` fails (very rare on same filesystem) → die; original state intact.

**Schema versioning:**
- Top-level `version: 1`. On read, fail fast if version unknown.
- Future migrations get a `cka_sim::state::migrate_v1_to_v2` style function.

### 4. `Trap N: <id>: <desc>` parsing

Graders emit lines like:
```
Trap 1: service-selector-label-mismatch: Service selector does not match Pod labels
```

Parser:
```bash
cka_sim::state::parse_traps() {
  local capture="$1"
  # awk extracts the trap id (2nd colon-delimited field after "Trap N")
  printf '%s\n' "$capture" \
    | grep -E '^Trap [0-9]+:' \
    | awk -F': *' '{print $2}'    # → just the id, one per line
}
```

This emits all trap IDs (with duplicates if a grader recorded the same trap twice — the raw count we want per D-24).

### 5. Per-question grader capture

Each grader runs in its own subprocess with its own stdout. Capture into a tempfile:

```bash
cka_sim::exam::grade_question() {
  local idx="$1" qdir="$2"
  local tmp
  tmp=$(mktemp -t "cka-sim-grade.XXXXXX")
  local rc=0
  # IMPORTANT: redirect both stdout AND stderr — graders use stderr for the live ✓/✗
  # progress (lib/grade.sh), and we want the full record. But: we ALSO want the candidate
  # to see the ✓/✗ live during batch grade. Solution: tee to both tmp and stderr.
  bash "$qdir/grade.sh" 2> >(tee -a "$tmp" >&2) > >(tee -a "$tmp")
  rc=$?
  # ^ This is fine because grade.sh routes the SCORE/Trap N block to stdout
  # and ✓/✗ progress to stderr (per Phase 2 grader contract).
  cka_sim::state::record_grade "$idx" "$rc" "$(cat "$tmp")"
  rm -f "$tmp"
}
```

Wait, that has a SIGPIPE risk per Phase 3 Pitfall 1. Better:

```bash
cka_sim::exam::grade_question() {
  local idx="$1" qdir="$2"
  local tmp
  tmp=$(mktemp -t "cka-sim-grade.XXXXXX")
  local rc=0
  bash "$qdir/grade.sh" >"$tmp" 2>>"$tmp" || rc=$?
  cat "$tmp" >&2   # show to candidate
  cka_sim::state::record_grade "$idx" "$rc" "$(cat "$tmp")"
  cka_sim::state::transcript_append "$idx" "$(< "$tmp")"
  rm -f "$tmp"
}
```

Mixing stdout+stderr into one tempfile loses the channel split, but for batch grading we want the candidate to see what the grader said anyway, and we parse SCORE/Trap from stdout-format (which is unique enough to grep without channel separation).

### 6. End-of-exam batch grade ordering

Run grades in question-idx order (deterministic). For questions marked `skipped`, do NOT run grade.sh — record `skipped` with score 0/max. For `flagged` and `answered` (the candidate pressed Enter), run grade.sh against the still-set-up lab namespace (per D-11, no inter-question reset).

### 7. Resume mechanics (RUN-05)

```bash
cka_sim::exam::resume() {
  local ts="$1"
  cka_sim::state::load "$ts"
  # Time check
  local now expired
  now=$(cka_sim::exam::now)
  if (( now > CKA_SIM_EXAM_DEADLINE_TS )); then
    expired=$(( now - CKA_SIM_EXAM_DEADLINE_TS ))
    warn "Exam expired ${expired}s ago — running batch grade for completed questions"
    cka_sim::exam::batch_grade
    cka_sim::report::render "$(cka_sim::state::session_path "$ts")" \
      "$(cka_sim::state::report_path "$ts")"
    exit 0
  fi
  # Re-setup current question
  local cur_idx="$CKA_SIM_EXAM_CUR_IDX"
  local qdir="$(cka_sim::blueprint::resolve_question \
    "${CKA_SIM_EXAM_QUESTIONS_PACK[$cur_idx]}" \
    "${CKA_SIM_EXAM_QUESTIONS_SLUG[$cur_idx]}")"
  bash "$qdir/reset.sh"
  bash "$qdir/setup.sh"
  # Spawn timer with the (possibly pause-shifted) deadline
  cka_sim::timer::spawn "$CKA_SIM_EXAM_DEADLINE_TS"
  cka_sim::exam::question_loop "$cur_idx"
}
```

---

## Pitfalls

1. **Atomic mktemp+mv (Phase 3 Pitfall 1)** — already covered above. Never `tee` JSON state. Never write directly to the final path.

2. **Graders self-source lib/grade.sh + lib/traps.sh (Phase 3 Pitfall 5)** — exam.sh does NOT source these. It runs `bash <path>/grade.sh` as a subprocess, just like drill.sh. The grader inherits CKA_SIM_ROOT and sources its own helpers.

3. **Bash signals during `read`** — INT delivered during `read` returns non-zero from read; main loop must handle the signaled-out-of-read case. Tested in `tests/exam/signal_handlers.sh`.

4. **Trap re-entrancy** — bash traps are NOT re-entrant. If INT fires while in the INT handler, the second INT is ignored. Acceptable: candidate hammering Ctrl-C just flags once.

5. **TSTP without re-arming the trap** — `trap - TSTP` resets to default (SIGSTOP), then we re-arm after kill. If we forget to re-arm, the next Ctrl-Z bypasses our handler.

6. **tput corruption from grader output** — graders write to stderr (`✓`/`✗` lines from lib/grade.sh). During the question prompt phase, the timer subshell writes to stdout at row=lines-1. As long as graders are NOT running during the prompt phase (they're not — batch grading at end), there's no overlap. But if a candidate runs a kubectl command in another shell, our timer redraws don't interfere. Document: candidate runs cluster commands in a separate shell.

7. **JSON corruption on Ctrl-C mid-write** — mktemp+mv defeats this. The state file is either old or new, never partial.

8. **Locale sort issues** — `LC_ALL=C` for any sort that compares percentages. Pattern: `LC_ALL=C sort -t '|' -k 4 -g` for numeric sort.

9. **No inter-question reset (D-11) — verify safety:**
   - Each question uses `cka-sim-<pack>-NN` lab namespace per TRIP-03 → no namespace collision.
   - Cluster-scoped objects use prefixes like `q07-cr-viewer` per TRIP-03 → no collision.
   - Host-level mutations (kubelet flag files, etc.) use sandbox `/tmp/qNN-*` paths → no collision.
   - **One concern:** if Q1 leaves a CRD installed and Q2 doesn't expect it, Q2's grade.sh might pass spuriously. Mitigation: graders use behavioral assertions (TRIP-04 mandate), not "object exists" checks. Cross-pack contamination would require very specific bug; document as known limitation.

10. **Blueprint estimated-minutes sum drift from MOCK-01** — D-15 documents this. Lint checks [120, 130]; manifest README explains; ROADMAP amendment in Phase 8.

11. **Empty home dir / first run** — `~/.cka-sim/sessions/` may not exist. `mkdir -p` with mode 0700 on first session creation.

12. **Concurrent exams** — two `cka-sim exam` instances would clobber each other's session files (different `<ts>` filenames, but they'd both touch the cluster). Detect via lockfile? Out of scope — single candidate, single cluster (per PROJECT.md "Single-learner mode"). Document as undefined behavior.

13. **Date arithmetic in pure bash** — `date +%s` is GNU coreutils on Ubuntu, fine. `date -d` for human-readable rendering in reports: `date -d "@$(jq -r .started_at session.json)"`.

14. **jq jq jq** — every state read goes through jq. Verify via `cka_sim::preflight::check_jq` at exam start. Already required by BOOT-07 (doctor).

15. **Exit code propagation** — if exam exits with a nonzero rc inside main, the EXIT trap should still persist state. Use `local rc=$?; cka_sim::state::save; exit $rc`.

---

## Blueprint-alpha Question Selection

Constraints: per-domain counts 2/3/3/4/5 (storage/workloads/SN/cluster-arch/trouble), 17 total, sum estimatedMinutes ∈ [120, 130], no two adjacent same-domain.

### Pack inventory recap

```
storage (6 questions, 7-9 min each):
  01-pvc-binding(8) 02-storageclass-dynamic(7) 03-access-modes-reclaim(9)
  04-csi-volumesnapshot(9) 05-wait-for-first-consumer(7) 06-pvc-mount-pod(7)

workloads-scheduling (8 questions, 7-9 min each):
  01-deployment-requests(7) 02-rolling-update-rollback(7) 03-configmap-secret-env-volume(8)
  04-hpa-metrics-server(9) 05-daemonset(7) 06-static-pod(8)
  07-native-sidecar(8) 08-nodeselector-affinity-taints(9)

services-networking (6 questions, 7-9 min each):
  01-networkpolicy-egress(9) 02-service-core(7) 03-coredns-resolution(7)
  04-ingress-path-host(8) 05-kube-proxy-mode(8) 06-netpol-endport(7)

cluster-architecture (8 questions, 6-10 min each):
  01-rbac-viewer(8) 02-etcd-backup-restore(10) 03-kubeadm-upgrade(10)
  04-pss-enforce(9) 05-audit-policy(9) 06-crd-basics(6)
  07-cri-dockerd-endpoint(8) 08-priorityclass(7)

troubleshooting (6 questions, 7-11 min each):
  01-deploy-svc-mismatch(7) 02-netpol-dns-egress(8) 03-coredns-resolution(8)
  04-debug-node(9) 05-static-pod-manifest(10) 06-broken-kubelet(11)
```

### Recommended draw

| # | pack | slug | est min | domain |
|---|---|---|---|---|
| 1 | storage | 01-pvc-binding | 8 | storage |
| 2 | troubleshooting | 01-deploy-svc-mismatch | 7 | trouble |
| 3 | workloads-scheduling | 02-rolling-update-rollback | 7 | workloads |
| 4 | services-networking | 02-service-core | 7 | s&n |
| 5 | cluster-architecture | 06-crd-basics | 6 | cluster-arch |
| 6 | troubleshooting | 02-netpol-dns-egress | 8 | trouble |
| 7 | workloads-scheduling | 04-hpa-metrics-server | 9 | workloads |
| 8 | services-networking | 06-netpol-endport | 7 | s&n |
| 9 | cluster-architecture | 04-pss-enforce | 9 | cluster-arch |
| 10 | troubleshooting | 04-debug-node | 9 | trouble |
| 11 | storage | 04-csi-volumesnapshot | 9 | storage |
| 12 | cluster-architecture | 07-cri-dockerd-endpoint | 8 | cluster-arch |
| 13 | workloads-scheduling | 07-native-sidecar | 8 | workloads |
| 14 | troubleshooting | 05-static-pod-manifest | 10 | trouble |
| 15 | services-networking | 05-kube-proxy-mode | 8 | s&n |
| 16 | cluster-architecture | 02-etcd-backup-restore | 10 | cluster-arch |
| 17 | troubleshooting | 06-broken-kubelet | 11 | trouble |

**Sum: 8+7+7+7+6+8+9+7+9+9+9+8+8+10+8+10+11 = 131 min**

That's 1 over the [120,130] window I documented. Let me re-balance: swap Q17 (broken-kubelet, 11) for trouble 03-coredns-resolution (8) — gives 128. But broken-kubelet is a marquee scenario; better to swap Q14 (static-pod, 10) for trouble 03-coredns (8) → 129 total.

**Final draw — sum 129 min:**

| # | pack | slug | est min | domain |
|---|---|---|---|---|
| 1 | storage | 01-pvc-binding | 8 | storage |
| 2 | troubleshooting | 01-deploy-svc-mismatch | 7 | trouble |
| 3 | workloads-scheduling | 02-rolling-update-rollback | 7 | workloads |
| 4 | services-networking | 02-service-core | 7 | s&n |
| 5 | cluster-architecture | 06-crd-basics | 6 | cluster-arch |
| 6 | troubleshooting | 02-netpol-dns-egress | 8 | trouble |
| 7 | workloads-scheduling | 04-hpa-metrics-server | 9 | workloads |
| 8 | services-networking | 06-netpol-endport | 7 | s&n |
| 9 | cluster-architecture | 04-pss-enforce | 9 | cluster-arch |
| 10 | troubleshooting | 04-debug-node | 9 | trouble |
| 11 | storage | 04-csi-volumesnapshot | 9 | storage |
| 12 | cluster-architecture | 07-cri-dockerd-endpoint | 8 | cluster-arch |
| 13 | workloads-scheduling | 07-native-sidecar | 8 | workloads |
| 14 | troubleshooting | 03-coredns-resolution | 8 | trouble |
| 15 | services-networking | 05-kube-proxy-mode | 8 | s&n |
| 16 | cluster-architecture | 02-etcd-backup-restore | 10 | cluster-arch |
| 17 | troubleshooting | 06-broken-kubelet | 11 | trouble |

**Verification:**
- Sum: 8+7+7+7+6+8+9+7+9+9+9+8+8+8+8+10+11 = **129 min** ✓ (in [120,130])
- Counts: storage 2 (#1,11) ✓; workloads 3 (#3,7,13) ✓; s&n 3 (#4,8,15) ✓; cluster-arch 4 (#5,9,12,16) ✓; trouble 5 (#2,6,10,14,17) ✓
- Adjacency: no two consecutive same-domain ✓
- Coverage breadth: includes csi-volumesnapshot (CG-01), hpa-metrics-server (CG-06), native-sidecar (CG-08), pss-enforce (CG-10), cri-dockerd (CG-13), kube-proxy-mode (CG-15), netpol-endport (CG-16), crd-basics (CG-12) — all the marquee v1.35 content-replacements

The planner is free to refine specific picks within the per-domain counts (per D-17 Claude's discretion), but this draw satisfies all constraints.

---

## Test Strategy

### tests/exam/ case files

```
tests/exam/exam_end_to_end.sh         — mock graders, assert session.json shape
tests/exam/exam_resume_after_int.sh   — SIGINT mid-Q, then --resume, verify state
tests/exam/exam_resume_after_kill.sh  — SIGTERM, then --resume
tests/exam/signal_handlers.sh         — INT/TSTP/EXIT all fire correctly
tests/exam/timer_render.sh            — timer subshell emits HH:MM:SS, decrements
tests/exam/state_atomic_write.sh      — assert mktemp+mv (no partial writes via inject failure)
tests/exam/state_schema.sh            — version check, jq -e on required fields
tests/exam/blueprint_load.sh          — parse manifest, resolve question paths
tests/exam/blueprint_validate.sh      — count, weights, no-dupes, sum range
tests/exam/report_golden.sh           — fixture session → diff against expected report
tests/exam/score_command.sh           — score <ts> reads + prints; regenerates if missing
tests/exam/list_history.sh            — list history walks sessions dir
```

### Fixtures

```
tests/fixtures/exam/
├── mock-pack-alpha/                  # 17-question synthetic pack
│   └── 01-fake/.. 17-fake/           # each with no-op setup, scripted grade
├── blueprint-mock-alpha.yaml         # 17 references to mock-pack-alpha
├── session-fixture.json              # fully-populated post-exam session (deterministic scores)
├── expected-report.md                # golden output from session-fixture.json
└── traps-mock-catalog.yaml           # known trap IDs for the report's trap table
```

### lint-packs.sh extension (pass H)

Add a new pass after the existing 7 passes:

```bash
info "pass H: blueprint manifest lint"
EXAMS_DIR="${CKA_SIM_LINT_EXAMS_DIR:-$REPO_ROOT/exams}"
if [[ -d "$EXAMS_DIR" ]]; then
  while IFS= read -r manifest; do
    cka_sim::lint_blueprint "$manifest"
  done < <(find "$EXAMS_DIR" -mindepth 2 -name manifest.yaml)
fi
```

`cka_sim::lint_blueprint` checks: count==17, weights present + values match 10/30/15/25/20, every (pack, slug) resolves to existing question dir, no duplicates, sum estimatedMinutes ∈ [120,130], README.md disclaimer string present, manifest exam.disclaimer present.

---

## CI Integration

- `cka-sim/scripts/test.sh` already invokes `lint-packs.sh` — extending lint-packs.sh with pass H means CI picks up blueprint validation automatically.
- `cka-sim/tests/run.sh` walks `tests/cases/` — add `tests/exam/*.sh` files to that list (or extend run.sh to walk `tests/{cases,exam}/`).
- `.github/workflows/validate.yml` already runs shellcheck on `cka-sim/**/*.sh` (per Phase 5/6 CI extensions). New files automatically covered.
- No new GHA jobs needed.

---

## Open Questions

(None blocking. The planner can decide these at task-level granularity.)

1. **Question UI menu key bindings** — D-14 says `[Enter]/f/s/n/p/q`. `n` (next) and `p` (prev) imply non-linear navigation through the 17 questions — the candidate can `p` back to a flagged question and revise. This needs a navigation index in state.json (`navigation_history: []`?) — leave to planner. Alternative: `f` flags + advances; `s` skips + advances; no `p` (only forward navigation). Simpler. Recommend the planner pick the simpler model unless there's a strong reason otherwise.

2. **Display of "remaining" when paused** — show `⏱ PAUSED (HH:MM:SS will resume)` or just `⏱ PAUSED`? Cosmetic, planner's call.

3. **Timer color thresholds** — go yellow at 30 min, red at 5 min? Cosmetic.

---

## RESEARCH COMPLETE

Phase 7 architecture is well-bounded by CONTEXT.md. Implementation risk concentrates in (1) signal trap composition, (2) atomic JSON state writes, and (3) the timer subshell's interaction with grader subprocess output. All three have proven patterns from prior phases (Phase 3 atomic-write, Phase 1 signal handling in bootstrap.sh) plus standard bash idioms documented above.

Recommended execution order for the planner:
1. Foundation: `lib/exam-state.sh` + `lib/exam-blueprint.sh` (pure, testable)
2. Render: `lib/exam-report.sh` (pure, golden-file testable)
3. Runtime: `lib/exam-timer.sh` + `lib/cmd/exam.sh` orchestrator (signal-heavy, hardest)
4. Adjacent commands: `lib/cmd/score.sh` + extend `lib/cmd/list.sh` (thin wrappers)
5. Content: `exams/blueprint-alpha/manifest.yaml` + README
6. Lint: `scripts/lint-packs.sh` pass H
7. Tests: `tests/exam/` + fixtures

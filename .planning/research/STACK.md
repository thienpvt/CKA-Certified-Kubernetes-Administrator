# Stack Research — CKA Exam Simulator Runner

**Domain:** Bash-only kubectl-driven exam-simulator runner targeting a self-hosted kubeadm Kubernetes 1.35 cluster on Ubuntu 22.04 / GCP
**Researched:** 2026-05-07
**Verified against v1.0 milestone scope on 2026-05-07** — Ubuntu 22.04, kubeadm 1.35, 1+2 GCP, bash-only runner, 5 domain packs + 2 mock-exam packs, 31 existing exercises kept as reference-only. No stack changes required.
**Overall confidence:** HIGH for bash/kubectl/SSH idioms (decade-stable territory); MEDIUM for tool-version pins (no live web verification this session — see "Verification gaps" below)

---

## Executive summary

The constraint set in `.planning/PROJECT.md` is unusually tight and unusually well-justified: pure Bash + the binaries that already ship on Ubuntu 22.04 and the kubeadm-installed Kubernetes 1.35 toolchain, no Go/Python CLI runtime, no cloud SDK, no extra runtime dependency the candidate has to install on exam day. That constraint maps cleanly onto a well-understood toolset:

- **Runner core:** `bash` (Ubuntu 22.04 ships GNU bash 5.1) with `set -euo pipefail` discipline, `kubectl wait` for state convergence, `kubectl get -o jsonpath=` and `kubectl auth can-i` for grading, structured stdout/stderr separation, exit-code conventions, `mktemp -d` for per-question scratch dirs.
- **Timer / TUI:** stay bash-pure — `date +%s` for clocks, `tput` for cursor / clear / colors, `read -t` for non-blocking input, optional `whiptail` (already in `whiptail` / `libnewt0.52` on Ubuntu 22.04) for menu + flag/skip UX, `timeout` for any external command that must not hang grading.
- **Grading helpers:** `jq` and `yq` (mikefarah Go binary) are the only two non-stdlib tools that earn their keep — both are single static binaries the candidate fetches once during cluster bootstrap, both are also broadly used in real CKA prep.
- **SSH topology:** stock OpenSSH on Ubuntu 22.04 — `ssh-keygen -t ed25519`, `~/.ssh/config` `Host node-01 / node-02 / node-03` stanzas, public-key push via `ssh-copy-id` or a one-shot `kubectl cp` / `scp` loop driven by the bootstrap script. No new SSH framework.
- **Distribution:** plain `cka-sim` script in `~/.local/bin/` or `/usr/local/bin/` (added to PATH by the bootstrap script). No krew plugin, no Homebrew tap, no installer DSL — a single `install.sh` that copies files and chmod +x's the entry point.
- **Self-test:** `bats-core` (bash-only test framework) for testing the runner itself (not the question content) + `shellcheck` in CI. Both are dev-only, never installed on the exam VM.

The stack has effectively no novelty risk. Every component is widely deployed, decade-stable, and present in Ubuntu's main archive (or a single-binary download). The trap-aware grader is a *pattern*, not a new dependency — it is just disciplined `kubectl` + `jq` plumbing in `grade.sh`.

---

## Recommended Stack

### Core technologies

| Technology | Version | Purpose | Why recommended |
|------------|---------|---------|-----------------|
| **GNU bash** | 5.1.x (Ubuntu 22.04 default; 5.2 acceptable) | Runner language, setup/grade/reset scripts, CLI dispatcher | Already on every target VM. PROJECT.md hard-rules out Go/Python. Bash 5.1 is the floor we can assume — `mapfile`, `${var,,}` lowercase, associative arrays, `read -t` fractional seconds, all available. Don't dip below 4.4 (no associative-array key-existence test) or above 5.2 (Ubuntu 22.04 won't have it). HIGH confidence. |
| **kubectl** | v1.35.x (matching server minor) | Sole cluster API surface for setup/grade/reset | The "API" of the entire runner. Pin client minor to server minor (kubectl supports +/- 1 minor skew but exam realism wants exact match). Installed via the kubeadm/`pkgs.k8s.io` apt repo — same source the candidate already uses. HIGH confidence. |
| **Kubernetes** | v1.35 stable (cluster pre-existing) | Target cluster | Set by PROJECT.md and the existing CKA v1.35 syllabus. The simulator must not assume features only available in 1.36+ alphas. HIGH confidence on the version pin; MEDIUM on exact patch level — verify against the kubeadm release the candidate installed. |
| **OpenSSH client + server** | Ubuntu 22.04 stock (OpenSSH 8.9p1) | `ssh node-NN`, `scp`, `ssh-copy-id`, key distribution | The exam-fidelity feature: PSI's environment lets the candidate `ssh node-01` from the student terminal. We replicate that with stock OpenSSH and `~/.ssh/config` Host stanzas. No third-party SSH wrapper. HIGH confidence. |
| **etcdctl** | v3.5.x (matches the etcd shipped by kubeadm 1.35) | Backup/restore lab grading; cluster-architecture domain coverage | Already on the control-plane node via the static-pod image; `crictl exec` or extracted to `/usr/local/bin/etcdctl` in bootstrap. `ETCDCTL_API=3` already exported by `scripts/exam-setup.sh`. HIGH confidence. |
| **crictl** | v1.35.x (CRI compat range with containerd 1.7+) | Pod/container debugging on nodes (`crictl ps`, `crictl logs`) | Replaces the misleading `docker` aliases currently in `exam-setup.sh` (flagged in CONCERNS.md). The CKA exam uses containerd, so `crictl` is what the grader and the candidate both use. HIGH confidence. |
| **kubeadm** | v1.35.x | Read-only in scope (cluster already exists); used only by upgrade/cluster-architecture grading scenarios | PROJECT.md is explicit that we do *not* bootstrap clusters. We do read kubeadm config (`/etc/kubernetes/admin.conf`, `/var/lib/kubelet/kubeadm-flags.env`) for grading. HIGH confidence. |

### Supporting binaries (single-static-binary tier)

These are the only two tools beyond the kubeadm/apt stack that the runner depends on. Both fetched during cluster bootstrap and pinned to a known release. Both ubiquitous in real CKA prep, so no surprise for the candidate.

| Tool | Version | Purpose | When to use |
|------|---------|---------|-------------|
| **jq** | 1.7.1 (apt: `jq` in jammy-updates) | JSON parsing of `kubectl ... -o json` for graders too gnarly for jsonpath | Every grader that has to walk a Pod's `.status.containerStatuses[*].state` map, or count items, or assert on multiple fields at once. jsonpath chokes on these; `jq` is the right tool. Single C binary; no plugin model. HIGH confidence. |
| **yq** (mikefarah, Go-based v4) | 4.44.x | YAML parsing, in-place YAML edits in `setup.sh` (e.g. break a known field on a manifest) | Specifically the **mikefarah** Go binary. NOT the Python `yq` (different syntax, requires Python). Fetched as a single static binary from `https://github.com/mikefarah/yq/releases/`. HIGH confidence on the choice; MEDIUM on the exact pin — use the latest 4.x at bootstrap time. |

### Built-in / coreutils tier (zero extra install)

Already on every Ubuntu 22.04 VM. Listed because the grading scripts will lean on them hard.

| Tool | Purpose | Notes |
|------|---------|-------|
| `timeout` (coreutils) | Wrap any kubectl call that might hang (e.g. `kubectl wait` with a misbehaving controller) | `timeout 30s kubectl wait ...` is the canonical pattern. Don't reinvent. |
| `tput` (ncurses-bin) | Terminal capability queries: clear screen, colors, cursor positioning for the timer | `tput cup` for fixed-position timer redraw, `tput setaf 1` for red FAIL. Avoids hard-coded ANSI escape strings. |
| `read -t N` (bash builtin) | Non-blocking input for the exam TUI ("press F to flag, S to skip, ENTER to grade") | Lets the timer redraw between keystrokes without `select` or `expect`. |
| `mktemp -d` | Per-question scratch dir, auto-cleaned on `trap EXIT` | Standard for any setup that must not leak state. |
| `mkfifo` | Optional event stream between timer (background) and main runner (foreground) | Only if we want the timer in a child process. Most question runs won't need it; the simpler approach is one foreground loop redrawing the clock between user inputs. |
| `whiptail` (libnewt) | Optional TUI menus for `cka-sim drill <pack>` question picker, end-of-exam "Review flagged?" prompt | Already in Ubuntu main; `whiptail --menu`, `whiptail --checklist`. Pure curses, no Python. **Optional** — a plain numbered prompt works equally well and is more exam-realistic. |
| `getopts` (bash builtin) | CLI argument parsing for `cka-sim drill -p storage -n 5` | Don't reach for `argbash` / external parsers. The flag surface is tiny. |
| `ssh-keygen`, `ssh-copy-id`, `scp` | SSH bootstrap | Stock OpenSSH. The bootstrap script generates an ed25519 key on the control-plane and pushes it to workers. |

### Development / CI tier (NOT installed on the exam VM)

These tools test the runner; the candidate never sees them at exam time. Lives in CI and contributor laptops.

| Tool | Version | Purpose | Notes |
|------|---------|---------|-------|
| **bats-core** | 1.11.x | Unit tests for the runner CLI: argument parsing, scoring math, trap-detection helpers, score-report rendering | Bash-only test framework; runs as `bats tests/`. Tests the *runner*, not the questions (questions are integration-tested by running them against a real kubeadm cluster, which we do manually or in a future kind-based CI lane). MEDIUM-HIGH confidence — bats-core is the de facto bash test framework but adopt it sparingly to avoid framework lock-in for content authors. |
| **shellcheck** | 0.10.x (apt: `shellcheck`) | Static analysis of every `.sh` in the repo | Already a CI table-stake for any bash project. Catches the `--container-runtime=remote`-class bugs that CONCERNS.md flagged in the existing scripts. Run via `shellcheck -x questions/**/*.sh scripts/*.sh runner/*.sh`. HIGH confidence. |
| **yamllint** | already in repo CI; pin a version this time (e.g. `1.35.0`) | YAML style on every fixture | CONCERNS.md flagged that the existing CI doesn't pin yamllint — fix that here. HIGH confidence. |
| **kubeconform** | 0.6.7 | Schema-validate manifests in `setup.sh` against the v1.35 OpenAPI schema | Optional but cheap insurance — catches typos in fixture YAML before a candidate hits them mid-question. Single Go binary, used only in CI. MEDIUM confidence: nice-to-have, not table-stakes. |

---

## Idiomatic patterns (these are the actual recommendations)

### Pattern 1 — `setup.sh` shape

```bash
#!/usr/bin/env bash
# Question 04-rbac-readonly: candidate must create a ClusterRole + RoleBinding
# that lets user 'auditor' read pods cluster-wide but nothing else.
# Idempotent: safe to re-run.
set -euo pipefail

NS="exam-04"
trap 'rc=$?; echo "[setup] exit $rc" >&2' EXIT

# Idempotent namespace
kubectl get ns "$NS" >/dev/null 2>&1 \
  || kubectl create ns "$NS"

# Idempotent fixture pod — replace if drifted
kubectl -n "$NS" apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata: { name: target, labels: { app: target } }
spec:
  containers: [ { name: c, image: nginx:1.28 } ]
YAML

kubectl -n "$NS" wait --for=condition=Ready pod/target --timeout=60s

echo "[setup] ready: ns=$NS pod=target"
```

Key idioms (all HIGH confidence):
1. `set -euo pipefail` on every `setup.sh` and `grade.sh`. **Not** on `reset.sh` — reset must continue past errors so a half-broken state still gets cleaned up; use `set -u` only.
2. `kubectl ... apply -f -` with heredoc beats `kubectl create` for idempotency.
3. `kubectl wait --for=condition=Ready` with `--timeout` is the only safe way to converge — never `sleep N`.
4. Namespace per question: `exam-NN` (mirrors the existing `exercise-NN` convention from `.planning/codebase/CONVENTIONS.md`). The grader can wipe the whole namespace at reset time.
5. `trap '...' EXIT` for cleanup of temp files (when present); always emit a final status line on stderr so the runner can log it.

### Pattern 2 — `grade.sh` shape with trap diagnostics

```bash
#!/usr/bin/env bash
# Grader for 04-rbac-readonly. Emits 0=pass, 1=fail.
# On fail, prints "Trap N: <description>" lines for each detected mistake class.
set -uo pipefail   # NOT -e: we WANT to keep checking after a failed assertion

NS="exam-04"
score=0; max=3
declare -a TRAPS=()

# Check 1: ClusterRole exists with right verbs/resources
if kubectl get clusterrole pod-reader -o jsonpath='{.rules[0].verbs}' 2>/dev/null \
     | grep -qw 'get'; then
  score=$((score+1))
else
  TRAPS+=("Trap 1: ClusterRole 'pod-reader' not found or missing 'get' verb")
fi

# Check 2: binding subject is correct (catches the --as=User: vs User= confusion)
subj_kind=$(kubectl get clusterrolebinding pod-reader-bind \
              -o jsonpath='{.subjects[0].kind}' 2>/dev/null || true)
if [[ "$subj_kind" != "User" ]]; then
  TRAPS+=("Trap 2: subject kind is '$subj_kind', expected 'User' (did you use 'ServiceAccount' instead?)")
fi

# Check 3: Effective auth — the ground truth
if kubectl auth can-i get pods --as=auditor -A >/dev/null 2>&1; then
  score=$((score+1))
else
  TRAPS+=("Trap 3: 'kubectl auth can-i get pods --as=auditor -A' returns no — check binding scope (Role vs ClusterRole)")
fi

# Check 4: negative auth — auditor must NOT be able to delete
if kubectl auth can-i delete pods --as=auditor -A >/dev/null 2>&1; then
  TRAPS+=("Trap 4: auditor can DELETE pods — your ClusterRole verbs are too broad")
else
  score=$((score+1))
fi

# Emit structured result
echo "SCORE: $score/$max"
if (( ${#TRAPS[@]} > 0 )); then
  printf '%s\n' "${TRAPS[@]}"
  exit 1
fi
exit 0
```

Key idioms (HIGH confidence):
1. `set -uo pipefail` (no `-e`) so a failed check doesn't abort grading — we want to collect ALL traps in one pass.
2. **`kubectl auth can-i ... --as=<user> -A`** is the ground-truth RBAC check. Always include it, even when you've already inspected the role. It catches binding-scope errors that role-shape inspection misses. (CONCERNS.md flagged that learners get the `--as=` form wrong — graders should print the correct form on failure.)
3. **Negative checks count as much as positive checks** — "auditor can NOT delete" is a check, with its own trap. This is what makes the grader trap-aware rather than just pass/fail.
4. `jsonpath='{.subjects[0].kind}'` for narrow extraction; pipe to `jq` only when the path branches or arrays need filtering.
5. `score / max` line is structured for the runner to parse with a fixed regex (`^SCORE: ([0-9]+)/([0-9]+)$`). Trap lines start with `^Trap [0-9]+:` so the score-reporter can aggregate them across questions.
6. Exit code is binary (0 pass / 1 fail). The score line carries the partial credit; the runner aggregates partial credit into the 100-point exam total.

### Pattern 3 — `reset.sh` shape

```bash
#!/usr/bin/env bash
# Reset 04-rbac-readonly to a clean baseline. Best-effort; never aborts.
set -u

NS="exam-04"
kubectl delete ns "$NS"            --ignore-not-found --wait=false
kubectl delete clusterrole pod-reader      --ignore-not-found
kubectl delete clusterrolebinding pod-reader-bind --ignore-not-found
echo "[reset] ns=$NS cluster-scoped objects removed"
```

Key idioms (HIGH confidence):
1. `--ignore-not-found` is the idempotency lever. No `if kubectl get ... ; then delete ; fi` boilerplate.
2. `--wait=false` on namespace deletion — the runner moves on; the next setup will `kubectl get ns / create ns` idempotently anyway.
3. Cluster-scoped objects (ClusterRole, PV, PriorityClass, StorageClass, etc.) need explicit per-name deletes — namespace delete won't catch them. **This is a recurring trap** worth checking: every `setup.sh` that creates cluster-scoped state must have a corresponding `reset.sh` line.
4. No `set -e` in reset. Continue on errors.

### Pattern 4 — Runner CLI dispatch (`cka-sim`)

```bash
#!/usr/bin/env bash
set -euo pipefail
CKA_SIM_HOME="${CKA_SIM_HOME:-$HOME/.cka-sim}"
CKA_SIM_LIB="${CKA_SIM_LIB:-/usr/local/share/cka-sim}"

usage() {
  cat <<'EOF'
cka-sim drill <pack> [<n>]   # single-question domain practice
cka-sim exam  <pack>         # timed 17-question / 2-hour mock
cka-sim reset <pack>         # nuke all question state for a pack
cka-sim list                 # available packs and questions
EOF
}

cmd="${1:-}"; shift || true
case "$cmd" in
  drill) exec "$CKA_SIM_LIB/cmd/drill.sh" "$@" ;;
  exam)  exec "$CKA_SIM_LIB/cmd/exam.sh"  "$@" ;;
  reset) exec "$CKA_SIM_LIB/cmd/reset.sh" "$@" ;;
  list)  exec "$CKA_SIM_LIB/cmd/list.sh"  "$@" ;;
  -h|--help|"") usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
```

Key idioms (HIGH confidence):
1. **`exec` to subcommand scripts** — keeps each subcommand independently testable with `bats`, and means `cka-sim drill` is just `cmd/drill.sh` with the same args.
2. `CKA_SIM_HOME` for per-user state (current attempt log, score history); `CKA_SIM_LIB` for read-only library files. Two roots is the standard split (cf. XDG Base Dirs).
3. `getopts` inside each `cmd/*.sh` — top-level dispatcher only routes by first positional.
4. No `argparse`-style flag-with-help — the help text is hand-written in a heredoc. Keeps things bash-native.

### Pattern 5 — Timer + scoreboard TUI (bash-only, no `dialog`)

```bash
# Background timer, foreground question loop. End-of-exam: print Markdown report.
EXAM_START=$(date +%s)
EXAM_DURATION=$((2 * 60 * 60))   # 2 hours

draw_clock() {
  local now elapsed remaining mm ss
  now=$(date +%s)
  elapsed=$((now - EXAM_START))
  remaining=$((EXAM_DURATION - elapsed))
  (( remaining < 0 )) && remaining=0
  mm=$((remaining / 60)); ss=$((remaining % 60))
  printf '\033[s\033[1;1H\033[K[%02d:%02d remaining | Q %d/%d | flags: %d ]\033[u' \
         "$mm" "$ss" "$qno" "$qtotal" "${#FLAGGED[@]}"
}

# Per-question loop
while true; do
  draw_clock
  read -r -t 1 -n 1 key || { draw_clock; continue; }
  case "$key" in
    g) run_grade ; break ;;
    f) FLAGGED+=("$qno") ;;
    s) break ;;       # skip
    q) break 2 ;;     # quit exam
  esac
done
```

Key idioms (HIGH/MEDIUM confidence):
1. **`read -t 1 -n 1`** — 1-second blocking read on a single key. Lets the clock redraw every second without a separate timer process. Simpler than `mkfifo`.
2. **`\033[s ... \033[u`** — save / restore cursor. Lets the clock redraw at row 1 col 1 without disturbing the candidate's typing position. Same trick screen-saver tools use; portable across xterm / gnome-terminal / GCP serial console.
3. **`tput cols`** to get terminal width before drawing the score table — wrap or truncate gracefully.
4. End-of-exam Markdown report goes to *stdout* and to a file under `$CKA_SIM_HOME/attempts/<timestamp>.md`. Never overwrite — append-only history.

### Pattern 6 — SSH bootstrap topology

The candidate works from the control-plane node. The runner needs `ssh node-01` and `ssh node-02` to "just work" without a password — that is the PSI-fidelity feature.

```bash
# scripts/bootstrap-ssh.sh — run once, on the control-plane node.
set -euo pipefail
KEY="$HOME/.ssh/cka_sim_ed25519"

if [[ ! -f "$KEY" ]]; then
  ssh-keygen -t ed25519 -N '' -C "cka-sim@$(hostname)" -f "$KEY"
fi

# Discover workers via kubectl — no hard-coded IPs.
mapfile -t WORKERS < <(kubectl get nodes \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}' \
  | awk '$1 != cp_name')   # filter out control-plane by name from $(hostname)

# Write ~/.ssh/config stanzas (idempotent — keyed on Host alias)
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
{
  echo ""
  echo "# === cka-sim BEGIN (managed) ==="
  i=1
  for line in "${WORKERS[@]}"; do
    name=${line%% *}; ip=${line##* }
    cat <<EOF
Host node-0$i
  HostName $ip
  User $(whoami)
  IdentityFile $KEY
  StrictHostKeyChecking accept-new
EOF
    i=$((i+1))
  done
  echo "# === cka-sim END ==="
} > "$HOME/.ssh/config.cka-sim"

# Merge: remove old block, append fresh one
sed -i '/# === cka-sim BEGIN/,/# === cka-sim END/d' "$HOME/.ssh/config" 2>/dev/null || true
cat "$HOME/.ssh/config.cka-sim" >> "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"

# Push pubkey to workers (assumes existing GCP SSH access — typically via OS Login)
for line in "${WORKERS[@]}"; do
  ip=${line##* }
  ssh-copy-id -i "$KEY.pub" -o StrictHostKeyChecking=accept-new "$(whoami)@$ip"
done
```

Key idioms (HIGH confidence):
1. **ed25519 keys, not RSA.** Smaller, faster, OpenSSH 6.5+ (Ubuntu 22.04 trivially supports them).
2. **Discovery via `kubectl get nodes -o jsonpath`** — never hard-code IPs. Nodes get re-imaged; the kubeconfig is the source of truth.
3. **`Host node-01 / node-02 / node-03` aliases** — the simulator's whole UX promise is "from the control-plane, type `ssh node-01`". The Host stanzas deliver that. `node-NN` mirrors the convention already used informally throughout the existing exercises (per `.planning/codebase/CONVENTIONS.md`).
4. **Sentinel-comment-fenced block** in `~/.ssh/config` (`# === cka-sim BEGIN`/`END`) — makes the bootstrap idempotent without the duplicate-append bug that CONCERNS.md flagged in `exam-setup.sh`'s vimrc handling. **Apply the same sentinel pattern to the vimrc append fix.**
5. `StrictHostKeyChecking accept-new` — first connection is silent, subsequent connections are pinned. `no` would teach the candidate a bad habit.
6. **GCP-specific note:** if the candidate uses GCP OS Login, the bootstrap should detect it (`getent passwd "$(whoami)" | grep -q google`) and skip `ssh-copy-id` in favor of a `gcloud compute os-login ssh-keys add` fallback — but PROJECT.md scopes provisioning out, so the simpler path is "candidate must have plain SSH already working between CP and workers, then the script adds the cka-sim key."

### Pattern 7 — Grading helpers library

A thin `lib/assert.sh` sourced by every `grade.sh`, encoding the trap idiom once.

```bash
# lib/assert.sh — sourced by grade.sh; never executed directly.
TRAPS=()
SCORE=0
MAX=0

assert_kubectl() {
  # assert_kubectl <description> -- <kubectl args...> <pattern-to-grep>
  local desc=$1; shift
  MAX=$((MAX+1))
  local pattern=${@: -1}
  local args=("${@:1:$#-1}")
  if kubectl "${args[@]}" 2>/dev/null | grep -q -- "$pattern"; then
    SCORE=$((SCORE+1))
  else
    TRAPS+=("Trap $((${#TRAPS[@]}+1)): $desc")
  fi
}

assert_can_i() {
  # assert_can_i <user> <verb> <resource> [namespace]
  local user=$1 verb=$2 res=$3 ns=${4:--A}
  MAX=$((MAX+1))
  if [[ "$ns" == "-A" ]]; then
    kubectl auth can-i "$verb" "$res" --as="$user" -A >/dev/null 2>&1 \
      && SCORE=$((SCORE+1)) \
      || TRAPS+=("Trap $((${#TRAPS[@]}+1)): user '$user' cannot '$verb $res' (expected: yes)")
  else
    kubectl auth can-i "$verb" "$res" --as="$user" -n "$ns" >/dev/null 2>&1 \
      && SCORE=$((SCORE+1)) \
      || TRAPS+=("Trap $((${#TRAPS[@]}+1)): user '$user' cannot '$verb $res' in ns '$ns'")
  fi
}

emit_result() {
  echo "SCORE: $SCORE/$MAX"
  printf '%s\n' "${TRAPS[@]}"
  (( ${#TRAPS[@]} > 0 )) && exit 1 || exit 0
}
```

HIGH confidence. Centralizes the trap-counter and the SCORE format the runner depends on.

---

## Anti-features (explicitly rejected)

| Don't use | Why | Use instead |
|-----------|-----|-------------|
| **Go or Python for the runner** | PROJECT.md hard rule: must run on the exam VM with no extra installs. A Go binary would also break the "exam shell parity" feeling. | Pure bash + `jq` + mikefarah `yq`. |
| **`expect` / Tcl** | Adds a runtime; not in Ubuntu 22.04 main by default; brittle pattern-matching. | `read -t` + `kubectl wait`. The simulator never needs to drive an interactive subprocess. |
| **`dialog` (TUI)** | Heavier than `whiptail`, less common on minimal Ubuntu images, GPL — preference for the lighter `whiptail` which is already in `libnewt`. | `whiptail` if a TUI menu is needed at all; otherwise plain numbered prompts. |
| **Python `yq`** | Different command syntax from the Go `yq`; requires Python; CONCERNS.md already flags Python-on-Windows fragility for `validate-local.sh`. | mikefarah `yq` (Go static binary). |
| **krew kubectl plugin layout** | Adds a discovery framework the candidate has to install; `cka-sim` is not actually a `kubectl` plugin (it doesn't extend `kubectl`, it *drives* `kubectl`). Naming it `kubectl-cka-sim` and submitting to krew would be confusingly off-mission. | Plain `cka-sim` script in `/usr/local/bin/` placed by a one-line `install.sh`. |
| **Homebrew tap, apt PPA, snap** | Single-user repo, single-cluster target. Distribution is `git clone && ./install.sh`. | `install.sh` that copies into `/usr/local/share/cka-sim/` + symlinks `/usr/local/bin/cka-sim`. |
| **A custom DSL for question files** (YAML/TOML "question manifest") | Bash files ARE the question definition — they're already what the runner needs to invoke. A meta-format would just generate the same bash less legibly. | Three plain bash files per question: `setup.sh`, `grade.sh`, `reset.sh`. Optional `meta.env` (key=value) for `DOMAIN=`, `WEIGHT=`, `TITLE=`. |
| **`make` for question lifecycle** | Make introduces parallelism issues against a shared cluster (two questions racing on the same NS) and obscures which command did what. | The runner CLI directly invokes the three scripts in order. |
| **`sshpass`** | Passwords-in-CLI is a known bad pattern; ed25519 + `ssh-copy-id` is the standard answer. | Public-key auth via the bootstrap script. |
| **A separate score database (SQLite, JSON file with merge logic)** | Append-only Markdown attempt files in `$CKA_SIM_HOME/attempts/` are simpler, human-readable, and the candidate can `grep` them. | Append `attempts/<timestamp>.md` per attempt. Aggregate at read-time. |
| **CI that runs the full simulator against a kind cluster** | Out of scope for v1 — the runner is for one user on their own kubeadm cluster, not a public CI fleet. | `bats-core` unit tests for the runner; manual integration runs against the candidate's cluster. Re-evaluate kind-CI as a later milestone. |
| **`shellspec`** (alternate bash test framework) | Slightly more featureful than bats but much smaller community; bats-core is the de facto standard and what most contributors recognize. | bats-core. |

---

## Stack patterns by variant

**If the candidate's cluster has restricted egress (no internet from worker nodes):**
- Pre-stage all required container images on each node via `crictl pull` during bootstrap.
- Pin the `mikefarah yq` and `kubeconform` binaries into the repo's `vendor/` (they're tiny — ~6 MB each) and have `install.sh` copy them to `/usr/local/bin/`. Then a fresh exam VM only needs `apt-get install jq shellcheck whiptail`, all in main.

**If the candidate runs the simulator from a workstation (NOT the control-plane node):**
- The `ssh node-NN` aliases break — they were defined on the CP. The simulator should detect this (no `/etc/kubernetes/admin.conf` present, kubeconfig points to a remote API server) and refuse with a clear error, since the exam-fidelity premise depends on running from the CP. PROJECT.md key decision row 7 makes this an explicit choice; don't soften it with a workstation mode.

**If the candidate wants a "lite" mode without `whiptail`:**
- Every TUI surface should have a fallback to a plain `printf` + `read -p` numbered prompt, gated on `command -v whiptail`. Default to the plain mode — `whiptail` is opt-in via `CKA_SIM_TUI=whiptail`.

---

## Version compatibility matrix

| Component | Pin to | Compatible with | Notes |
|-----------|--------|-----------------|-------|
| `kubectl` | client minor == server minor (1.35.x) | server +/- 1 minor | Match server exactly for exam realism. |
| `crictl` | 1.35.x | containerd 1.7+ | The kubeadm-installed containerd on Ubuntu 22.04. |
| `etcdctl` | 3.5.x | etcd 3.5.x (kubeadm 1.35 default) | `ETCDCTL_API=3` always exported. |
| `jq` | 1.7.x | any kubectl | apt: `jq` in jammy-updates is 1.6 — **upgrade to 1.7+** via the static binary on the GitHub release page if you need the newer regex / SQL-style operators. 1.6 is acceptable for the simple paths most graders use. MEDIUM confidence on whether 1.7 is actually needed; default to 1.6 from apt unless a specific grader needs 1.7. |
| `yq` (mikefarah) | 4.44.x | yaml 1.2 | Single static binary; pin in `vendor/` with sha256. |
| `bats-core` | 1.11.x | bash 3.2+ | dev-only |
| `shellcheck` | 0.10.x | sh / bash 5.x | apt: `shellcheck` in jammy is fine. |
| `bash` | 5.1.x (Ubuntu 22.04 default) | scripts also work on 5.0+ | Don't use 5.2-only features (e.g. `${var@U}` uppercase expansion). |
| `whiptail` | shipped with `libnewt` 0.52.x | any | apt: `whiptail`. |

---

## Verification gaps & confidence ledger

Per the agent's training-data-as-hypothesis discipline:

| Claim | Source | Confidence | Notes |
|-------|--------|------------|-------|
| Kubernetes 1.35 release exists and is the relevant exam target | `.planning/PROJECT.md` and `.planning/codebase/STACK.md` (already declared) | HIGH | Asserted by the project owner; not separately verified this session. |
| Ubuntu 22.04 ships bash 5.1, OpenSSH 8.9, jq 1.6, whiptail, shellcheck 0.8, ncurses-bin | Training data + Ubuntu jammy package metadata | HIGH | Stable since 2022 release; `apt-cache madison` from inside the cluster will confirm. |
| `mikefarah/yq` is the right yq | Widely-known; the Python `yq` is a separate Andrey Kislyuk project | HIGH | Worth a one-line note in CONTRIBUTING.md so a contributor doesn't `apt install yq` (which on some distros pulls the Python one). |
| `bats-core` 1.11.x is current | Training data | MEDIUM | Verify against `https://github.com/bats-core/bats-core/releases` at install time; the recommendation is "latest 1.x". |
| `crictl` and `etcdctl` versions track Kubernetes 1.35 patch range | Training data | MEDIUM | Verify against the kubeadm release notes the candidate's cluster was built from. |
| No live web verification was possible this session | Tool environment | — | WebSearch was denied; no Brave/Exa/Firecrawl key configured; Context7 not invoked because all the libraries above are not "library-docs" subjects (they're CLI tools whose behaviour is stable across years). Re-verify versions at the top of the milestone that touches each tool. |

---

## Installation (target VM bootstrap)

```bash
# Run on the control-plane node, once.
sudo apt-get update
sudo apt-get install -y \
  jq \
  whiptail \
  yamllint \
  shellcheck

# yq (mikefarah, Go static binary)
YQ_VERSION=v4.44.3
sudo curl -fsSL -o /usr/local/bin/yq \
  "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"
sudo chmod +x /usr/local/bin/yq

# kubeconform (CI-only, optional on the VM)
KCFM=0.6.7
curl -fsSL "https://github.com/yannh/kubeconform/releases/download/v${KCFM}/kubeconform-linux-amd64.tar.gz" \
  | sudo tar -xz -C /usr/local/bin/ kubeconform

# bats-core (dev/CI machines only — NOT installed on exam VM)
# git clone https://github.com/bats-core/bats-core ~/src/bats-core
# (cd ~/src/bats-core && sudo ./install.sh /usr/local)
```

`install.sh` for the simulator itself:

```bash
sudo install -d /usr/local/share/cka-sim
sudo cp -r runner/. cmd/. lib/. packs/. /usr/local/share/cka-sim/
sudo install -m 0755 bin/cka-sim /usr/local/bin/cka-sim
mkdir -p "$HOME/.cka-sim/attempts"
echo "cka-sim installed. Run: cka-sim list"
```

---

## Sources

- `.planning/PROJECT.md` — primary constraints (bash-only, k8s 1.35, kubeadm, Ubuntu 22.04 GCP, single-learner, no provisioning) — **load-bearing**
- `.planning/codebase/STACK.md` — existing tool inventory for continuity (k, kn, kgp aliases; `do`, `now` env vars; `ETCDCTL_API=3`; vimrc setup; image pins `nginx:1.27/1.28`, `busybox:1.36/1.37`)
- `.planning/codebase/CONVENTIONS.md` — bash style (`#!/bin/bash`, `set -euo pipefail` on validation, banner comment, ANSI color vars, `REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"` idiom, LF endings) — must be honored by the new runner
- `.planning/codebase/CONCERNS.md` — fixes the new runner must NOT replicate: non-idempotent vimrc append (use sentinel-comment block), wrong kubelet config path (`/var/lib/kubelet/kubeadm-flags.env` not `/etc/kubernetes/kubelet.conf`), unstable `-1.1` apt pins, misleading `docker` aliases (replace with `crictl`), un-pinned yamllint in CI
- Training-data knowledge of: bash 5.1 features, OpenSSH ed25519, kubectl jsonpath/auth-can-i semantics, jq 1.6/1.7, mikefarah yq v4 API, bats-core test layout, shellcheck, whiptail menus, Ubuntu jammy package set — HIGH confidence on stable behavior, MEDIUM on exact current version pins (re-verify at install time)
- No live web verification was performed — WebSearch denied, no Brave/Exa/Firecrawl/Context7 invocation possible for these CLI-tool subjects this session

---

*Stack research for: CKA Exam Simulator runner — pure bash + kubectl on kubeadm Kubernetes 1.35 / Ubuntu 22.04 GCP*
*Researched: 2026-05-07*

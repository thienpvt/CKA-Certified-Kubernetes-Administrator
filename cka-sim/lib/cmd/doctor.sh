#!/bin/bash
# cka-sim doctor — read-only preflight check for exam practice readiness.
#
# Exits 0 if every check passes, 1 otherwise.
# Prints actionable fix commands for each failure.

set -uo pipefail  # NOT -e: doctor must run ALL checks and aggregate failures

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"
# shellcheck source=../preflight.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/preflight.sh"

failures=0

_pass() { ok "$*"; }
_fail() { err "$*"; failures=$(( failures + 1 )); }

header "cka-sim doctor"

# ---------- Check 1: required binaries ----------

missing=$(cka_sim::preflight::check_binaries kubectl jq ssh ssh-keygen etcdctl crictl 2>/dev/null || true)
if [[ -z "$missing" ]]; then
  _pass "required binaries: kubectl jq ssh ssh-keygen etcdctl crictl all present"
else
  _fail "missing binaries: $(echo "$missing" | tr '\n' ' ')— install via 'sudo apt-get install -y <pkg>' (jq: jq; etcdctl/crictl: come with kubeadm; ssh: openssh-client)"
fi

# ---------- Check 2: kubeconfig ----------

if kubeconfig_path=$(cka_sim::preflight::check_kubeconfig); then
  _pass "kubeconfig readable: $kubeconfig_path"
else
  _fail "no readable kubeconfig at \$KUBECONFIG / ~/.kube/config / /etc/kubernetes/admin.conf — copy admin.conf: 'mkdir -p ~/.kube && sudo cp /etc/kubernetes/admin.conf ~/.kube/config && sudo chown \$USER:\$USER ~/.kube/config'"
fi

# ---------- Check 3: API server reachable ----------

if kubectl get --raw /livez >/dev/null 2>&1; then
  _pass "API server reachable (/livez ok)"
else
  _fail "API server not reachable — check 'kubectl cluster-info' and confirm the control-plane pod kube-apiserver is running"
fi

# ---------- Check 4: cluster topology ----------

if cluster_counts=$(cka_sim::preflight::check_cluster_nodes); then
  read -r total cp workers <<<"$cluster_counts"
  _pass "cluster topology: $total Ready ($cp CP + $workers workers)"
else
  read -r total cp workers <<<"$cluster_counts"
  _fail "need ≥3 Ready nodes (1 CP + ≥2 workers); got total=$total cp=$cp workers=$workers — check 'kubectl get nodes' and bring missing workers to Ready"
fi

# ---------- Check 5: SSH BatchMode to each worker ----------

if ! command -v kubectl >/dev/null 2>&1; then
  warn "skipping SSH checks (kubectl missing)"
else
  mapfile -t worker_names < <(cka_sim::preflight::get_worker_names 2>/dev/null || true)
  if (( ${#worker_names[@]} == 0 )); then
    _fail "no worker nodes discovered via kubectl — cannot test SSH (fix cluster first, then re-run)"
  else
    for name in "${worker_names[@]}"; do
      if cka_sim::preflight::check_ssh_batchmode "$name"; then
        _pass "ssh BatchMode works: $name"
      else
        _fail "ssh BatchMode failed for $name — run 'cka-sim bootstrap' to (re-)distribute ~/.ssh/cka_sim_ed25519.pub to this worker"
      fi
    done
  fi
fi

# ---------- Check 6: ~/.cka-sim state dirs ----------

if cka_sim::preflight::check_state_dirs; then
  _pass "state dirs present: ~/.cka-sim/{sessions,reports,logs}"
else
  _fail "missing ~/.cka-sim state subdirs — run 'cka-sim bootstrap' (it runs 'mkdir -p' idempotently)"
fi

# ---------- Check 7: SSH key ----------

if [[ -f "$HOME/.ssh/cka_sim_ed25519" ]] && [[ -f "$HOME/.ssh/cka_sim_ed25519.pub" ]]; then
  _pass "SSH key present: ~/.ssh/cka_sim_ed25519"
else
  _fail "SSH key ~/.ssh/cka_sim_ed25519 missing — run 'cka-sim bootstrap' to generate and distribute"
fi

# ---------- Check 8: bashrc sentinel block ----------

if cka_sim::preflight::check_bashrc_block; then
  _pass "~/.bashrc sentinel block present (env exports configured)"
  if [[ "${ETCDCTL_API:-}" == "3" ]]; then
    _pass "ETCDCTL_API=3 active in current shell"
  else
    warn "ETCDCTL_API not set in current shell — run 'source ~/.bashrc' or open a new shell"
  fi
else
  _fail "~/.bashrc sentinel block missing — run 'cka-sim bootstrap' to install ETCDCTL_API + CONTAINER_RUNTIME_ENDPOINT exports"
fi

# ---------- Result ----------

printf '\n' >&2
if (( failures == 0 )); then
  ok "all checks passed — cluster is ready for drill/exam"
  exit 0
else
  err "$failures check(s) failed — address the issues above and re-run 'cka-sim doctor'"
  exit 1
fi

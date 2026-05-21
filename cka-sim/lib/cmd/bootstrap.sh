#!/bin/bash
# cka-sim bootstrap — prepare the existing 1+2 kubeadm cluster for exam practice.
#
# What this does (all idempotent):
#   1. Verify cluster reachable (≥3 Ready nodes, 1 CP + ≥2 workers)
#   2. Install jq if missing (with sudo, prompted)
#   3. Create ~/.cka-sim/{sessions,reports,logs}
#   4. Write sentinel-fenced env-export block to ~/.bashrc
#   5. Generate ~/.ssh/cka_sim_ed25519 if absent
#   6. Write sentinel-fenced Host stanzas to ~/.ssh/config for each worker
#   7. Distribute the pubkey to each worker via ssh-copy-id (may prompt pw once)
#   8. Install /usr/local/bin/cka-sim -> <repo>/cka-sim/bin/cka-sim symlink (sudo, prompted)
#
# What this explicitly does NOT do (per BOOT-04):
#   - No shell aliases injected
#   - No ~/.vimrc modification
#   - scripts/exam-setup.sh is NOT sourced by this script

set -euo pipefail

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"
# shellcheck source=../fileblock.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/fileblock.sh"
# shellcheck source=../preflight.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/preflight.sh"

readonly SENTINEL_BEGIN='# === cka-sim BEGIN (managed by cka-sim bootstrap; do not edit inside this block) ==='
readonly SENTINEL_END='# === cka-sim END ==='
readonly SSH_KEY="$HOME/.ssh/cka_sim_ed25519"
readonly BASHRC="$HOME/.bashrc"
readonly SSH_CONFIG="$HOME/.ssh/config"

# Prompt the user y/N; echo "y" or "n".
_confirm() {
  local prompt="$1"
  local reply=""
  printf '%s [y/N] ' "$prompt" >&2
  read -r reply || reply=""
  case "$reply" in
    y|Y|yes|YES) printf 'y' ;;
    *)           printf 'n' ;;
  esac
}

# ---------- Step 1: kubeconfig + cluster topology ----------

header "cka-sim bootstrap"

info "checking kubeconfig"
kubeconfig_path=$(cka_sim::preflight::check_kubeconfig) \
  || die "kubeconfig not readable. Copy /etc/kubernetes/admin.conf to ~/.kube/config (mkdir -p ~/.kube && sudo cp /etc/kubernetes/admin.conf ~/.kube/config && sudo chown \$USER:\$USER ~/.kube/config) and re-run."
ok "kubeconfig: $kubeconfig_path"

info "checking cluster nodes"
if ! cluster_counts=$(cka_sim::preflight::check_cluster_nodes); then
  read -r total cp workers <<<"$cluster_counts"
  die "need ≥3 Ready nodes (1 control-plane + ≥2 workers); got total=$total cp=$cp workers=$workers. Verify with 'kubectl get nodes' and check that nodes are Ready."
fi
read -r total cp workers <<<"$cluster_counts"
ok "cluster: $total Ready nodes ($cp control-plane + $workers workers)"

# ---------- Step 2: jq ----------

info "checking jq"
if ! command -v jq >/dev/null 2>&1; then
  if [[ "$(_confirm 'jq is not installed. Install via sudo apt-get install -y jq?')" == "y" ]]; then
    if ! sudo apt-get update -qq && sudo apt-get install -y jq; then
      die "sudo apt-get install jq failed. Install jq manually and re-run."
    fi
    ok "jq installed"
  else
    die "jq is required. Install with 'sudo apt-get install -y jq' and re-run."
  fi
else
  ok "jq present ($(jq --version))"
fi

# ---------- Step 3: state dirs ----------

info "ensuring ~/.cka-sim state directories"
cka_sim::preflight::ensure_state_dirs
ok "state dirs: ~/.cka-sim/{sessions,reports,logs}"

# ---------- Step 4: ~/.bashrc env block ----------

info "writing env exports to ~/.bashrc (sentinel-fenced)"
bashrc_content=$(cat <<'BASHRC_EOF'
# cka-sim environment exports (phase 1, BOOT-05/06)
export ETCDCTL_API=3
export CONTAINER_RUNTIME_ENDPOINT=unix:///run/containerd/containerd.sock
BASHRC_EOF
)
cka_sim::fileblock::write "$BASHRC" "$SENTINEL_BEGIN" "$SENTINEL_END" "$bashrc_content"
# shellcheck disable=SC2088  # rationale: literal user-facing text, not a path expansion
ok "~/.bashrc env block installed (source ~/.bashrc to activate this shell)"

# ---------- Step 5: SSH key ----------

info "ensuring SSH key $SSH_KEY"
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
if [[ ! -f "$SSH_KEY" ]]; then
  ssh-keygen -t ed25519 -N '' -f "$SSH_KEY" -C "cka-sim@$(hostname)" >/dev/null
  ok "generated $SSH_KEY"
else
  ok "existing key $SSH_KEY"
fi

# ---------- Step 6: SSH config Host stanzas ----------

info "discovering worker nodes and IPs"
mapfile -t worker_names < <(cka_sim::preflight::get_worker_names)
(( ${#worker_names[@]} >= 2 )) \
  || die "fewer than 2 worker nodes discovered; kubectl get nodes must show 2+ non-control-plane Ready nodes."

current_user="${USER:-$(whoami)}"
ssh_block=""
for name in "${worker_names[@]}"; do
  ip=$(cka_sim::preflight::get_node_ip "$name")
  [[ -n "$ip" ]] || die "could not resolve InternalIP for node '$name'. Check 'kubectl get node $name -o wide'."
  ssh_block+="Host $name"$'\n'
  ssh_block+="  HostName $ip"$'\n'
  ssh_block+="  User $current_user"$'\n'
  ssh_block+="  IdentityFile $SSH_KEY"$'\n'
  ssh_block+="  StrictHostKeyChecking accept-new"$'\n'
  ssh_block+="  UserKnownHostsFile ~/.ssh/known_hosts"$'\n'
  ssh_block+="  ControlMaster auto"$'\n'
  ssh_block+="  ControlPath ~/.ssh/cm-%r@%h:%p"$'\n'
  ssh_block+="  ControlPersist 10m"$'\n'
  ssh_block+=$'\n'
done
# Trim trailing blank line for cleanliness
ssh_block=${ssh_block%$'\n'}

cka_sim::fileblock::write "$SSH_CONFIG" "$SENTINEL_BEGIN" "$SENTINEL_END" "$ssh_block"
chmod 600 "$SSH_CONFIG"
# shellcheck disable=SC2088  # rationale: literal user-facing text, not a path expansion
ok "~/.ssh/config Host stanzas installed for: ${worker_names[*]}"

# ---------- Step 7: Distribute pubkey ----------

info "distributing pubkey to workers (may prompt for password once per host)"
for name in "${worker_names[@]}"; do
  if cka_sim::preflight::check_ssh_batchmode "$name"; then
    ok "$name: BatchMode SSH already working"
    continue
  fi
  ip=$(cka_sim::preflight::get_node_ip "$name")
  info "$name ($ip): running ssh-copy-id (may prompt for password)"
  if ssh-copy-id -i "${SSH_KEY}.pub" -o StrictHostKeyChecking=accept-new \
       "${current_user}@${ip}" >/dev/null 2>&1; then
    # Re-verify
    if cka_sim::preflight::check_ssh_batchmode "$name"; then
      ok "$name: pubkey installed, BatchMode SSH works"
    else
      die "$name: ssh-copy-id succeeded but BatchMode SSH still failing. Check ~/.ssh/authorized_keys on $name."
    fi
  else
    die "$name: ssh-copy-id failed. Ensure $current_user can ssh to $ip with a password first, or manually copy $SSH_KEY.pub to ~/.ssh/authorized_keys on $name."
  fi
done

# ---------- Step 8: Install symlink ----------

SYMLINK="/usr/local/bin/cka-sim"
info "checking PATH symlink $SYMLINK"
want_target="$CKA_SIM_ROOT/bin/cka-sim"
if [[ -L "$SYMLINK" ]] && [[ "$(readlink -f "$SYMLINK")" == "$(readlink -f "$want_target")" ]]; then
  ok "$SYMLINK already points to $want_target"
elif [[ -e "$SYMLINK" ]]; then
  warn "$SYMLINK exists but points elsewhere. Skipping (remove it manually and re-run if you want bootstrap to manage it)."
else
  if [[ "$(_confirm "Install $SYMLINK -> $want_target? (requires sudo)")" == "y" ]]; then
    if sudo ln -sf "$want_target" "$SYMLINK"; then
      ok "installed $SYMLINK"
    else
      warn "sudo ln -sf failed. You can run manually: sudo ln -sf '$want_target' '$SYMLINK'"
    fi
  else
    warn "skipped. Add '$CKA_SIM_ROOT/bin' to PATH manually, or re-run bootstrap to install the symlink."
  fi
fi

# ---------- Done ----------

printf '\n' >&2
ok "bootstrap complete. Next: run 'cka-sim doctor' to verify the cluster is ready."
printf '  (source ~/.bashrc or open a new shell to pick up env exports.)\n' >&2

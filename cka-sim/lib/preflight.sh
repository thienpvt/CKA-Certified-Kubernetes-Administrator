#!/bin/bash
# cka-sim/lib/preflight.sh — shared dependency / cluster readiness helpers
# Sourced by: lib/cmd/bootstrap.sh, lib/cmd/doctor.sh

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=colors.sh disable=SC1091
[[ -z "${RED+x}" ]] && source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"

# ---------- Dependency checks ----------

# Usage: cka_sim::preflight::check_binaries <name>...
# Prints each missing binary, one per line. Exits 0 if all present, 1 otherwise.
cka_sim::preflight::check_binaries() {
  local missing=()
  local b
  for b in "$@"; do
    command -v "$b" >/dev/null 2>&1 || missing+=("$b")
  done
  if (( ${#missing[@]} > 0 )); then
    printf '%s\n' "${missing[@]}"
    return 1
  fi
  return 0
}

# ---------- Kubeconfig ----------

# Resolves KUBECONFIG to an accessible file. Preference order:
#   1. $KUBECONFIG if set and readable
#   2. ~/.kube/config
#   3. /etc/kubernetes/admin.conf
# Echoes the resolved path on success; returns 1 on failure.
cka_sim::preflight::check_kubeconfig() {
  local candidates=()
  [[ -n "${KUBECONFIG:-}" ]] && candidates+=("$KUBECONFIG")
  candidates+=("$HOME/.kube/config" "/etc/kubernetes/admin.conf")

  local c
  for c in "${candidates[@]}"; do
    if [[ -r "$c" ]]; then
      export KUBECONFIG="$c"
      printf '%s\n' "$c"
      return 0
    fi
  done
  return 1
}

# ---------- Cluster node topology ----------

# Runs kubectl and asserts: ≥3 Ready nodes, ≥1 control-plane, ≥2 workers.
# Echoes "<total> <cp> <workers>" on success.
# Returns 1 on failure; caller prints the actionable message.
cka_sim::preflight::check_cluster_nodes() {
  local nodes_json
  nodes_json=$(kubectl get nodes -o json 2>/dev/null) || return 1

  local total cp workers
  # Count Ready nodes.
  total=$(printf '%s' "$nodes_json" \
    | jq '[.items[] | select(.status.conditions[] | select(.type=="Ready") | .status=="True")] | length')
  cp=$(printf '%s' "$nodes_json" \
    | jq '[.items[] | select(.metadata.labels["node-role.kubernetes.io/control-plane"] != null)] | length')
  workers=$(( total - cp ))

  if (( total < 3 )) || (( cp < 1 )) || (( workers < 2 )); then
    printf '%d %d %d\n' "$total" "$cp" "$workers"
    return 1
  fi
  printf '%d %d %d\n' "$total" "$cp" "$workers"
  return 0
}

# Echoes worker node names, one per line.
cka_sim::preflight::get_worker_names() {
  kubectl get nodes -o json 2>/dev/null \
    | jq -r '.items[] | select(.metadata.labels["node-role.kubernetes.io/control-plane"] == null) | .metadata.name'
}

# Echoes a node's InternalIP.
cka_sim::preflight::get_node_ip() {
  local name="$1"
  [[ -n "$name" ]] || { printf 'get_node_ip: missing node name\n' >&2; return 1; }
  kubectl get node "$name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null
}

# ---------- SSH ----------

# Usage: cka_sim::preflight::check_ssh_batchmode <host>
# Returns 0 if non-interactive ssh to <host> succeeds in <5s.
cka_sim::preflight::check_ssh_batchmode() {
  local host="$1"
  [[ -n "$host" ]] || { printf 'check_ssh_batchmode: missing host\n' >&2; return 1; }
  ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new \
      "$host" true 2>/dev/null
}

# ---------- State dirs ----------

cka_sim::preflight::check_state_dirs() {
  local sub
  for sub in sessions reports logs; do
    [[ -d "$HOME/.cka-sim/$sub" ]] || return 1
  done
  return 0
}

cka_sim::preflight::ensure_state_dirs() {
  local sub
  for sub in sessions reports logs; do
    mkdir -p "$HOME/.cka-sim/$sub"
  done
}

# ---------- Bashrc env block check ----------

# Returns 0 if the sentinel block is present in ~/.bashrc.
cka_sim::preflight::check_bashrc_block() {
  [[ -f "$HOME/.bashrc" ]] && grep -qF '# === cka-sim BEGIN' "$HOME/.bashrc"
}

#!/bin/bash
# cka-sim/lib/setup.sh — shared setup helpers for question authoring.
# Sourced by every packs/*/*/setup.sh. Keeps ns-Active wait, PV seeding, and
# Deployment seeding in one place so bug fixes propagate automatically.
# All helpers are idempotent and safe to re-run (TRIP-02 requirement).

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"

# cka_sim::setup::ensure_lab_ns <ns> <pack> <question-id>
#   Idempotently create the lab namespace with the standard cka-sim labels.
#   Safe to re-run; labels are applied via kubectl apply (merge semantics).
cka_sim::setup::ensure_lab_ns() {
  local ns="$1" pack="$2" qid="$3"
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${ns}
  labels:
    cka-sim/pack: ${pack}
    cka-sim/question-id: ${qid}
EOF
}

# cka_sim::setup::wait_for_ns_active <ns> <pack> <question-id> [<timeout-seconds>]
#   Poll up to <timeout-seconds> (default 120) for ns.status.phase == Active.
#   Absorbs the `reset.sh --wait=false` race: if the ns disappears mid-wait
#   (still Terminating from prior reset), re-applies the Namespace def.
#   Dies if ns is not Active after the full timeout.
cka_sim::setup::wait_for_ns_active() {
  local ns="$1" pack="$2" qid="$3" timeout="${4:-120}"
  # IN-01 (04-REVIEW.md): round up so a non-5-multiple timeout still covers
  # its full second budget (e.g. timeout=12 -> 3 iterations = 15s wall, never 10s).
  local iterations=$(( (timeout + 4) / 5 ))
  local phase=""
  local i
  for i in $(seq 1 "$iterations"); do
    phase=$(kubectl get ns "$ns" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
    [[ "$phase" == "Active" ]] && return 0
    if [[ -z "$phase" ]]; then
      cka_sim::setup::ensure_lab_ns "$ns" "$pack" "$qid"
    fi
    sleep 5
  done
  die "ns $ns not Active after ${timeout}s (phase=$phase)"
}

# cka_sim::setup::seed_pv_hostpath <pv-name> <size> <access-mode> <reclaim-policy> <host-path> [<node-affinity-spec>]
#   Create a hostPath PV with optional nodeAffinity. The 6th argument controls
#   nodeAffinity emission:
#     (a) omitted or empty        -> NO nodeAffinity block (seeds the
#                                    hostpath-pv-without-nodeaffinity trap,
#                                    e.g. storage/01-pvc-binding).
#     (b) bare key (no '=')       -> operator: Exists against that key.
#                                    Matches ANY node carrying the label
#                                    regardless of value. Use only when
#                                    every-node membership is the intent.
#     (c) "key=value"             -> operator: In with values: [value].
#                                    Pins the PV to the specific node(s)
#                                    whose label matches. Required for
#                                    questions whose behavioural oracle
#                                    depends on same-node execution
#                                    (e.g. storage/06-pvc-mount-pod's
#                                    writer -> reader data handoff).
#   Per CR-01 (04-REVIEW.md), shape (b)'s operator: Exists against
#   kubernetes.io/hostname does NOT pin to a single node -- every node
#   carries that label with some value, so Exists matches all nodes. Use
#   shape (c) with a concrete hostname when single-node pinning is needed.
cka_sim::setup::seed_pv_hostpath() {
  local name="$1" size="$2" mode="$3" reclaim="$4" hp="$5" affinity_spec="${6:-}"
  local affinity_block=""
  if [[ -n "$affinity_spec" ]]; then
    if [[ "$affinity_spec" == *"="* ]]; then
      # Shape (c): key=value -> In match on that specific value.
      local k="${affinity_spec%%=*}"
      local v="${affinity_spec#*=}"
      affinity_block=$(cat <<AFF
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: ${k}
              operator: In
              values: ["${v}"]
AFF
)
    else
      # Shape (b): bare key -> Exists (legacy: any-node membership).
      affinity_block=$(cat <<AFF
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: ${affinity_spec}
              operator: Exists
AFF
)
    fi
  fi
  # WR-07 (04-REVIEW.md): if CKA_SIM_PACK and/or CKA_SIM_QUESTION_ID are
  # exported by the caller (every new setup.sh in Phase 4 does), stamp matching
  # cka-sim/pack and cka-sim/question-id labels onto the PV so pack-scoped
  # cleanup + coverage tooling can find it. Cluster-scoped resources without
  # these labels are invisible to any lint/sweep that filters by pack.
  local labels_block=""
  if [[ -n "${CKA_SIM_PACK:-}" || -n "${CKA_SIM_QUESTION_ID:-}" ]]; then
    labels_block="  labels:"
    [[ -n "${CKA_SIM_PACK:-}" ]]        && labels_block+=$'\n'"    cka-sim/pack: ${CKA_SIM_PACK}"
    [[ -n "${CKA_SIM_QUESTION_ID:-}" ]] && labels_block+=$'\n'"    cka-sim/question-id: ${CKA_SIM_QUESTION_ID}"
  fi
  kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${name}
${labels_block}
spec:
  capacity:
    storage: ${size}
  accessModes:
    - ${mode}
  persistentVolumeReclaimPolicy: ${reclaim}
  storageClassName: manual
  hostPath:
    path: ${hp}
    type: DirectoryOrCreate
${affinity_block}
EOF
}

# cka_sim::setup::seed_deployment <ns> <name> <image> [--replicas N] [--sa SA] [--cpu X] [--memory Y]
#   Create a minimal Deployment. Flags opt-in to serviceAccountName and requests.
#   Used by questions that need a deployable target without reinventing YAML.
cka_sim::setup::seed_deployment() {
  local ns="$1" name="$2" image="$3"; shift 3
  local replicas=1 sa="" cpu="" mem=""
  while (( $# > 0 )); do
    case "$1" in
      --replicas) replicas="$2"; shift 2 ;;
      --sa)       sa="$2"; shift 2 ;;
      --cpu)      cpu="$2"; shift 2 ;;
      --memory)   mem="$2"; shift 2 ;;
      *) die "seed_deployment: unexpected flag $1" ;;
    esac
  done
  local sa_block=""
  # IN-02 (04-REVIEW.md): when --sa is not passed, emit NO line here -- the
  # previous shape left a blank line between 'spec:' and 'containers:' which
  # was YAML-valid but cosmetically noisy and tripped shellcheck SC2016 on
  # any future rewrite. The leading newline lives inside sa_block so the
  # heredoc below can splice it as '    spec:${sa_block}' without trailing
  # whitespace on the empty branch.
  [[ -n "$sa" ]] && sa_block=$'\n      serviceAccountName: '"${sa}"
  local resources_block=""
  if [[ -n "$cpu" || -n "$mem" ]]; then
    resources_block=$(cat <<RES
          resources:
            requests:
              cpu: ${cpu:-50m}
              memory: ${mem:-64Mi}
RES
)
  fi
  kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${name}
  namespace: ${ns}
  labels:
    app: ${name}
spec:
  replicas: ${replicas}
  selector:
    matchLabels:
      app: ${name}
  template:
    metadata:
      labels:
        app: ${name}
    spec:${sa_block}
      containers:
        - name: app
          image: ${image}
${resources_block}
EOF
}

#!/bin/bash
# capture-grading-fixtures.sh — record post-setup + post-ref-solution fixtures
# for grading-honesty regression tests. Operator-facing; runs once after
# grade.sh changes; commits fixtures.
#
# Usage: bash cka-sim/scripts/capture-grading-fixtures.sh [--regen <question>]
#   --regen <question>   slug of single question to regenerate (e.g. workloads-scheduling__02-rolling-update-rollback)
#   No flag              regenerate all 4 offender fixtures.
set -euo pipefail

CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CKA_SIM_ROOT

# shellcheck source=../lib/colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../lib/log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"

FIXTURES_BASE="$CKA_SIM_ROOT/tests/fixtures/grading-honesty"

# 4 offender questions (pack/slug -> test-id)
declare -A QUESTIONS=(
  ["workloads-scheduling/02-rolling-update-rollback"]="workloads-scheduling__02-rolling-update-rollback"
  ["storage/02-storageclass-dynamic"]="storage__02-storageclass-dynamic"
  ["services-networking/06-netpol-endport"]="services-networking__06-netpol-endport"
  ["cluster-architecture/04-pss-enforce"]="cluster-architecture__04-pss-enforce"
)

# Namespace conventions
declare -A NAMESPACES=(
  ["workloads-scheduling/02-rolling-update-rollback"]="cka-sim-workloads-scheduling-02"
  ["storage/02-storageclass-dynamic"]="cka-sim-storage-02"
  ["services-networking/06-netpol-endport"]="cka-sim-services-networking-06"
  ["cluster-architecture/04-pss-enforce"]="cka-sim-cluster-architecture-04"
)

# JQ cleanup pipeline: strip managedFields + lastTransitionTime
JQ_CLEANUP='del(.metadata.managedFields) | del(.. | .lastTransitionTime?)'

regen_target=""
if [[ "${1:-}" == "--regen" ]]; then
  regen_target="${2:?--regen requires a question slug (e.g. workloads-scheduling__02-rolling-update-rollback)}"
fi

capture_phase() {
  local pack_slug="$1" phase="$2"
  local test_id="${QUESTIONS[$pack_slug]}"
  local ns="${NAMESPACES[$pack_slug]}"
  local qdir="$CKA_SIM_ROOT/packs/$pack_slug"
  local out_dir="$FIXTURES_BASE/$test_id/$phase"

  mkdir -p "$out_dir"

  info "capturing $test_id / $phase"

  # Capture baseline.json (lean schema)
  local resources
  resources=$(kubectl get -n "$ns" \
    deployment,statefulset,daemonset,pod,service,configmap,secret,pvc,networkpolicy,rolebinding,serviceaccount \
    -o json 2>/dev/null | jq "[$JQ_CLEANUP | .items[]? | {
      kind: .kind,
      name: .metadata.name,
      namespace: .metadata.namespace,
      generation: .metadata.generation,
      resourceVersion: .metadata.resourceVersion,
      labels: (.metadata.labels // {})
    }]")

  # Cluster-scoped resources relevant to this question
  local cluster_resources
  cluster_resources=$(kubectl get storageclass,pv,clusterrolebinding,priorityclass \
    -o json 2>/dev/null | jq --arg ns "$ns" "[$JQ_CLEANUP | .items[]? | select(
      (.metadata.name | startswith(\"$ns\")) or
      ((.metadata.labels // {})[\"cka-sim/question\"] != null)
    ) | {
      kind: .kind,
      name: .metadata.name,
      namespace: null,
      generation: .metadata.generation,
      resourceVersion: .metadata.resourceVersion,
      labels: (.metadata.labels // {})
    }]" 2>/dev/null || echo "[]")

  local all_resources
  all_resources=$(printf '%s\n%s' "$resources" "$cluster_resources" | jq -s '.[0] + .[1]')

  local resource_list
  resource_list=$(printf '%s' "$all_resources" | jq '[.[] | "\(.kind | ascii_downcase)/\(.name)"]')

  local captured_at
  captured_at=$(date +%s)

  jq -n \
    --argjson ts "$captured_at" \
    --arg ns "$ns" \
    --argjson resources "$all_resources" \
    --argjson resource_list "$resource_list" \
    '{captured_at: $ts, lab_namespace: $ns, resources: $resources, resource_list: $resource_list}' \
    > "$out_dir/baseline.json"

  ok "wrote $out_dir/baseline.json"

  # Capture .fixtures.json — run grade.sh with kubectl tracing to enumerate calls
  # For now, this is a placeholder; the actual manifest is hand-authored per question
  # based on grade.sh kubectl call inventory.
  info "NOTE: .fixtures.json must be hand-authored from grade.sh kubectl call inventory"
  info "      or captured via kubectl-trace wrapper (future enhancement)"

  ok "phase $phase complete for $test_id"
}

capture_question() {
  local pack_slug="$1"
  local qdir="$CKA_SIM_ROOT/packs/$pack_slug"

  header "Capturing: $pack_slug"

  # Reset + setup
  if [[ -x "$qdir/reset.sh" ]]; then
    info "running reset.sh"
    bash "$qdir/reset.sh" 2>/dev/null || true
  fi
  if [[ -x "$qdir/setup.sh" ]]; then
    info "running setup.sh"
    bash "$qdir/setup.sh"
  fi

  # Post-setup capture
  capture_phase "$pack_slug" "post-setup"

  # Run ref-solution
  if [[ -x "$qdir/ref-solution.sh" ]]; then
    info "running ref-solution.sh"
    bash "$qdir/ref-solution.sh"
  fi

  # Post-ref-solution capture
  capture_phase "$pack_slug" "post-ref-solution"

  ok "done: $pack_slug"
}

# Main
header "capture-grading-fixtures"

for pack_slug in "${!QUESTIONS[@]}"; do
  test_id="${QUESTIONS[$pack_slug]}"
  if [[ -n "$regen_target" && "$test_id" != "$regen_target" ]]; then
    continue
  fi
  capture_question "$pack_slug"
done

ok "capture complete"

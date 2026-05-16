#!/bin/bash
# cka-sim/lib/baseline.sh — baseline capture + candidate-modification detection.
# Sourced by: lib/grade.sh (which sources this after traps.sh).
# Provides: cka_sim::baseline::capture, cka_sim::baseline::is_candidate_modified.
#
# Contract:
#   - Sources cleanly with set -uo pipefail.
#   - is_candidate_modified returns 0 (back-compat) when CKA_SIM_BASELINE_PATH unset or file missing.
#   - Generation-first, rv-fallback comparison logic.
#   - resource_list uses canonical lowercase-kind/name format (no apigroup suffix).

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=colors.sh disable=SC1091
[[ -z "${RED+x}" ]] && source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"

# ---------- cka_sim::baseline::capture ----------
#
# Captures baseline JSON to $CKA_SIM_BASELINE_PATH.
# Two-query approach: namespaced + cluster-scoped (filtered by question-ID prefix).
# On kubectl failure: exits non-zero (does NOT write empty baseline).
#
# Usage: cka_sim::baseline::capture <namespace>
cka_sim::baseline::capture() {
  local ns="${1:?capture requires a namespace argument}"

  : "${CKA_SIM_BASELINE_PATH:?CKA_SIM_BASELINE_PATH must be exported by caller}"
  : "${CKA_SIM_QUESTION_ID:?CKA_SIM_QUESTION_ID must be exported by caller}"

  # QUERY 1: namespaced resources
  local namespaced_json
  namespaced_json=$(kubectl get -n "$ns" \
    deployment,statefulset,daemonset,pod,service,configmap,secret,pvc,networkpolicy,rolebinding,serviceaccount \
    -o json 2>/dev/null) || {
    err "baseline capture: kubectl get (namespaced) failed for ns=$ns"
    return 1
  }

  # QUERY 2: cluster-scoped resources filtered by question-ID prefix
  local cluster_json
  cluster_json=$(kubectl get \
    storageclass,pv,clusterrolebinding,priorityclass \
    -o json 2>/dev/null) || {
    err "baseline capture: kubectl get (cluster-scoped) failed"
    return 1
  }

  # Extract per-resource fields from namespaced query + normalize kind
  local namespaced_resources
  namespaced_resources=$(printf '%s' "$namespaced_json" | jq --arg qid "$CKA_SIM_QUESTION_ID" '
    [(.items // [])[] | {
      kind: .kind,
      name: .metadata.name,
      namespace: .metadata.namespace,
      generation: .metadata.generation,
      resourceVersion: .metadata.resourceVersion,
      labels: (.metadata.labels // {})
    } | del(.labels["kubectl.kubernetes.io/last-applied-configuration"]) | del(.managedFields)]
  ') || {
    err "baseline capture: jq transform (namespaced) failed"
    return 1
  }

  # Extract cluster-scoped resources filtered by question-ID prefix or label
  local cluster_resources
  cluster_resources=$(printf '%s' "$cluster_json" | jq --arg qid "$CKA_SIM_QUESTION_ID" '
    [(.items // [])[] | select(
      (.metadata.name | startswith($qid)) or
      ((.metadata.labels // {})["cka-sim/question"] == $qid)
    ) | {
      kind: .kind,
      name: .metadata.name,
      namespace: null,
      generation: .metadata.generation,
      resourceVersion: .metadata.resourceVersion,
      labels: (.metadata.labels // {})
    } | del(.labels["kubectl.kubernetes.io/last-applied-configuration"]) | del(.managedFields)]
  ') || {
    err "baseline capture: jq transform (cluster-scoped) failed"
    return 1
  }

  # Merge both resource arrays
  local all_resources
  all_resources=$(printf '%s\n%s' "$namespaced_resources" "$cluster_resources" | jq -s '.[0] + .[1]') || {
    err "baseline capture: jq merge failed"
    return 1
  }

  # Build resource_list with canonical lowercase-kind/name format
  local resource_list
  resource_list=$(printf '%s' "$all_resources" | jq '[.[] | "\(.kind | ascii_downcase)/\(.name)"]') || {
    err "baseline capture: jq resource_list failed"
    return 1
  }

  # Compose final baseline JSON
  local captured_at
  captured_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local baseline_json
  baseline_json=$(jq -n \
    --arg ts "$captured_at" \
    --arg ns "$ns" \
    --argjson resources "$all_resources" \
    --argjson resource_list "$resource_list" \
    '{captured_at: $ts, lab_namespace: $ns, resources: $resources, resource_list: $resource_list}') || {
    err "baseline capture: jq compose failed"
    return 1
  }

  # Atomic write: tmpfile then mv
  mkdir -p "$(dirname "$CKA_SIM_BASELINE_PATH")"
  chmod 0700 "$(dirname "$CKA_SIM_BASELINE_PATH")" 2>/dev/null || true

  local tmpfile
  tmpfile=$(mktemp "${CKA_SIM_BASELINE_PATH}.XXXXXX") || {
    err "baseline capture: mktemp failed"
    return 1
  }

  printf '%s\n' "$baseline_json" > "$tmpfile" || {
    rm -f "$tmpfile"
    err "baseline capture: write to tmpfile failed"
    return 1
  }

  mv "$tmpfile" "$CKA_SIM_BASELINE_PATH" || {
    rm -f "$tmpfile"
    err "baseline capture: mv to final path failed"
    return 1
  }

  chmod 0444 "$CKA_SIM_BASELINE_PATH" 2>/dev/null || true
  ok "baseline captured: $CKA_SIM_BASELINE_PATH"
}

# ---------- cka_sim::baseline::canonical_kind ----------
#
# Normalize a kubectl kind short-name to its canonical lowercase singular form
# so lookups against the resource_list stored by capture() succeed.
#
# kubectl get -o json returns items with .kind set to the full CamelCase singular
# (e.g., PersistentVolume, Service). capture() lowercases these into resource_list
# entries like "persistentvolume/<name>". Callers of is_candidate_modified often
# use the short form (pv, pvc, svc, etc.); this helper expands them.
#
# Usage: canonical=$(cka_sim::baseline::canonical_kind "pv")  # -> persistentvolume
cka_sim::baseline::canonical_kind() {
  local k
  k="$(printf '%s' "${1:?canonical_kind requires kind}" | tr '[:upper:]' '[:lower:]')"
  case "$k" in
    pv)      echo "persistentvolume" ;;
    pvc)     echo "persistentvolumeclaim" ;;
    svc)     echo "service" ;;
    sa)      echo "serviceaccount" ;;
    cm)      echo "configmap" ;;
    ns)      echo "namespace" ;;
    po)      echo "pod" ;;
    deploy)  echo "deployment" ;;
    sts)     echo "statefulset" ;;
    ds)      echo "daemonset" ;;
    rs)      echo "replicaset" ;;
    rc)      echo "replicationcontroller" ;;
    ing)     echo "ingress" ;;
    netpol)  echo "networkpolicy" ;;
    pdb)     echo "poddisruptionbudget" ;;
    sc)      echo "storageclass" ;;
    ep)      echo "endpoints" ;;
    no)      echo "node" ;;
    crd)     echo "customresourcedefinition" ;;
    *)       echo "$k" ;;
  esac
}

# ---------- cka_sim::baseline::is_candidate_modified ----------
#
# Returns 0 if the resource has been modified since baseline (or baseline unavailable).
# Returns 1 if the resource is unchanged.
#
# Logic: generation-first, rv-fallback.
#   - If CKA_SIM_BASELINE_PATH unset or file missing -> return 0 (back-compat).
#   - If resource not in baseline.resource_list -> return 0 (candidate-authored).
#   - If baseline.generation is non-null AND current.generation > baseline.generation -> return 0.
#   - If baseline.generation is null OR generations equal -> compare resourceVersion.
#   - If rv differs -> return 0. Else -> return 1 (unchanged).
#
# Usage: cka_sim::baseline::is_candidate_modified <kind> <name> [-n <ns>]
cka_sim::baseline::is_candidate_modified() {
  local kind="${1:?is_candidate_modified requires kind}" name="${2:?is_candidate_modified requires name}"
  shift 2

  local ns=""
  while (( $# > 0 )); do
    if [[ "$1" == "-n" ]]; then
      [[ $# -ge 2 ]] || { err "is_candidate_modified: flag -n requires value"; return 0; }
      ns="$2"
      shift 2
    else
      shift
    fi
  done

  # Back-compat: no baseline path or file -> return 0
  if [[ -z "${CKA_SIM_BASELINE_PATH:-}" ]] || [[ ! -r "$CKA_SIM_BASELINE_PATH" ]]; then
    return 0
  fi

  # Canonical lookup key: lowercase canonical-kind/name.
  # Phase 07.1 D-24 — kubectl short names (pv, pvc, svc, sa, cm, etc.) must be
  # normalized to full canonical kind to match the resource_list stored by capture().
  local canonical_kind
  canonical_kind="$(cka_sim::baseline::canonical_kind "$kind")"
  local lookup_key
  lookup_key="$canonical_kind/$name"

  # Check if resource is in baseline
  local in_baseline
  in_baseline=$(jq -r --arg key "$lookup_key" \
    '(.resource_list // []) | if index($key) != null then "true" else "false" end' \
    "$CKA_SIM_BASELINE_PATH" 2>/dev/null) || {
    err "baseline.json malformed: $CKA_SIM_BASELINE_PATH"
    return 0
  }

  if [[ "$in_baseline" != "true" ]]; then
    # Resource not in baseline -> candidate-authored
    return 0
  fi

  # Read baseline generation and resourceVersion for this resource
  local baseline_gen baseline_rv
  baseline_gen=$(jq -r --arg key "$lookup_key" \
    '[.resources[] | select(("\(.kind | ascii_downcase)/\(.name)" == $key))] | .[0].generation // ""' \
    "$CKA_SIM_BASELINE_PATH" 2>/dev/null)
  baseline_rv=$(jq -r --arg key "$lookup_key" \
    '[.resources[] | select(("\(.kind | ascii_downcase)/\(.name)" == $key))] | .[0].resourceVersion // ""' \
    "$CKA_SIM_BASELINE_PATH" 2>/dev/null)

  # GENERATION-FIRST check
  if [[ -n "$baseline_gen" ]] && [[ "$baseline_gen" != "null" ]]; then
    local current_gen
    if [[ -n "$ns" ]]; then
      current_gen=$(kubectl get "$kind" "$name" -n "$ns" -o jsonpath='{.metadata.generation}' 2>/dev/null)
    else
      current_gen=$(kubectl get "$kind" "$name" -o jsonpath='{.metadata.generation}' 2>/dev/null)
    fi

    if [[ -n "$current_gen" ]] && (( current_gen > baseline_gen )); then
      return 0  # modified (generation increased)
    fi
    # Generation equal or current_gen empty -> fall through to rv check
  fi

  # RV FALLBACK (reached when baseline_gen is null/empty OR generation comparison was equal)
  local current_rv
  if [[ -n "$ns" ]]; then
    current_rv=$(kubectl get "$kind" "$name" -n "$ns" -o jsonpath='{.metadata.resourceVersion}' 2>/dev/null)
  else
    current_rv=$(kubectl get "$kind" "$name" -o jsonpath='{.metadata.resourceVersion}' 2>/dev/null)
  fi

  if [[ "$current_rv" != "$baseline_rv" ]]; then
    return 0  # modified (rv changed)
  fi

  return 1  # unchanged
}

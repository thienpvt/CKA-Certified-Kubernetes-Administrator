#!/bin/bash
# cka-sim/lib/grade.sh — assertion helpers + accumulator state machine + emit_result finalizer.
# Sourced by: every grade.sh under packs/*/<question>/.
# State machine (per CONTEXT D-05, D-06, D-07, D-08): assertions accumulate; SCORE + Trap N: lines to stdout; live ✓/✗ to stderr; trap dedup by id.
# NOTE: grader scripts that source this module use `set -uo pipefail` — NOT -e — so all assertions run.

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=colors.sh disable=SC1091
[[ -z "${RED+x}" ]] && source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"
# shellcheck source=traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"
# shellcheck source=baseline.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/baseline.sh"

# ---------- Accumulator state (shared across every sourced grader) ----------
#
# `declare -ag` / `declare -gi` keeps values in the sourcing shell so multiple
# grader stages and emit_result see the same totals.

declare -ag CKA_SIM_GRADE_FAILS=()
declare -ag CKA_SIM_GRADE_PASSES=()
declare -ag CKA_SIM_GRADE_TRAPS=()
declare -gi CKA_SIM_GRADE_TOTAL=0
declare -gi CKA_SIM_GRADE_PASSED=0

# ---------- Assertion helpers (7; names are locked by GRADE-01) ----------
#
# Contract for every helper (per D-05, D-06):
#   - Increments CKA_SIM_GRADE_TOTAL by weight on entry.
#   - On pass: increments CKA_SIM_GRADE_PASSED by weight, appends message to
#     CKA_SIM_GRADE_PASSES, calls `ok` (stderr), returns 0.
#   - On fail: appends message to CKA_SIM_GRADE_FAILS, calls `err` (stderr),
#     returns 1.
#   - Never calls `die` — caller's `set -uo pipefail` keeps the grader running.

# Shared argv parser — only assert_resource_exists / assert_field_eq / assert_can_i
# accept flags, and they inline the same algorithm. See the plan's example traces.

# cka_sim::grade::assert_resource_exists <kind> <name> [-n <ns>] [<weight>]
#   Passes iff `kubectl get <kind> <name> [-n <ns>] -o name` exits 0 with non-empty stdout.
cka_sim::grade::assert_resource_exists() {
  local kind="$1" name="$2"
  shift 2
  local ns="" weight=""
  while (( $# > 0 )); do
    if [[ "$1" == "-n" ]]; then
      [[ $# -ge 2 ]] || die "assert_resource_exists: flag -n requires value"
      ns="$2"
      shift 2
    elif [[ "$1" =~ ^[0-9]+$ ]]; then
      weight="$1"
      shift
      (( $# == 0 )) || die "assert_resource_exists: unexpected argument after weight: $1"
    else
      die "assert_resource_exists: unexpected argument: $1"
    fi
  done
  : "${weight:=1}"
  CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + weight ))

  local out rc
  if [[ -n "$ns" ]]; then
    out=$(kubectl get "$kind" "$name" -n "$ns" -o name 2>/dev/null); rc=$?
  else
    out=$(kubectl get "$kind" "$name" -o name 2>/dev/null); rc=$?
  fi

  if (( rc == 0 )) && [[ -n "$out" ]]; then
    CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + weight ))
    CKA_SIM_GRADE_PASSES+=("resource $kind/$name exists")
    ok "resource $kind/$name exists"
    return 0
  fi
  CKA_SIM_GRADE_FAILS+=("resource $kind/$name not found in ns=${ns:-<none>}")
  err "resource $kind/$name not found in ns=${ns:-<none>}"
  return 1
}

# cka_sim::grade::assert_field_eq <kind> <name> <jsonpath> <expected> [-n <ns>] [<weight>]
#   Passes iff kubectl jsonpath stdout equals <expected> exactly.
cka_sim::grade::assert_field_eq() {
  local kind="$1" name="$2" jsonpath="$3" expected="$4"
  shift 4
  local ns="" weight=""
  while (( $# > 0 )); do
    if [[ "$1" == "-n" ]]; then
      [[ $# -ge 2 ]] || die "assert_field_eq: flag -n requires value"
      ns="$2"
      shift 2
    elif [[ "$1" =~ ^[0-9]+$ ]]; then
      weight="$1"
      shift
      (( $# == 0 )) || die "assert_field_eq: unexpected argument after weight: $1"
    else
      die "assert_field_eq: unexpected argument: $1"
    fi
  done
  : "${weight:=1}"
  CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + weight ))

  local actual
  if [[ -n "$ns" ]]; then
    actual=$(kubectl get "$kind" "$name" -n "$ns" -o jsonpath="$jsonpath" 2>/dev/null)
  else
    actual=$(kubectl get "$kind" "$name" -o jsonpath="$jsonpath" 2>/dev/null)
  fi

  if [[ "$actual" == "$expected" ]]; then
    CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + weight ))
    CKA_SIM_GRADE_PASSES+=("field $jsonpath on $kind/$name == '$expected'")
    ok "field $jsonpath on $kind/$name == '$expected'"
    return 0
  fi
  CKA_SIM_GRADE_FAILS+=("field $jsonpath on $kind/$name = '$actual' (expected '$expected')")
  err "field $jsonpath on $kind/$name = '$actual' (expected '$expected')"
  return 1
}

# cka_sim::grade::assert_pod_ready <namespace> <pod-name> [<weight>]
#   Passes iff pod has Ready=True.
cka_sim::grade::assert_pod_ready() {
  local ns="$1" pod="$2" weight="${3:-1}"
  CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + weight ))

  local ready
  ready=$(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)

  if [[ "$ready" == "True" ]]; then
    CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + weight ))
    CKA_SIM_GRADE_PASSES+=("pod '$pod' is Ready")
    ok "pod '$pod' is Ready"
    return 0
  fi
  CKA_SIM_GRADE_FAILS+=("pod '$pod' is not Ready (got: '${ready:-<missing>}')")
  err "pod '$pod' is not Ready (got: '${ready:-<missing>}')"
  return 1
}

# cka_sim::grade::assert_pvc_bound <namespace> <pvc-name> [<weight>]
#   Passes iff PVC .status.phase == Bound.
cka_sim::grade::assert_pvc_bound() {
  local ns="$1" pvc="$2" weight="${3:-1}"
  CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + weight ))

  local phase
  phase=$(kubectl get pvc "$pvc" -n "$ns" -o jsonpath='{.status.phase}' 2>/dev/null)

  if [[ "$phase" == "Bound" ]]; then
    CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + weight ))
    CKA_SIM_GRADE_PASSES+=("PVC '$pvc' is Bound")
    ok "PVC '$pvc' is Bound"
    return 0
  fi
  CKA_SIM_GRADE_FAILS+=("PVC '$pvc' not Bound (phase='${phase:-<missing>}')")
  err "PVC '$pvc' not Bound (phase='${phase:-<missing>}')"
  return 1
}

# cka_sim::grade::assert_can_i <verb> <resource> [-n <ns>] [--as <user>] [<weight>]
#   Passes iff `kubectl auth can-i <verb> <resource>` prints "yes".
cka_sim::grade::assert_can_i() {
  local verb="$1" resource="$2"
  shift 2
  local ns="" user="" weight=""
  while (( $# > 0 )); do
    if [[ "$1" == "-n" ]]; then
      [[ $# -ge 2 ]] || die "assert_can_i: flag -n requires value"
      ns="$2"
      shift 2
    elif [[ "$1" == "--as" ]]; then
      [[ $# -ge 2 ]] || die "assert_can_i: flag --as requires value"
      user="$2"
      shift 2
    elif [[ "$1" =~ ^[0-9]+$ ]]; then
      weight="$1"
      shift
      (( $# == 0 )) || die "assert_can_i: unexpected argument after weight: $1"
    else
      die "assert_can_i: unexpected argument: $1"
    fi
  done
  : "${weight:=1}"
  CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + weight ))

  local -a cmd=(kubectl auth can-i "$verb" "$resource")
  [[ -n "$ns"   ]] && cmd+=(-n "$ns")
  [[ -n "$user" ]] && cmd+=(--as "$user")

  local out
  out=$("${cmd[@]}" 2>/dev/null)

  if [[ "$out" == "yes" ]]; then
    CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + weight ))
    CKA_SIM_GRADE_PASSES+=("can-i $verb $resource (as=${user:-<self>}, ns=${ns:-<none>}) = yes")
    ok "can-i $verb $resource (as=${user:-<self>}, ns=${ns:-<none>}) = yes"
    return 0
  fi
  CKA_SIM_GRADE_FAILS+=("can-i $verb $resource (as=${user:-<self>}, ns=${ns:-<none>}) = no")
  err "can-i $verb $resource (as=${user:-<self>}, ns=${ns:-<none>}) = no"
  return 1
}

# cka_sim::grade::assert_egress_allowed <namespace> <pod-name> <target-host> <target-port> [<weight>]
#   Passes iff in-pod `echo > /dev/tcp/<host>/<port>` succeeds within 3s.
cka_sim::grade::assert_egress_allowed() {
  local ns="$1" pod="$2" target_host="$3" target_port="$4" weight="${5:-1}"
  CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + weight ))

  if kubectl exec -n "$ns" "$pod" -- timeout 3 sh -c "echo > /dev/tcp/$target_host/$target_port" 2>/dev/null; then
    CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + weight ))
    CKA_SIM_GRADE_PASSES+=("egress from pod '$pod' to $target_host:$target_port works")
    ok "egress from pod '$pod' to $target_host:$target_port works"
    return 0
  fi
  CKA_SIM_GRADE_FAILS+=("egress from pod '$pod' to $target_host:$target_port blocked or unreachable")
  err "egress from pod '$pod' to $target_host:$target_port blocked or unreachable"
  return 1
}

# cka_sim::grade::assert_endpoints_nonempty <namespace> <service-name> [<weight>]
#   Passes iff the service has at least one backing endpoint IP.
cka_sim::grade::assert_endpoints_nonempty() {
  local ns="$1" svc="$2" weight="${3:-1}"
  CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + weight ))

  local ips
  ips=$(kubectl get endpoints "$svc" -n "$ns" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)

  if [[ -n "$ips" ]]; then
    CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + weight ))
    CKA_SIM_GRADE_PASSES+=("endpoints for service '$svc' are non-empty")
    ok "endpoints for service '$svc' are non-empty"
    return 0
  fi
  CKA_SIM_GRADE_FAILS+=("endpoints for service '$svc' are empty (no Ready pods backing it)")
  err "endpoints for service '$svc' are empty (no Ready pods backing it)"
  return 1
}

# ---------- Baseline-aware assertion helpers (3; added by 07.1-01) ----------
#
# These helpers use lib/baseline.sh to compare current cluster state against
# the captured baseline, enabling grading honesty (detect setup-state vs candidate work).

# cka_sim::grade::assert_changed_since_setup <kind> <name> [-n <ns>] [<weight>]
#   Passes iff the resource has been modified since baseline capture.
#   Uses generation-first/rv-fallback logic via is_candidate_modified.
#   On missing baseline: FAIL (caller asked for a delta on something untrackable).
cka_sim::grade::assert_changed_since_setup() {
  local kind="$1" name="$2"
  shift 2
  local ns="" weight=""
  while (( $# > 0 )); do
    if [[ "$1" == "-n" ]]; then
      [[ $# -ge 2 ]] || die "assert_changed_since_setup: flag -n requires value"
      ns="$2"
      shift 2
    elif [[ "$1" =~ ^[0-9]+$ ]]; then
      weight="$1"
      shift
      (( $# == 0 )) || die "assert_changed_since_setup: unexpected argument after weight: $1"
    else
      die "assert_changed_since_setup: unexpected argument: $1"
    fi
  done
  : "${weight:=1}"
  CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + weight ))

  # If no baseline available, fail (can't prove delta)
  if [[ -z "${CKA_SIM_BASELINE_PATH:-}" ]] || [[ ! -r "${CKA_SIM_BASELINE_PATH:-}" ]]; then
    CKA_SIM_GRADE_FAILS+=("$kind/$name unchanged since setup (no baseline available)")
    err "$kind/$name unchanged since setup (no baseline available)"
    return 1
  fi

  local -a mod_args=("$kind" "$name")
  [[ -n "$ns" ]] && mod_args+=("-n" "$ns")

  if cka_sim::baseline::is_candidate_modified "${mod_args[@]}"; then
    CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + weight ))
    CKA_SIM_GRADE_PASSES+=("$kind/$name changed since setup")
    ok "$kind/$name changed since setup"
    return 0
  fi

  CKA_SIM_GRADE_FAILS+=("$kind/$name unchanged since setup")
  err "$kind/$name unchanged since setup"
  return 1
}

# cka_sim::grade::assert_generation_delta_ge <kind> <name> <N> [-n <ns>] [<weight>]
#   Passes iff (current.generation - baseline.generation) >= N.
#   Fails if resource not in baseline or generation is null (per D-07).
cka_sim::grade::assert_generation_delta_ge() {
  local kind="$1" name="$2" threshold="$3"
  shift 3
  local ns="" weight=""
  while (( $# > 0 )); do
    if [[ "$1" == "-n" ]]; then
      [[ $# -ge 2 ]] || die "assert_generation_delta_ge: flag -n requires value"
      ns="$2"
      shift 2
    elif [[ "$1" =~ ^[0-9]+$ ]]; then
      weight="$1"
      shift
      (( $# == 0 )) || die "assert_generation_delta_ge: unexpected argument after weight: $1"
    else
      die "assert_generation_delta_ge: unexpected argument: $1"
    fi
  done
  : "${weight:=1}"
  CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + weight ))

  # Must have baseline
  if [[ -z "${CKA_SIM_BASELINE_PATH:-}" ]] || [[ ! -r "${CKA_SIM_BASELINE_PATH:-}" ]]; then
    CKA_SIM_GRADE_FAILS+=("$kind/$name generation delta undefined (no baseline)")
    err "$kind/$name generation delta undefined (no baseline)"
    return 1
  fi

  # Canonical lookup key
  local canonical_kind lookup_key
  canonical_kind="$(cka_sim::baseline::canonical_kind "$kind")"
  lookup_key="$canonical_kind/$name"

  # Check resource is in baseline
  local in_baseline
  in_baseline=$(jq -r --arg key "$lookup_key" \
    '(.resource_list // []) | if index($key) != null then "true" else "false" end' \
    < "$CKA_SIM_BASELINE_PATH" 2>/dev/null) || {
    CKA_SIM_GRADE_FAILS+=("$kind/$name generation delta undefined (baseline unreadable)")
    err "$kind/$name generation delta undefined (baseline unreadable)"
    return 1
  }

  if [[ "$in_baseline" != "true" ]]; then
    CKA_SIM_GRADE_FAILS+=("$kind/$name generation delta undefined (not in baseline)")
    err "$kind/$name generation delta undefined (not in baseline)"
    return 1
  fi

  # Read baseline generation
  local baseline_gen
  baseline_gen=$(jq -r --arg key "$lookup_key" \
    '[.resources[] | select(("\(.kind | ascii_downcase)/\(.name)" == $key))] | .[0].generation // ""' \
    < "$CKA_SIM_BASELINE_PATH" 2>/dev/null) || {
    CKA_SIM_GRADE_FAILS+=("$kind/$name generation delta undefined (baseline unreadable)")
    err "$kind/$name generation delta undefined (baseline unreadable)"
    return 1
  }

  if [[ -z "$baseline_gen" ]] || [[ "$baseline_gen" == "null" ]]; then
    CKA_SIM_GRADE_FAILS+=("$kind/$name generation delta undefined (baseline generation is null)")
    err "$kind/$name generation delta undefined (baseline generation is null)"
    return 1
  fi

  # Fetch current generation
  local current_gen
  if [[ -n "$ns" ]]; then
    current_gen=$(kubectl get "$kind" "$name" -n "$ns" -o jsonpath='{.metadata.generation}' 2>/dev/null)
  else
    current_gen=$(kubectl get "$kind" "$name" -o jsonpath='{.metadata.generation}' 2>/dev/null)
  fi

  if [[ -z "$current_gen" ]]; then
    CKA_SIM_GRADE_FAILS+=("$kind/$name generation delta undefined (current generation unavailable)")
    err "$kind/$name generation delta undefined (current generation unavailable)"
    return 1
  fi

  local delta=$(( current_gen - baseline_gen ))

  if (( delta >= threshold )); then
    CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + weight ))
    CKA_SIM_GRADE_PASSES+=("$kind/$name generation delta=$delta (>=$threshold)")
    ok "$kind/$name generation delta=$delta (>=$threshold)"
    return 0
  fi

  CKA_SIM_GRADE_FAILS+=("$kind/$name generation delta=$delta (need >=$threshold; baseline=$baseline_gen current=$current_gen)")
  err "$kind/$name generation delta=$delta (need >=$threshold; baseline=$baseline_gen current=$current_gen)"
  return 1
}

# cka_sim::grade::assert_resource_candidate_authored <kind> <name> [-n <ns>] [<weight>]
#   Passes iff the resource was NOT in baseline AND currently exists.
#   Fails if resource pre-existed in baseline OR does not exist now.
cka_sim::grade::assert_resource_candidate_authored() {
  local kind="$1" name="$2"
  shift 2
  local ns="" weight=""
  while (( $# > 0 )); do
    if [[ "$1" == "-n" ]]; then
      [[ $# -ge 2 ]] || die "assert_resource_candidate_authored: flag -n requires value"
      ns="$2"
      shift 2
    elif [[ "$1" =~ ^[0-9]+$ ]]; then
      weight="$1"
      shift
      (( $# == 0 )) || die "assert_resource_candidate_authored: unexpected argument after weight: $1"
    else
      die "assert_resource_candidate_authored: unexpected argument: $1"
    fi
  done
  : "${weight:=1}"
  CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + weight ))

  # Must have baseline
  if [[ -z "${CKA_SIM_BASELINE_PATH:-}" ]] || [[ ! -r "${CKA_SIM_BASELINE_PATH:-}" ]]; then
    CKA_SIM_GRADE_FAILS+=("$kind/$name candidate-authored check failed (no baseline)")
    err "$kind/$name candidate-authored check failed (no baseline)"
    return 1
  fi

  # Canonical lookup key
  local canonical_kind lookup_key
  canonical_kind="$(cka_sim::baseline::canonical_kind "$kind")"
  lookup_key="$canonical_kind/$name"

  # Check if resource was in baseline
  local in_baseline
  in_baseline=$(jq -r --arg key "$lookup_key" \
    '(.resource_list // []) | if index($key) != null then "true" else "false" end' \
    < "$CKA_SIM_BASELINE_PATH" 2>/dev/null) || {
    CKA_SIM_GRADE_FAILS+=("$kind/$name candidate-authored check failed (baseline unreadable)")
    err "$kind/$name candidate-authored check failed (baseline unreadable)"
    return 1
  }

  if [[ "$in_baseline" == "true" ]]; then
    CKA_SIM_GRADE_FAILS+=("$kind/$name pre-existed in baseline (not candidate-authored)")
    err "$kind/$name pre-existed in baseline (not candidate-authored)"
    return 1
  fi

  # Verify resource currently exists
  local out
  if [[ -n "$ns" ]]; then
    out=$(kubectl get "$kind" "$name" -n "$ns" -o name 2>/dev/null)
  else
    out=$(kubectl get "$kind" "$name" -o name 2>/dev/null)
  fi

  if [[ -n "$out" ]]; then
    CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + weight ))
    CKA_SIM_GRADE_PASSES+=("$kind/$name created by candidate")
    ok "$kind/$name created by candidate"
    return 0
  fi

  CKA_SIM_GRADE_FAILS+=("$kind/$name does not exist (candidate has not created it)")
  err "$kind/$name does not exist (candidate has not created it)"
  return 1
}

# ---------- Trap recorder ----------

# cka_sim::grade::record_trap <trap-id>
#   Validates the id against the catalog (lazy-loads via id_exists). On unknown
#   id, dies fast — shipping a phantom trap is a developer bug (per D-16).
#   Deduplicates by scanning the accumulator array (per D-08): same id recorded
#   twice produces a single `Trap N:` line.
cka_sim::grade::record_trap() {
  local id="${1:-}"
  [[ -n "$id" ]] || die "record_trap: missing trap-id"
  cka_sim::trap::id_exists "$id" \
    || die "unknown trap-id '$id' — register it in traps/catalog.yaml first"

  local existing
  for existing in "${CKA_SIM_GRADE_TRAPS[@]}"; do
    [[ "$existing" == "$id" ]] && return 0
  done
  CKA_SIM_GRADE_TRAPS+=("$id")
}

# ---------- Finalizer ----------

# cka_sim::grade::emit_result
#   Prints the SCORE line + Trap N: lines to stdout (parseable by Phase 7).
#   Returns 0 iff all assertions passed AND no traps were recorded.
#   Graders call this as their last step: `cka_sim::grade::emit_result; exit $?`.
cka_sim::grade::emit_result() {
  printf '\n' >&2
  printf 'SCORE: %d/%d\n' "$CKA_SIM_GRADE_PASSED" "$CKA_SIM_GRADE_TOTAL"

  local i=0 id
  for id in "${CKA_SIM_GRADE_TRAPS[@]}"; do
    i=$(( i + 1 ))
    cka_sim::trap::format_line "$i" "$id"
  done

  if (( CKA_SIM_GRADE_PASSED == CKA_SIM_GRADE_TOTAL )) && (( ${#CKA_SIM_GRADE_TRAPS[@]} == 0 )); then
    return 0
  fi
  return 1
}

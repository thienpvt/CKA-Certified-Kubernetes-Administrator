#!/bin/bash
# cka-sim/lib/symptom-diff.sh — shared symptom-diff core (Phase 16 BASELINE-01).
# Sourced by: cka-sim/scripts/lint-question-symptom.sh (lint mode),
#             cka-sim/lib/cmd/audit.sh (audit mode).
# Pure bash + jq + python3 yaml.safe_load. NO dependency on lib/colors.sh
# or lib/log.sh (callers source those themselves).
set -uo pipefail   # NOT -e: per-question failures are accumulated, not fatal.

# --- Module guard ---------------------------------------------------------
[[ -n "${CKA_SIM_SYMPTOM_DIFF_SOURCED:-}" ]] && return 0
readonly CKA_SIM_SYMPTOM_DIFF_SOURCED=1

# --- Resource-kind allow-list --------------------------------------------
# Short alias -> canonical kubectl kind.
declare -gA KIND_ALIAS=(
  [pvc]=persistentvolumeclaim
  [pv]=persistentvolume
  [pod]=pod
  [svc]=service
  [deploy]=deployment
  [networkpolicy]=networkpolicy
  [configmap]=configmap
  [secret]=secret
  [namespace]=namespace
  [role]=role
  [rolebinding]=rolebinding
  [clusterrole]=clusterrole
  [clusterrolebinding]=clusterrolebinding
  [serviceaccount]=serviceaccount
  [hpa]=horizontalpodautoscaler
  [daemonset]=daemonset
  [replicaset]=replicaset
  [priorityclass]=priorityclass
  [storageclass]=storageclass
  [volumesnapshot]=volumesnapshot
  [volumesnapshotclass]=volumesnapshotclass
  [ingress]=ingress
)

# --- Cluster-scoped kinds (no -n flag) ------------------------------------
_is_cluster_scoped() {
  case "$1" in
    pv|namespace|clusterrole|clusterrolebinding|priorityclass|storageclass|volumesnapshotclass) return 0 ;;
    *) return 1 ;;
  esac
}

# --- jsonpath translator --------------------------------------------------
# Translates user-friendly dot-form into a jq query string.
# Two special cases:
#   1. status.conditions[?(@.type=="X")].field
#   2. metadata.labels.<dotted-key-with-slashes>  (segments after labels. quoted)
# Anything else: literal `.<dot-path>`.
_jsonpath_to_jq() {
  local jp="$1"
  if [[ "$jp" =~ ^(status|spec)\.conditions\[\?\(@\.type==\"([^\"]+)\"\)\]\.([a-zA-Z_]+)$ ]]; then
    printf '.%s.conditions[] | select(.type=="%s") | .%s' \
      "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
    return 0
  fi
  if [[ "$jp" =~ ^metadata\.labels\.(.+)$ ]]; then
    local key="${BASH_REMATCH[1]}"
    key="${key//\\./.}"
    printf '.metadata.labels."%s"' "$key"
    return 0
  fi
  printf '.%s' "$jp"
}

# --- BLG-02: kind-based harness skip flag ---------------------------------
# Returns 0 (true; skip the question) if the question's metadata.yaml declares
# unsupported-on-kind=true at the top level. Returns 1 otherwise. Args: q_dir.
cka_sim::symptom_diff::is_unsupported_on_kind() {
  local q_dir="$1"
  local meta="$q_dir/metadata.yaml"
  [[ -f "$meta" ]] || return 1
  grep -qE '^unsupported-on-kind:[[:space:]]*true[[:space:]]*(#.*)?$' "$meta"
}

# --- AUDIT-W&S06: audit-mode-only harness skip flag -----------------------
# Returns 0 (true; skip) if metadata.yaml declares unsupported-in-audit-mode=true. Args: q_dir.
# Orthogonal to is_unsupported_on_kind: a question may be flagged audit-skip
# while remaining valid for kind-based lint runs (and vice versa). Both
# predicates are consulted independently by audit.sh and lint-question-symptom.sh.
cka_sim::symptom_diff::is_unsupported_in_audit_mode() {
  local q_dir="$1"
  local meta="$q_dir/metadata.yaml"
  [[ -f "$meta" ]] || return 1
  grep -qE '^unsupported-in-audit-mode:[[:space:]]*true[[:space:]]*(#.*)?$' "$meta"
}

# --- Per-question lab namespace builder (RFC 1123, <=63 chars) ------------
# $1 = prefix (e.g. "lint" or "audit"), $2 = pack, $3 = q_name
cka_sim::symptom_diff::compute_ns() {
  local prefix="$1" pack="$2" q_name="$3"
  local ns_raw="cka-sim-${prefix}-${pack}-${q_name}"
  local ns="${ns_raw//[^a-z0-9-]/-}"
  ns="${ns:0:63}"
  ns="${ns%-}"
  printf '%s' "$ns"
}

# --- Structured-row emitter (writes to fd 3 if open) ----------------------
# Returns 0 and emits nothing if fd 3 is not open (probed via /dev/fd/3);
# otherwise writes one TSV row to fd 3. Audit mode redirects fd 3 to a tmp
# file; lint mode does not redirect fd 3, so the probe short-circuits.
_emit_row() {
  [[ -e /dev/fd/3 ]] || return 0
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@" >&3
}

# --- Per-question diff core -----------------------------------------------
# Args: yaml_file, q_dir, pack, q_name, ns_prefix
# Returns: 0 clean / 1 divergence
# stderr: human-readable err lines (file:line citations) — used by lint
# fd 3 (if open): TSV rows (verdict\tkind\tname\tjsonpath\texpected\tactual\tline)
cka_sim::symptom_diff::run_one() {
  local yaml_file="$1"
  local q_dir="$2"
  local pack="$3"
  local q_name="$4"
  local ns_prefix="$5"

  local ns
  ns="$(cka_sim::symptom_diff::compute_ns "$ns_prefix" "$pack" "$q_name")"

  if [[ ! -x "$q_dir/setup.sh" && ! -f "$q_dir/setup.sh" ]]; then
    err "$pack/$q_name: setup.sh missing"
    _emit_row ERROR "" "$pack/$q_name" "" "" "setup.sh missing" ""
    return 1
  fi

  # Run setup.sh in a subshell with the per-question ns exported.
  # shellcheck disable=SC2030  # rationale: deliberate subshell-scoped export
  if ! (
    export CKA_SIM_LAB_NS="$ns"
    export CKA_SIM_ROOT
    bash "$q_dir/setup.sh"
  ) >/dev/null 2>&1; then
    err "$pack/$q_name: setup.sh failed against ns=$ns"
    _emit_row ERROR "" "$pack/$q_name" "" "" "setup.sh failed (ns=$ns)" ""
    # Attempt reset even on setup failure, to avoid leaks.
    # shellcheck disable=SC2030,SC2031  # rationale: deliberate subshell-scoped export
    ( export CKA_SIM_LAB_NS="$ns"; export CKA_SIM_ROOT; bash "$q_dir/reset.sh" ) >/dev/null 2>&1 || true
    return 1
  fi

  # Parse expected-symptom.yaml into a tab-separated event stream.
  local parsed
  parsed="$(python3 - "$yaml_file" "$ns" <<'PY'
import sys
import yaml
path, ns = sys.argv[1], sys.argv[2]
with open(path) as f:
    d = yaml.safe_load(f) or {}

def sub(v):
    if isinstance(v, str):
        return v.replace('${CKA_SIM_LAB_NS}', ns)
    return v

top_ns = sub(d.get('namespace') or '')
for r in (d.get('resources') or []):
    kind = r.get('kind') or ''
    name = r.get('name') or ''
    rns = sub(r.get('namespace') if r.get('namespace') is not None else top_ns)
    print('R', kind, sub(name), rns, sep='\t')
    for jp, ev in (r.get('expect') or {}).items():
        print('E', kind, sub(name), jp, sub(str(ev)), sep='\t')
for r in (d.get('absent_resources') or []):
    kind = r.get('kind') or ''
    name = r.get('name') or ''
    rns = sub(r.get('namespace') if r.get('namespace') is not None else top_ns)
    print('A', kind, sub(name), rns, sep='\t')
PY
  )" || {
    err "$pack/$q_name: failed to parse $yaml_file"
    _emit_row ERROR "" "$pack/$q_name" "" "" "yaml parse failed" ""
    # shellcheck disable=SC2030,SC2031  # rationale: deliberate subshell-scoped export
    ( export CKA_SIM_LAB_NS="$ns"; export CKA_SIM_ROOT; bash "$q_dir/reset.sh" ) >/dev/null 2>&1 || true
    return 1
  }

  # Strip carriage returns introduced on Windows MSYS hosts where python
  # emits \r\n line endings — `read -r` does not split on \r, so trailing \r
  # would leak into namespace/name fields and break kubectl lookups.
  parsed="${parsed//$'\r'/}"

  # Pattern D (BLG-04): Calico-on-kind Deployment Available convergence.
  # For each E event claiming a Deployment's status.conditions[Available].status=True,
  # invoke kubectl wait with a 90s timeout BEFORE the JSON-capture pass so the
  # subsequent get reflects post-convergence state. Tolerate timeout — the diff
  # captures the actual state regardless. Skipped for Available=False claims so
  # questions like troubleshooting/03-coredns-resolution don't pay 90s for nothing.
  local w_tag w_kind w_name w_jp w_expected
  while IFS=$'\t' read -r w_tag w_kind w_name w_jp w_expected; do
    [[ "$w_tag" == "E" ]] || continue
    [[ "$w_kind" == "deploy" ]] || continue
    [[ "$w_jp" =~ ^(status|spec)\.conditions\[\?\(@\.type==\"Available\"\)\]\.status$ ]] || continue
    [[ "$w_expected" == "True" ]] || continue
    local wait_ns=""
    local r_tag r_kind r_name r_rns _r_rest
    while IFS=$'\t' read -r r_tag r_kind r_name r_rns _r_rest; do
      [[ "$r_tag" == "R" ]] || continue
      [[ "$r_kind" == "$w_kind" && "$r_name" == "$w_name" ]] || continue
      wait_ns="$r_rns"
      break
    done <<<"$parsed"
    [[ -n "$wait_ns" ]] || continue
    info "$pack/$q_name: waiting up to 90s for deploy/$w_name Available=True (BLG-04)"
    kubectl wait "deployment/$w_name" -n "$wait_ns" --for=condition=Available --timeout=90s >/dev/null 2>&1 || true
  done <<<"$parsed"

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local local_fail=0

  # First pass: capture JSON for each declared resource.
  local kind name rns canonical
  while IFS=$'\t' read -r tag kind name rns _rest; do
    [[ "$tag" == "R" ]] || continue
    if [[ -z "${KIND_ALIAS[$kind]:-}" ]]; then
      warn "$pack/$q_name: unknown kind '$kind' for $name — skipping"
      continue
    fi
    canonical="${KIND_ALIAS[$kind]}"
    local json_path="$tmp_dir/${kind}_${name//\//_}.json"
    local get_cmd=(kubectl get "$canonical" "$name" -o json)
    if ! _is_cluster_scoped "$kind"; then
      get_cmd+=(-n "$rns")
    fi
    if ! "${get_cmd[@]}" >"$json_path" 2>/dev/null; then
      local line_num
      line_num="$(grep -nE "^[[:space:]]*name:[[:space:]]*${name}([[:space:]]|$)" "$yaml_file" | head -1 | cut -d: -f1)"
      err "$yaml_file:${line_num:-?}: $kind/$name not found in cluster (ns=$rns)"
      _emit_row MISSING "$kind" "$name" "" "" "<not-found>" "${line_num:-?}"
      local_fail=1
    fi
  done <<<"$parsed"

  # Second pass: jsonpath-evaluate each expect entry.
  local jp expected actual jq_query
  while IFS=$'\t' read -r tag kind name jp expected; do
    [[ "$tag" == "E" ]] || continue
    [[ -z "${KIND_ALIAS[$kind]:-}" ]] && continue
    local json_path="$tmp_dir/${kind}_${name//\//_}.json"
    [[ -s "$json_path" ]] || continue   # missing-resource error already emitted
    jq_query="$(_jsonpath_to_jq "$jp")"
    # BUG-M11 fix: parenthesize the jsonpath via `as $v | $v // "<missing>"`
    # so jq's `//` operator scopes correctly. The bare `expr // "<missing>"`
    # form binds the alternative across the entire pipeline and returns an
    # array (e.g. `["restricted"]`) for nested-key paths instead of the scalar.
    actual="$(jq -r "($jq_query) as \$v | \$v // \"<missing>\"" "$json_path" 2>/dev/null || echo "<jq-error>")"
    # jq may emit 'null' for missing fields; normalise to <missing>.
    [[ "$actual" == "null" ]] && actual="<missing>"
    local line_num
    local jp_escaped="${jp//\[/\\[}"
    jp_escaped="${jp_escaped//\]/\\]}"
    jp_escaped="${jp_escaped//\?/\\?}"
    jp_escaped="${jp_escaped//\(/\\(}"
    jp_escaped="${jp_escaped//\)/\\)}"
    jp_escaped="${jp_escaped//\./\\.}"
    line_num="$(grep -nE "^[[:space:]]*${jp_escaped}[[:space:]]*:" "$yaml_file" | head -1 | cut -d: -f1)"
    if [[ "$actual" == "$expected" ]]; then
      _emit_row PASS "$kind" "$name" "$jp" "$expected" "$actual" "${line_num:-?}"
    else
      err "$yaml_file:${line_num:-?}: $kind/$name $jp expected '$expected', got '$actual'"
      _emit_row FAIL "$kind" "$name" "$jp" "$expected" "$actual" "${line_num:-?}"
      local_fail=1
    fi
  done <<<"$parsed"

  # Third pass: absent_resources — must NOT exist.
  while IFS=$'\t' read -r tag kind name rns _rest; do
    [[ "$tag" == "A" ]] || continue
    [[ -z "${KIND_ALIAS[$kind]:-}" ]] && continue
    canonical="${KIND_ALIAS[$kind]}"
    local get_cmd=(kubectl get "$canonical" "$name" -o name)
    if ! _is_cluster_scoped "$kind"; then
      get_cmd+=(-n "$rns")
    fi
    if "${get_cmd[@]}" >/dev/null 2>&1; then
      local line_num
      line_num="$(grep -nE "^[[:space:]]*name:[[:space:]]*${name}([[:space:]]|$)" "$yaml_file" | head -1 | cut -d: -f1)"
      err "$yaml_file:${line_num:-?}: $kind/$name unexpectedly present (absent_resources)"
      _emit_row FAIL "$kind" "$name" "<absent>" "<absent>" "<present>" "${line_num:-?}"
      local_fail=1
    fi
  done <<<"$parsed"

  # Reset always runs; tolerate failures with a warn.
  # shellcheck disable=SC2031  # rationale: deliberate subshell-scoped export
  if ! ( export CKA_SIM_LAB_NS="$ns"; export CKA_SIM_ROOT; bash "$q_dir/reset.sh" ) >/dev/null 2>&1; then
    warn "$pack/$q_name: reset.sh exited non-zero (ns may need manual cleanup)"
  fi

  rm -rf "$tmp_dir"
  return "$local_fail"
}

# end symptom-diff.sh

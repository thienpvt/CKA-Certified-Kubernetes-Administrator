#!/bin/bash
# cka-sim/scripts/lint-question-symptom.sh — Phase 15 CI-01.
# Per-question symptom-diff: source setup.sh, capture kubectl state,
# diff against expected-symptom.yaml. Pure bash + jq + python3 yaml.
#
# Usage:
#   bash cka-sim/scripts/lint-question-symptom.sh                 # all questions
#   bash cka-sim/scripts/lint-question-symptom.sh storage/01-pvc-binding  # one
#
# Exit codes:
#   0 = clean diff (or no live cluster; warn-skip)
#   1 = at least one question diverged from its expected-symptom.yaml
set -euo pipefail

CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$CKA_SIM_ROOT/.." && pwd)"
export CKA_SIM_ROOT REPO_ROOT

# shellcheck source=../lib/colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../lib/log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"

header "live-cluster symptom diff"

# --- Cluster preflight gate -----------------------------------------------
if ! kubectl cluster-info >/dev/null 2>&1; then
  warn "no live cluster reachable (kubectl cluster-info failed) — skipping symptom-diff"
  exit 0
fi

# --- Tool preflight --------------------------------------------------------
command -v jq >/dev/null 2>&1 || die "jq not found in PATH"
command -v python3 >/dev/null 2>&1 || die "python3 not found in PATH"
python3 -c 'import yaml' 2>/dev/null || die "python3 yaml module not available"

# --- Resource-kind allow-list (CONTEXT specifics) -------------------------
declare -A KIND_ALIAS=(
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

# --- jsonpath translator ---------------------------------------------------
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

# --- Per-question diff core -----------------------------------------------
_diff_one_question() {
  local yaml_file="$1"
  local q_dir="$2"
  local pack="$3"
  local q_name="$4"

  # Build a per-question lab namespace name (RFC 1123, <= 63 chars).
  local ns_raw="cka-sim-lint-${pack}-${q_name}"
  local ns="${ns_raw//[^a-z0-9-]/-}"
  ns="${ns:0:63}"
  ns="${ns%-}"

  if [[ ! -x "$q_dir/setup.sh" && ! -f "$q_dir/setup.sh" ]]; then
    err "$pack/$q_name: setup.sh missing"
    return 1
  fi

  # Run setup.sh in a subshell with the per-question ns exported.
  if ! (
    export CKA_SIM_LAB_NS="$ns"
    export CKA_SIM_ROOT
    bash "$q_dir/setup.sh"
  ) >/dev/null 2>&1; then
    err "$pack/$q_name: setup.sh failed against ns=$ns"
    # Attempt reset even on setup failure, to avoid leaks.
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
    print('R', kind, name, rns, sep='\t')
    for jp, ev in (r.get('expect') or {}).items():
        print('E', kind, name, jp, sub(str(ev)), sep='\t')
for r in (d.get('absent_resources') or []):
    kind = r.get('kind') or ''
    name = r.get('name') or ''
    rns = sub(r.get('namespace') if r.get('namespace') is not None else top_ns)
    print('A', kind, name, rns, sep='\t')
PY
  )" || {
    err "$pack/$q_name: failed to parse $yaml_file"
    ( export CKA_SIM_LAB_NS="$ns"; export CKA_SIM_ROOT; bash "$q_dir/reset.sh" ) >/dev/null 2>&1 || true
    return 1
  }

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local local_fail=0

  # First pass: capture JSON for each declared resource.
  local line kind name rns canonical
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
    actual="$(jq -r "$jq_query // \"<missing>\"" "$json_path" 2>/dev/null || echo "<jq-error>")"
    # jq may emit 'null' for missing fields; normalise to <missing>.
    [[ "$actual" == "null" ]] && actual="<missing>"
    if [[ "$actual" != "$expected" ]]; then
      local line_num
      # Find the jsonpath literal in the YAML file (escape special characters lightly).
      local jp_escaped="${jp//\[/\\[}"
      jp_escaped="${jp_escaped//\]/\\]}"
      jp_escaped="${jp_escaped//\?/\\?}"
      jp_escaped="${jp_escaped//\(/\\(}"
      jp_escaped="${jp_escaped//\)/\\)}"
      jp_escaped="${jp_escaped//\./\\.}"
      line_num="$(grep -nE "^[[:space:]]*${jp_escaped}[[:space:]]*:" "$yaml_file" | head -1 | cut -d: -f1)"
      err "$yaml_file:${line_num:-?}: $kind/$name $jp expected '$expected', got '$actual'"
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
      local_fail=1
    fi
  done <<<"$parsed"

  # Reset always runs; tolerate failures with a warn.
  if ! ( export CKA_SIM_LAB_NS="$ns"; export CKA_SIM_ROOT; bash "$q_dir/reset.sh" ) >/dev/null 2>&1; then
    warn "$pack/$q_name: reset.sh exited non-zero (ns may need manual cleanup)"
  fi

  rm -rf "$tmp_dir"
  return "$local_fail"
}

# --- Driver ---------------------------------------------------------------
errors=0
checked=0
target_arg="${1:-}"

while IFS= read -r yaml_file; do
  q_dir="$(dirname "$yaml_file")"
  pack="$(basename "$(dirname "$q_dir")")"
  q_name="$(basename "$q_dir")"
  if [[ -n "$target_arg" && "$pack/$q_name" != "$target_arg" ]]; then
    continue
  fi
  checked=$(( checked + 1 ))
  info "==> $pack/$q_name"
  if ! _diff_one_question "$yaml_file" "$q_dir" "$pack" "$q_name"; then
    errors=$(( errors + 1 ))
  fi
done < <(find "$CKA_SIM_ROOT/packs" -name 'expected-symptom.yaml' -type f | sort)

if [[ -n "$target_arg" && "$checked" -eq 0 ]]; then
  warn "no expected-symptom.yaml matched filter '$target_arg'"
  exit 0
fi

if (( errors > 0 )); then
  err "$errors question(s) had symptom-diff failures across $checked checked"
  exit 1
fi
ok "symptom diff: $checked question(s) passed"

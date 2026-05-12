#!/bin/bash
# cka-sim/scripts/lint-traps.sh — schema + naming + path + seed-completeness lint for traps/catalog.yaml.
# Pure bash (per D-04 — no python, no yq).
# Wired into cka-sim/scripts/test.sh and CI's bash-tests job.

set -euo pipefail

CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$CKA_SIM_ROOT/.." && pwd)"

# shellcheck source=../lib/colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../lib/log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"

header "trap catalog lint"

catalog="$CKA_SIM_ROOT/traps/catalog.yaml"
if [[ ! -f "$catalog" ]]; then
  # Wave-1 graceful path: catalog lands in plan 02-02 (Wave 2) and traps.sh lands in plan 02-01.
  # Treat missing catalog as a "scaffold not yet complete" warning, not an error — exit 0 so plan
  # 02-03's own scaffold-only acceptance can pass without requiring 02-01 or 02-02.
  # We skip BEFORE sourcing lib/traps.sh because traps.sh also lands in 02-01; end-to-end green
  # (catalog present + 8 seeds valid) is checked in plan 02-04's acceptance, after 02-01/02-02 land.
  warn "catalog not found: $catalog — skipping lint (expected during plan 02-03 scaffold verification)"
  exit 0
fi

# Source traps.sh for the is_valid_id regex (single source of truth for TRIP-07).
# Deferred until after the catalog-existence gate so the reference-forward stays valid in Wave 1.
# shellcheck source=../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Closed enums (D-13, D-14, D-15)
valid_severity=("info" "warn" "error")
valid_domain=("troubleshooting" "cluster-architecture" "services-networking" "workloads-scheduling" "storage")
valid_source=("cncf-curriculum" "concerns-md" "community")
valid_ref_kind=("concerns-md" "k8s-doc" "prior-art-exercise" "exam-objective" "blog-post")

# Required seed IDs per GRADE-05 (D-15(h)).
seed_ids=(
  "pss-error-string-mismatch"
  "psp-fictional-pod-label-exemption"
  "kubelet-runtime-flag-in-kubeconfig"
  "removed-container-runtime-flag"
  "hostpath-pv-without-nodeaffinity"
  "as-flag-format-wrong"
  "default-sa-used"
  "missing-dns-egress"
)

# Required entry fields (D-13).
required_fields=("name" "description" "remediation_hint" "severity" "domain" "source" "references")

errors=0
checked=0

# ---- in_array helper ----
_in_array() {
  local needle="$1"; shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

# ---- pure-bash entry-by-entry walk ----
# State machine: track current entry's id + collected fields; on next "  - id:" line, validate the previous one.
declare -A seen_ids=()
current_id=""
declare -A current_fields=()
declare -a current_ref_kinds=()
declare -a current_ref_targets=()

_validate_entry() {
  [[ -n "$current_id" ]] || return 0
  checked=$(( checked + 1 ))
  local missing_fields=()
  local f
  for f in "${required_fields[@]}"; do
    [[ -n "${current_fields[$f]:-}" ]] || missing_fields+=("$f")
  done
  if (( ${#missing_fields[@]} > 0 )); then
    err "trap[$current_id]: missing fields: ${missing_fields[*]}"
    errors=$(( errors + 1 ))
    return 0
  fi
  # id RFC 1123 (D-15(b)) — reuse traps.sh helper
  if ! cka_sim::trap::is_valid_id "$current_id"; then
    err "trap[$current_id]: id is not RFC 1123 (lowercase a-z, 0-9, '-', length<=63, alphanumeric start/end)"
    errors=$(( errors + 1 ))
  fi
  # severity / domain / source enums
  _in_array "${current_fields[severity]}" "${valid_severity[@]}" || { err "trap[$current_id]: severity '${current_fields[severity]}' not in enum"; errors=$(( errors + 1 )); }
  _in_array "${current_fields[domain]}" "${valid_domain[@]}" || { err "trap[$current_id]: domain '${current_fields[domain]}' not in enum"; errors=$(( errors + 1 )); }
  _in_array "${current_fields[source]}" "${valid_source[@]}" || { err "trap[$current_id]: source '${current_fields[source]}' not in enum"; errors=$(( errors + 1 )); }
  # references[].kind enum + path-existence for concerns-md/prior-art-exercise
  local i
  for (( i=0; i<${#current_ref_kinds[@]}; i++ )); do
    local k="${current_ref_kinds[$i]}" t="${current_ref_targets[$i]}"
    if ! _in_array "$k" "${valid_ref_kind[@]}"; then
      err "trap[$current_id]: references[].kind '$k' not in enum"
      errors=$(( errors + 1 ))
    fi
    if [[ "$k" == "concerns-md" || "$k" == "prior-art-exercise" ]]; then
      if [[ ! -e "$REPO_ROOT/$t" ]]; then
        err "trap[$current_id]: references[$i] target '$t' does not resolve under repo root"
        errors=$(( errors + 1 ))
      fi
    fi
  done
  ok "trap[$current_id]: schema OK"
  seen_ids[$current_id]=1
}

_strip_quotes() {
  local v="$1"
  v="${v#\"}"; v="${v%\"}"
  v="${v#\'}"; v="${v%\'}"
  printf '%s' "$v"
}

while IFS= read -r line; do
  # Skip blanks and comment-only lines
  [[ -z "${line// }" ]] && continue
  [[ "$line" =~ ^[[:space:]]*# ]] && continue

  # New entry: "  - id: <id>"
  if [[ "$line" =~ ^[[:space:]]{2}-[[:space:]]+id:[[:space:]]+(.+)$ ]]; then
    # IMPORTANT: capture BASH_REMATCH[1] BEFORE calling _validate_entry — that helper invokes
    # cka_sim::trap::is_valid_id which does its own `[[ =~ ]]` and clobbers BASH_REMATCH.
    new_id="$(_strip_quotes "${BASH_REMATCH[1]}")"
    # Validate previous entry (if any) before starting a new one
    _validate_entry
    # Reset state
    current_id="$new_id"
    unset current_fields current_ref_kinds current_ref_targets
    declare -A current_fields=()
    declare -a current_ref_kinds=()
    declare -a current_ref_targets=()
    continue
  fi

  # Entry field: "    <field>: <value>"
  if [[ "$line" =~ ^[[:space:]]{4}([a-z_]+):[[:space:]]*(.*)$ ]]; then
    local_key="${BASH_REMATCH[1]}"
    local_val="$(_strip_quotes "${BASH_REMATCH[2]}")"
    # references is a list — value will be empty; skip
    if [[ "$local_key" == "references" ]]; then
      current_fields[references]="(list)"
      continue
    fi
    # Only stash if it's a known top-level field
    for f in "${required_fields[@]}" id; do
      if [[ "$f" == "$local_key" ]]; then
        current_fields[$local_key]="$local_val"
        break
      fi
    done
    continue
  fi

  # Reference list item: "      - kind: <k>" / "        target: <t>" / "        note: <n>"
  if [[ "$line" =~ ^[[:space:]]{6}-[[:space:]]+kind:[[:space:]]+(.+)$ ]]; then
    current_ref_kinds+=("$(_strip_quotes "${BASH_REMATCH[1]}")")
    current_ref_targets+=("")  # placeholder — target will be set on next line
    continue
  fi
  if [[ "$line" =~ ^[[:space:]]{8}target:[[:space:]]+(.+)$ ]]; then
    # update last element (NOTE: bare assignment, NOT `local` — this block runs at script top-level,
    # not inside a function; `local` would error with "local: can only be used in a function" under set -e)
    last=$(( ${#current_ref_targets[@]} - 1 ))
    if (( last >= 0 )); then
      current_ref_targets[$last]="$(_strip_quotes "${BASH_REMATCH[1]}")"
    fi
    continue
  fi
  # Inline-form references entry (yaml flow): handled? skip — D-13 schema is explicitly the block form.
done < "$catalog"

# Validate the final pending entry
_validate_entry

# Seed completeness check (D-15(h))
for sid in "${seed_ids[@]}"; do
  if [[ -z "${seen_ids[$sid]:-}" ]]; then
    err "seeded trap-id missing from catalog: $sid"
    errors=$(( errors + 1 ))
  fi
done

printf '\n' >&2
if (( errors > 0 )); then
  err "$errors lint error(s) across $checked entr(ies). Fix before pushing."
  exit 1
else
  ok "catalog lint passed ($checked entries schema OK)."
  exit 0
fi

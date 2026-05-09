#!/bin/bash
# cka-sim/lib/traps.sh — trap detector library + catalog parser.
# Sourced by: lib/grade.sh, every grade.sh under packs/*/.
# Detector contract (per CONTEXT D-02): positional args; stdout = trap-id on hit, EMPTY on miss.
# Catalog contract (per CONTEXT D-04): pure-bash parser of traps/catalog.yaml's flat shape into associative arrays.

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=colors.sh disable=SC1091
[[ -z "${RED+x}" ]] && source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"

# ---------- Catalog state ----------
#
# Six associative arrays, keyed by trap-id, hold the fields of traps/catalog.yaml.
# `declare -gA` ensures they survive sourcing and are shared across every grade.sh
# that sources this library.

declare -gA CKA_SIM_TRAP_NAME=()
declare -gA CKA_SIM_TRAP_DESC=()
declare -gA CKA_SIM_TRAP_REMEDIATION=()
declare -gA CKA_SIM_TRAP_SEVERITY=()
declare -gA CKA_SIM_TRAP_DOMAIN=()
declare -gA CKA_SIM_TRAP_SOURCE=()
declare -g  CKA_SIM_TRAP_CATALOG_LOADED=0

# ---------- Validation ----------

# cka_sim::trap::is_valid_id <id>
#   Returns 0 iff <id> conforms to RFC 1123 DNS label:
#     - matches ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$
#     - length <= 63
#   Single source of truth for TRIP-07 validation — both lint-traps.sh
#   and record_trap call this.
cka_sim::trap::is_valid_id() {
  local id="${1:-}"
  [[ -n "$id" ]] || return 1
  (( ${#id} <= 63 )) || return 1
  [[ "$id" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]
}

# ---------- Catalog parser ----------

# cka_sim::trap::_load_catalog [<catalog-path>]
#   Pure-bash parser for traps/catalog.yaml's flat shape. Default path is
#   ${CKA_SIM_ROOT}/traps/catalog.yaml. Populates the six associative
#   arrays above. Idempotent — calling twice overwrites the same slots.
#   On parse failure (bad id, missing required field, unreadable file)
#   invokes `die` from log.sh.
cka_sim::trap::_load_catalog() {
  local path="${1:-$CKA_SIM_ROOT/traps/catalog.yaml}"
  [[ -r "$path" ]] || die "catalog parse failed: cannot read '$path'"

  local line trimmed value
  local current_id=""

  # Walk each line of the flat YAML. Required-field completeness is verified
  # in a second pass below; this pass only populates the maps.
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip blank lines and whole-line comments.
    [[ -z "${line//[[:space:]]/}" ]] && continue
    trimmed="${line#"${line%%[![:space:]]*}"}"
    [[ "${trimmed:0:1}" == "#" ]] && continue

    # New entry marker: `^  - id: <id>` (two-space indent is a fixed part of
    # the flat catalog shape — enforced by lint-traps.sh).
    if [[ "$line" =~ ^\ \ -\ id:\ (.+)$ ]]; then
      value="${BASH_REMATCH[1]}"
      value="${value%\"}"
      value="${value#\"}"
      cka_sim::trap::is_valid_id "$value" \
        || die "catalog parse failed: invalid id '$value' (must match RFC 1123)"
      current_id="$value"
      # Claim the slot for this id with empty placeholders. The second-pass
      # completeness check flags any field left empty.
      CKA_SIM_TRAP_NAME[$current_id]=""
      CKA_SIM_TRAP_DESC[$current_id]=""
      CKA_SIM_TRAP_REMEDIATION[$current_id]=""
      CKA_SIM_TRAP_SEVERITY[$current_id]=""
      CKA_SIM_TRAP_DOMAIN[$current_id]=""
      CKA_SIM_TRAP_SOURCE[$current_id]=""
      continue
    fi

    # Field line: `^    (name|description|remediation_hint|severity|domain|source): <value>`.
    # Four-space indent distinguishes top-level entry fields from the `references:`
    # sub-list items (six-space dash) which we intentionally skip.
    if [[ "$line" =~ ^\ \ \ \ (name|description|remediation_hint|severity|domain|source):\ (.+)$ ]]; then
      local field="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      # Strip one layer of surrounding double-quotes if present.
      if [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
        value="${value#\"}"
        value="${value%\"}"
      fi
      [[ -n "$current_id" ]] \
        || die "catalog parse failed: field '$field' appeared before any entry id"
      case "$field" in
        name)             CKA_SIM_TRAP_NAME[$current_id]="$value" ;;
        description)      CKA_SIM_TRAP_DESC[$current_id]="$value" ;;
        remediation_hint) CKA_SIM_TRAP_REMEDIATION[$current_id]="$value" ;;
        severity)         CKA_SIM_TRAP_SEVERITY[$current_id]="$value" ;;
        domain)           CKA_SIM_TRAP_DOMAIN[$current_id]="$value" ;;
        source)           CKA_SIM_TRAP_SOURCE[$current_id]="$value" ;;
      esac
      continue
    fi

    # Anything else (top-level `traps:`, the `references:` sub-list header,
    # its `- kind/target/note` items, stray blank-indent lines) is skipped.
    # Schema enforcement is lint-traps.sh's job; the runtime parser only
    # cares about the six runtime-consumed fields.
  done < "$path"

  # Second pass: verify every claimed entry has all six required fields filled.
  local id
  for id in "${!CKA_SIM_TRAP_NAME[@]}"; do
    [[ -n "${CKA_SIM_TRAP_NAME[$id]}"        ]] || die "catalog parse failed: '$id' missing field 'name'"
    [[ -n "${CKA_SIM_TRAP_DESC[$id]}"        ]] || die "catalog parse failed: '$id' missing field 'description'"
    [[ -n "${CKA_SIM_TRAP_REMEDIATION[$id]}" ]] || die "catalog parse failed: '$id' missing field 'remediation_hint'"
    [[ -n "${CKA_SIM_TRAP_SEVERITY[$id]}"    ]] || die "catalog parse failed: '$id' missing field 'severity'"
    [[ -n "${CKA_SIM_TRAP_DOMAIN[$id]}"      ]] || die "catalog parse failed: '$id' missing field 'domain'"
    [[ -n "${CKA_SIM_TRAP_SOURCE[$id]}"      ]] || die "catalog parse failed: '$id' missing field 'source'"
  done

  CKA_SIM_TRAP_CATALOG_LOADED=1
}

# ---------- Runtime lookup helpers ----------

# cka_sim::trap::id_exists <id>
#   Returns 0 if <id> is present in the loaded catalog, 1 otherwise.
#   Lazy-loads the catalog on first call so graders never have to.
cka_sim::trap::id_exists() {
  local id="${1:-}"
  [[ -n "$id" ]] || return 1
  (( CKA_SIM_TRAP_CATALOG_LOADED == 1 )) || cka_sim::trap::_load_catalog
  [[ -n "${CKA_SIM_TRAP_NAME[$id]+x}" ]]
}

# cka_sim::trap::format_line <ordinal> <id>
#   Prints one catalog-line to stdout:
#     Trap <ordinal>: <name>: <description>
#   Fails via `die` if <id> is not in the catalog.
cka_sim::trap::format_line() {
  local ord="${1:-}" id="${2:-}"
  [[ -n "$ord" && -n "$id" ]] || die "format_line: usage: format_line <ordinal> <id>"
  cka_sim::trap::id_exists "$id" \
    || die "format_line: unknown trap-id '$id' (not in catalog)"
  printf 'Trap %d: %s: %s\n' "$ord" "${CKA_SIM_TRAP_NAME[$id]}" "${CKA_SIM_TRAP_DESC[$id]}"
}

# Detectors land in plan 02-02; see traps/catalog.yaml for the seed list.

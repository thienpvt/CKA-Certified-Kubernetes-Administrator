#!/bin/bash
# cka-sim/lib/log.sh — leveled logging helpers
# Sourced by: bin/cka-sim and every lib/cmd/*.sh
# Contract: all output goes to stderr so stdout stays parseable by callers.

# shellcheck source=colors.sh disable=SC1091
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"
# shellcheck disable=SC1091
[[ -z "${RED+x}" ]] && source "$CKA_SIM_ROOT/lib/colors.sh"

info()    { printf '  %s\n' "$*" >&2; }
ok()      { printf '%s✓%s %s\n' "$GREEN" "$NC" "$*" >&2; }
warn()    { printf '%s!%s %s\n' "$YELLOW" "$NC" "$*" >&2; }
err()     { printf '%s✗%s %s\n' "$RED" "$NC" "$*" >&2; }

die()     { err "$*"; exit 1; }

header()  {
  printf '\n%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' "$BOLD" "$NC" >&2
  printf '%s %s %s\n' "$BOLD" "$*" "$NC" >&2
  printf '%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n\n' "$BOLD" "$NC" >&2
}

verbose() {
  [[ "${CKA_SIM_VERBOSE:-0}" == "1" ]] || return 0
  printf '[verbose] %s\n' "$*" >&2
}
